import AVFoundation
import Foundation
import UIKit
import XCTest

@testable import BookCourse

private final class MockMediaNetworkTrap: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var requests = 0
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.requests += 1
    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
  }
  override func stopLoading() { }
}

@MainActor final class MockMediaTests: XCTestCase {
  private func context(kind: String = "image") -> LessonMediaRequest {
    LessonMediaRequest(kind: kind, bookID: "book_local_mock_pdf", chapterID: "chapter-demo",
      chapterTitle: "DNA 的复制", title: "理解复制过程", excerpt: "DNA 的两条链分别作为模板，形成两个新的 DNA 分子。",
      pages: [1], lessonID: "lesson-demo", courseID: "course-mock")
  }

  private func storage() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("mock-media-tests-" + UUID().uuidString)
  }

  func testLocalPDFImageShowsLoadingAndResultAndReopensWithoutAPI() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = CloudMediaModel(api: nil, request: context(), storageRoot: root)
    let load = Task { await model.load() }
    await Task.yield()
    XCTAssertTrue(model.loading)
    XCTAssertFalse(model.canSubmit)
    await load.value
    XCTAssertNil(model.api)
    XCTAssertTrue(model.canSubmit)
    let start = ContinuousClock.now
    let generate = Task { await model.submit() }
    await Task.yield()
    XCTAssertTrue(model.submitting)
    XCTAssertNil(model.imageData)
    await generate.value
    XCTAssertGreaterThanOrEqual(ContinuousClock.now - start, .milliseconds(1500))
    XCTAssertEqual(model.job?.status, "succeeded")
    XCTAssertEqual(model.generationProgress, 1)
    XCTAssertFalse(model.submitting)
    XCTAssertNotNil(UIImage(data: try XCTUnwrap(model.imageData)))
    XCTAssertNil(model.videoURL)
    XCTAssertEqual(model.job?.result["source"], .string("bundled-mock"))
    let reopened = CloudMediaModel(api: nil, request: context(), storageRoot: root)
    await reopened.load()
    XCTAssertEqual(reopened.job?.id, model.job?.id)
    XCTAssertEqual(reopened.receipt?.state, "succeeded")
    XCTAssertEqual(reopened.imageData, model.imageData)
  }

  func testLocalPDFVideoIsPlayableAndSavedToLibraryWithoutSuppliedAPIRequests() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockMediaNetworkTrap.self]
    MockMediaNetworkTrap.requests = 0
    let api = CloudAPI(baseURL: URL(string: "https://mock-media.invalid")!,
      session: URLSession(configuration: config))
    var savedURL: URL?
    let model = CloudMediaModel(api: api, request: context(kind: "video"), storageRoot: root,
      libraryDirectory: root.appendingPathComponent("lesson-media")) { _, url in savedURL = url }
    await model.load()
    await model.submit()
    XCTAssertNil(model.api)
    XCTAssertEqual(MockMediaNetworkTrap.requests, 0)
    XCTAssertEqual(model.job?.status, "succeeded")
    let url = try XCTUnwrap(model.videoURL)
    XCTAssertTrue(url.isFileURL)
    XCTAssertEqual(savedURL, url)
    let asset = AVURLAsset(url: url)
    let playable = try await asset.load(.isPlayable)
    let duration = try await asset.load(.duration)
    XCTAssertTrue(playable)
    XCTAssertGreaterThan(duration.seconds, 0)
  }

  func testRegenerationKeepsIndependentHistoryAndCurrentResult() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = CloudMediaModel(api: nil, request: context(), storageRoot: root)
    await model.load()
    await model.submit()
    let first = try XCTUnwrap(model.job)
    await model.submit()
    let second = try XCTUnwrap(model.job)
    XCTAssertNotEqual(first.id, second.id)
    XCTAssertEqual(model.history.count, 2)
    model.select(first)
    XCTAssertTrue(model.isPreviewingHistory)
    XCTAssertEqual(model.displayedJob?.id, first.id)
    XCTAssertNotNil(model.displayedImageData)
    XCTAssertFalse(model.canSubmit)
    model.returnToCurrent()
    XCTAssertFalse(model.isPreviewingHistory)
    XCTAssertEqual(model.displayedJob?.id, second.id)
    XCTAssertTrue(model.canSubmit)
  }

  func testIndependentRepositoryStorageRootsDoNotShareResults() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let firstRepository = root.appendingPathComponent("session-a")
    let secondRepository = root.appendingPathComponent("session-b")
    let first = CloudMediaModel(api: nil, request: context(),
      storageRoot: firstRepository.appendingPathComponent("mock-media"),
      libraryDirectory: firstRepository.appendingPathComponent("lesson-media"))
    await first.load()
    await first.submit()
    let completedID = try XCTUnwrap(first.job?.id)
    let second = CloudMediaModel(api: nil, request: context(),
      storageRoot: secondRepository.appendingPathComponent("mock-media"),
      libraryDirectory: secondRepository.appendingPathComponent("lesson-media"))
    await second.load()
    XCTAssertNil(second.error)
    XCTAssertNil(second.job)
    XCTAssertNil(second.imageData)
    XCTAssertTrue(second.history.isEmpty)
    XCTAssertTrue(second.canSubmit)
    let service = MockMediaService(request: context(),
      metadataRoot: secondRepository.appendingPathComponent("mock-media"),
      artifactRoot: secondRepository.appendingPathComponent("lesson-media"))
    XCTAssertTrue(try service.history().isEmpty)
    await second.submit()
    XCTAssertEqual(second.job?.status, "succeeded")
    XCTAssertNotEqual(second.job?.id, completedID)
    let reopened = CloudMediaModel(api: nil, request: context(),
      storageRoot: firstRepository.appendingPathComponent("mock-media"),
      libraryDirectory: firstRepository.appendingPathComponent("lesson-media"))
    await reopened.load()
    XCTAssertNil(reopened.error)
    XCTAssertEqual(reopened.job?.id, completedID)
    XCTAssertEqual(reopened.history.count, 1)
    XCTAssertNotNil(reopened.imageData)
  }

  func testLibraryDirectoryAloneAlsoIsolatesMetadata() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let firstLibrary = root.appendingPathComponent("first-library")
    let first = CloudMediaModel(api: nil, request: context(), libraryDirectory: firstLibrary)
    await first.load()
    await first.submit()
    XCTAssertEqual(first.job?.status, "succeeded")
    XCTAssertTrue(FileManager.default.fileExists(atPath:
      firstLibrary.appendingPathComponent(".mock-media").path))
    // These two libraries have the same parent, so using the parent's default
    // metadata directory would leak the first library's task into the second.
    let second = CloudMediaModel(api: nil, request: context(),
      libraryDirectory: root.appendingPathComponent("second-library"))
    await second.load()
    XCTAssertNil(second.error)
    XCTAssertNil(second.job)
    XCTAssertTrue(second.history.isEmpty)
    XCTAssertTrue(second.canSubmit)
  }

  func testCancellationReleasesLoadingAndCanRetry() async throws {
    let root = storage()
    defer { try? FileManager.default.removeItem(at: root) }
    let model = CloudMediaModel(api: nil, request: context(), storageRoot: root)
    await model.load()
    let generate = Task { await model.submit() }
    await Task.yield()
    generate.cancel()
    await generate.value
    XCTAssertFalse(model.submitting)
    XCTAssertEqual(model.job?.status, "cancelled")
    XCTAssertNil(model.imageData)
    XCTAssertTrue(model.canSubmit)
    await model.submit()
    XCTAssertEqual(model.job?.status, "succeeded")
    XCTAssertNotNil(model.imageData)
    XCTAssertTrue(model.history.contains { $0.status == "cancelled" })
  }
}
