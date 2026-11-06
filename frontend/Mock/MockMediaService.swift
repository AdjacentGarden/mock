import CryptoKit
import Foundation

/// Local media fixtures and timings. No URLSession, provider, API key or backend
/// participates in generation. Any uploaded PDF can use the same demo assets.
@MainActor struct MockMediaService {
  struct Phase {
    var status: String
    var message: String
    var progress: Double
    var milliseconds: Int
  }

  static var capabilities: StudioCapabilities {
    StudioCapabilities(image: true, video: true, voice_notes: true, notes_ai: true,
      draft_scope: "local-mock", video_seconds: 6, image_estimate: nil, video_estimate: nil,
      media_notice: nil, video_notice: nil, image_width: nil, image_height: nil,
      video_resolution: nil, video_requires_image: false)
  }

  static func phases(kind: LearningMediaKind) -> [Phase] {
    [Phase(status: "planning", message: "正在整理讲解思路", progress: 0.4, milliseconds: 600),
     Phase(status: "polling", message: kind == .image ? "正在生成辅助图解" : "正在生成讲解短片",
       progress: 0.85, milliseconds: 650)]
  }

  static func pause(milliseconds: Int) async throws {
    try await Task.sleep(for: .milliseconds(milliseconds))
    try Task.checkCancellation()
  }

  let request: LessonMediaRequest
  let metadataRoot: URL
  let artifactRoot: URL

  private var historyURL: URL {
    let fixtureScope = MockBookContent.contentBookID(bookID: request.bookID, chapterID: request.chapterID) == nil ? "biology-v1" : "catalog-v2"
    let scope = [request.courseID, request.bookID, request.kind, fixtureScope].joined(separator: "|")
    let key = SHA256.hash(data: Data(scope.utf8)).map { String(format: "%02x", $0) }.joined()
    return metadataRoot.appendingPathComponent(key + ".json")
  }

  func history() throws -> [StudioJob] {
    guard FileManager.default.fileExists(atPath: historyURL.path) else { return [] }
    return try JSONDecoder().decode([StudioJob].self, from: Data(contentsOf: historyURL))
      .filter { $0.book_id == request.bookID && $0.kind == request.kind }
      .sorted { ($0.created ?? 0) > ($1.created ?? 0) }
  }

  func makeJob(status: String) -> StudioJob {
    let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    return StudioJob(id: id, book_id: request.bookID, kind: request.kind, status: status,
      result: [:], error: nil, asset_url: nil, request_id: "mock_" + id,
      created: Date().timeIntervalSince1970, excerpt: request.excerpt, chapter_title: request.chapterTitle)
  }

  func save(_ job: StudioJob) throws {
    try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)
    var values = try history().filter { $0.id != job.id }
    values.insert(job, at: 0)
    try JSONEncoder().encode(values).write(to: historyURL, options: .atomic)
  }

  func artifactURL(_ job: StudioJob) -> URL? {
    guard LessonMediaJobContract.validJobID(job.id), ["image", "video"].contains(job.kind) else { return nil }
    return artifactRoot.appendingPathComponent("mock-" + job.id + (job.kind == "image" ? ".png" : ".mp4"))
  }

  func complete(_ pending: StudioJob) throws -> StudioJob {
    let topic = MockBookContent.topic(bookID: request.bookID, chapterID: request.chapterID)
    let contentBook = MockBookContent.contentBookID(bookID: request.bookID, chapterID: request.chapterID)
    let path: String
    if let topic, let contentBook {
      path = MockBookContent.mediaPath(bookID: contentBook, chapterID: topic.chapter_id, kind: request.kind)
    } else {
      path = request.kind == "image" ? imageFixture : "assets/lesson/meiosis-explainer-demo-v1.mp4"
    }
    guard let source = ContentBundle.url(path), let target = artifactURL(pending) else {
      throw ContentError.missing("本地图解或视频素材")
    }
    try FileManager.default.createDirectory(at: artifactRoot, withIntermediateDirectories: true)
    // Each generation owns its artifact. Regenerating or returning to history
    // never overwrites another result, including results attached to notes.
    if FileManager.default.fileExists(atPath: target.path) {
      try FileManager.default.removeItem(at: target)
    }
    try FileManager.default.copyItem(at: source, to: target)
    var completed = pending
    completed.status = "succeeded"
    completed.error = nil
    completed.result = ["title": .string(request.kind == "image" ? request.chapterTitle + " · 辅助图解" : request.chapterTitle + " · 讲解短片"),
      "explanation": .string(topic?.summary ?? (request.kind == "image"
        ? "演示图解已准备好。结合课程内容观察概念之间的联系，再完成章节练习。"
        : "观看示例短片，了解染色体复制与细胞两次分裂的过程。")),
      "fixture_version": .string(topic == nil ? "1" : "2"),
      "source": .string("bundled-mock")]
    try save(completed)
    return completed
  }

  private var imageFixture: String {
    let text = (request.chapterTitle + request.title + request.excerpt).lowercased()
    let choices: [(String, String)] = [
      ("复制", "dna-replication-overview-v1.png"),
      ("蛋白质", "protein-synthesis-overview-v1.png"),
      ("遗传密码", "genetic-code-deciphering-overview-v1.png"),
      ("双螺旋", "dna-structure-overview-v1.png"),
      ("伴性", "sex-linked-inheritance-overview-v1.png"),
      ("遗传病", "human-genetic-disease-overview-v1.png"),
      ("染色体变异", "chromosomal-variation-overview-v1.png"),
      ("突变", "gene-mutation-recombination-overview-v1.png"),
      ("性状", "gene-trait-control-overview-v1.png"),
      ("自由组合", "mendel-dihybrid-overview-v1.png"),
    ]
    let filename = choices.first(where: { text.contains($0.0) })?.1 ?? "mendel-monohybrid-overview-v1.png"
    return "assets/lesson/" + filename
  }
}
