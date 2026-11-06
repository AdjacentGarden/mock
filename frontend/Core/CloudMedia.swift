import CryptoKit
import Foundation
import Observation
import UIKit

// The lesson context and all wire models come from the cloud implementation.
enum LearningMediaKind: String, Codable, Sendable { case image, video }

extension LessonMediaRequest {
  init(lesson: Lesson, section: LessonBlock?, asset: BookAsset? = nil, kind: LearningMediaKind) {
    let text = section?.content ?? lesson.summary
    let excerpt = ([asset?.caption, text].compactMap { $0 }.filter { !$0.isEmpty }).joined(separator: "\n")
    let citations = section?.citations ?? lesson.blocks.flatMap(\.citations)
    let pages = citations.flatMap {
      Array($0.page_start...max($0.page_start, min($0.page_end, $0.page_start + 29)))
    }.filter { (1...100000).contains($0) }
    self.init(kind: kind.rawValue, bookID: lesson.book_id, chapterID: lesson.chapter_id,
      chapterTitle: lesson.title, title: asset?.caption ?? lesson.title,
      excerpt: String(excerpt.prefix(3000)),
      pages: Array(Set(pages.isEmpty ? [asset?.page ?? lesson.page_start].filter { $0 > 0 } : pages)).sorted().prefix(30).map { $0 },
      lessonID: lesson.id, courseID: "")
  }
}

extension StudioCapabilities {
  func available(_ kind: LearningMediaKind) -> Bool { kind == .image ? image : video }

  func unavailableNotice(_ kind: LearningMediaKind) -> String {
    let notices = kind == .video ? [video_notice, media_notice] : [media_notice]
    if let notice = notices.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
      .first(where: { !$0.isEmpty }) { return notice }
    return kind == .image
      ? "辅助图生成服务暂未就绪，请检查后端的图像服务配置。"
      : "视频生成服务暂未就绪，请检查后端的视频服务配置。"
  }

  /// These are the current submission settings, never metadata for an older asset.
  func generationTarget(_ kind: LearningMediaKind) -> String? {
    if kind == .image {
      guard let width = image_width, let height = image_height, width > 0, height > 0 else { return nil }
      return "新生成图片目标尺寸：\(width) × \(height) 像素。"
    }
    guard let resolution = video_resolution?.trimmingCharacters(in: .whitespacesAndNewlines),
      !resolution.isEmpty else { return nil }
    return "新生成视频目标分辨率：\(resolution)。"
  }

  func generationRequirement(_ kind: LearningMediaKind) -> String? {
    kind == .video && video_requires_image == true ? "低价视频需先生成当前选段的辅助图。" : nil
  }
}

extension StudioJob: Identifiable {
  var isRunning: Bool { ["queued", "planning", "submitting", "polling", "reviewing"].contains(status) }
  var statusText: String {
    switch status {
    case "queued": "正在排队"
    case "planning": "正在设计讲解"
    case "submitting": "正在提交生成"
    case "polling": "正在生成短片"
    case "reviewing": "正在检查内容"
    case "succeeded": "已生成"
    case "failed", "rejected": "生成未完成"
    case "cancelled": "任务已取消"
    case "uncertain": "结果待确认"
    default: "请刷新任务状态"
    }
  }
}

extension CloudAPI {
  func downloadMedia(_ job: StudioJob) async throws -> Data {
    guard job.status == "succeeded", ["image", "video"].contains(job.kind),
      LessonMediaJobContract.validJobID(job.id), job.asset_url == "/api/studio/jobs/\(job.id)/asset"
    else { throw CloudError(status: 422, message: "生成结果尚不可用") }
    return try await downloadStudioAsset(jobID: job.id, kind: job.kind)
  }
}

/// Presentation adapter for the offline demo media service. Its public API matches
/// the production adapter so the reader can later switch to a real service.
@MainActor @Observable final class CloudMediaModel {
  let api: CloudAPI?
  let context: LessonMediaRequest
  var kind: LearningMediaKind { LearningMediaKind(rawValue: context.kind) ?? .video }
  var capabilities: StudioCapabilities?
  var jobs: [StudioJob] = []
  var job: StudioJob?
  private(set) var historyPreview: StudioJob?
  private(set) var receipt: LessonMediaReceipt?
  var loading = false
  var submitting = false
  var downloading = false
  var error: String?
  var authenticationExpired = false
  var imageData: Data?
  var videoURL: URL?
  var refreshID = 0
  var generationProgress = 0.0
  var generationMessage = "正在准备素材"
  private var historyImageData: Data?
  private var historyVideoURL: URL?
  private var ready = false
  private var invalidated = false
  private var operationID = UUID()
  private let service: MockMediaService
  private let saveToLibrary: ((String, URL) async throws -> Void)?

  var isPreviewingHistory: Bool { historyPreview != nil }
  var displayedJob: StudioJob? { historyPreview ?? job }
  var displayedImageData: Data? { isPreviewingHistory ? historyImageData : imageData }
  var displayedVideoURL: URL? { isPreviewingHistory ? historyVideoURL : videoURL }
  var history: [StudioJob] { jobs }
  var canSubmit: Bool {
    ready && !invalidated && !loading && !submitting && !isPreviewingHistory
      && capabilities?.available(kind) == true && context.excerpt.count >= 4
  }

  init(api: CloudAPI?, request: LessonMediaRequest, storageRoot: URL? = nil,
    libraryDirectory: URL? = nil, saveToLibrary: ((String, URL) async throws -> Void)? = nil) {
    // Retain the initializer contract; this adapter never calls the supplied API.
    self.api = nil
    context = request
    self.saveToLibrary = saveToLibrary
    // Keep metadata in the same repository/session as its artifacts. In
    // particular, isolated fixture sessions must never share a global history.
    let root = storageRoot
      ?? libraryDirectory?.appendingPathComponent(".mock-media", isDirectory: true)
      ?? FileManager.default.urls(for: .applicationSupportDirectory,
        in: .userDomainMask)[0].appendingPathComponent("CloudPathMock/Media", isDirectory: true)
    service = MockMediaService(request: request, metadataRoot: root,
      artifactRoot: libraryDirectory ?? root.appendingPathComponent("artifacts", isDirectory: true))
  }

  func load() async {
    guard !loading, !submitting, !invalidated else { return }
    loading = true
    ready = false
    error = nil
    defer { loading = false; refreshID += 1 }
    do {
      try await MockMediaService.pause(milliseconds: 600)
      guard !invalidated else { return }
      capabilities = MockMediaService.capabilities
      jobs = try service.history()
      if let previous = jobs.first(where: { $0.excerpt == context.excerpt && $0.chapter_title == context.chapterTitle }) {
        job = previous
        receipt = LessonMediaReceipt(requestID: previous.request_id ?? "mock_recovered",
          jobID: previous.id, state: previous.status, submissionUncertain: false)
        if previous.status == "succeeded" {
          try display(previous, history: false)
          if let url = service.artifactURL(previous) { try await saveToLibrary?(previous.id, url) }
        }
      }
      ready = true
    } catch is CancellationError { } catch { self.error = error.localizedDescription }
  }

  func submit() async {
    guard canSubmit else { return }
    let token = UUID()
    operationID = token
    submitting = true
    generationProgress = 0
    generationMessage = "正在准备生成任务"
    error = nil
    clearAsset()
    var current = service.makeJob(status: "planning")
    job = current
    receipt = LessonMediaReceipt(requestID: current.request_id!, jobID: current.id,
      state: current.status, submissionUncertain: false)
    defer { submitting = false; downloading = false; refreshID += 1 }
    do {
      for phase in MockMediaService.phases(kind: kind) {
        generationMessage = phase.message
        current.status = phase.status
        job = current
        receipt?.state = phase.status
        try await MockMediaService.pause(milliseconds: phase.milliseconds)
        guard token == operationID, !invalidated else { throw CancellationError() }
        generationProgress = phase.progress
      }
      downloading = true
      generationMessage = "正在加载生成结果"
      try await MockMediaService.pause(milliseconds: 500)
      guard token == operationID, !invalidated else { throw CancellationError() }
      let completed = try service.complete(current)
      if let url = service.artifactURL(completed) { try await saveToLibrary?(completed.id, url) }
      try Task.checkCancellation()
      guard token == operationID, !invalidated else { throw CancellationError() }
      job = completed
      receipt?.state = "succeeded"
      generationProgress = 1
      generationMessage = "生成完成"
      try display(completed, history: false)
      jobs = try service.history()
    } catch is CancellationError {
      guard !invalidated else { return }
      current.status = "cancelled"
      current.error = "生成已暂停，可以重新生成。"
      job = current
      receipt?.state = "cancelled"
      try? service.save(current)
      jobs = (try? service.history()) ?? jobs
    } catch {
      current.status = "failed"
      current.error = error.localizedDescription
      job = current
      receipt?.state = "failed"
      self.error = error.localizedDescription
      try? service.save(current)
      jobs = (try? service.history()) ?? jobs
    }
  }

  /// Results are produced by submit(), so the view's production polling hook
  /// intentionally has no network activity in this repository.
  func follow(pollInterval: Duration = .seconds(2)) async { }

  func select(_ value: StudioJob) {
    guard !loading, !submitting, !invalidated else { return }
    if value.id == job?.id { returnToCurrent(); return }
    do {
      historyPreview = value
      try display(value, history: true)
      error = value.status == "failed" ? value.error : nil
      refreshID += 1
    } catch { self.error = error.localizedDescription }
  }

  func returnToCurrent() {
    historyPreview = nil
    historyImageData = nil
    historyVideoURL = nil
    error = nil
    refreshID += 1
  }

  func refresh() async {
    returnToCurrent()
    await load()
  }

  private func display(_ value: StudioJob, history: Bool) throws {
    if history { historyImageData = nil; historyVideoURL = nil }
    else { imageData = nil; videoURL = nil }
    guard value.status == "succeeded", let url = service.artifactURL(value) else { return }
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw ContentError.missing("演示素材，请点击重新生成")
    }
    if kind == .image {
      let bytes = try Data(contentsOf: url)
      guard UIImage(data: bytes) != nil else { throw ContentError.invalid("演示图片无法读取，请重新生成。") }
      if history { historyImageData = bytes } else { imageData = bytes }
    } else {
      if history { historyVideoURL = url } else { videoURL = url }
    }
  }

  func invalidateIdentity() {
    invalidated = true
    operationID = UUID()
    ready = false
    capabilities = nil
    jobs = []
    job = nil
    historyPreview = nil
    clearAsset()
    error = "当前演示会话已变化，请关闭后重新打开。"
    refreshID += 1
  }

  func clearAsset() {
    imageData = nil
    videoURL = nil
    historyImageData = nil
    historyVideoURL = nil
  }
}

extension LocalBookCourseRepository {
  func saveLessonMedia(_ url: URL, id: String, context: LessonMediaRequest, resourceID: String, scope: String) throws {
    do { try requireLiveCourse(courseID: context.courseID, scope: scope) }
    catch {
      try? removeCourseFileIfUnreferenced(url)
      throw error
    }
    let key = AgentDigest.sha256(context.id + "|" + id)
    guard url.deletingLastPathComponent().standardizedFileURL.path == directory.appendingPathComponent("lesson-media").standardizedFileURL.path,
      FileManager.default.fileExists(atPath: url.path) else { throw ContentError.storage("生成素材尚未保存") }
    let record: [String: JSONValue] = ["id": .string(key), "kind": .string(context.kind),
      "course_id": .string(context.courseID), "course_resource_id": .string(resourceID), "book_id": .string(context.bookID),
      "chapter_id": .string(context.chapterID), "lesson_id": .string(context.lessonID), "title": .string(context.title),
      "file": .string(url.lastPathComponent), "excerpt": .string(context.excerpt), "pages": .array(context.pages.map { .number(Double($0)) })]
    try db.put("lesson-media:" + scope, key, encoder.encode(record))
  }
  func localLessonMedia(scope: String) throws -> [[String: JSONValue]] {
    try db.get("lesson-media:" + scope).map { try decoder.decode([String: JSONValue].self, from: $0) }
  }
}
