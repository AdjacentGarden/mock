import Foundation
import XCTest
@testable import BookCourse

private final class MockCatalogNetworkTrap: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var requests = 0
  static func reset() { lock.lock(); defer { lock.unlock() }; requests = 0 }
  static var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
  override class func canInit(with request: URLRequest) -> Bool {
    ["http", "https"].contains(request.url?.scheme ?? "")
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock(); Self.requests += 1; Self.lock.unlock()
    client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
  }
  override func stopLoading() { }
}

@MainActor final class MockCatalogTests: XCTestCase {
  func testEveryDirectoryOnlyCatalogHasLearningPracticeFlashcardsAndPlanWithoutNetwork() throws {
    MockCatalogNetworkTrap.reset()
    URLProtocol.registerClass(MockCatalogNetworkTrap.self)
    defer { URLProtocol.unregisterClass(MockCatalogNetworkTrap.self) }
    let originals = try ContentBundle.load([SourceContent].self, name: "sources").filter { $0.lessons.isEmpty }
    XCTAssertFalse(originals.isEmpty)
    for original in originals {
      let source = MockCatalogService.source(from: original)
      let parents = Set(original.chapters.compactMap(\.parent_id))
      let leaves = original.chapters.filter { !parents.contains($0.id) }
      XCTAssertEqual(source.id, original.id)
      XCTAssertEqual(source.chapters, original.chapters, "Discovery outlines must keep their original IDs and titles")
      XCTAssertEqual(Set(source.lessons.map(\.chapter_id)), Set(leaves.map(\.id)))
      XCTAssertTrue(source.lessons.allSatisfy { $0.status == "ready" && $0.book_id == original.id && !$0.blocks.isEmpty })
      for chapter in leaves {
        XCTAssertTrue(source.flashcards.contains { $0.chapter_id == chapter.id && !$0.back.isEmpty })
        let questions = source.quizzes.filter { $0.chapter_id == chapter.id }
        XCTAssertEqual(Set(questions.compactMap(\.question_type)), ["judgment", "choice", "short-answer"])
        XCTAssertTrue(questions.allSatisfy { !$0.answer.isEmpty && $0.source_kind == "mock_authored" })
        XCTAssertTrue(source.plan.tasks.contains { $0.chapter_id == chapter.id && $0.task_type == "learn" })
      }
      XCTAssertTrue(source.lessons.allSatisfy { $0.blocks.allSatisfy { block in
        block.citations.allSatisfy { $0.source_metadata?["source_kind"] == .string("mock_handout") }
      } }, "Authored examples must identify their local handout source")
      XCTAssertEqual(MockCatalogService.source(from: source), source, "Opening or importing again keeps progress and content")
    }
    XCTAssertEqual(MockCatalogNetworkTrap.count, 0)
  }

  func testExistingTeachingContentIsPreserved() throws {
    let biology = try XCTUnwrap(ContentBundle.load([SourceContent].self, name: "sources").first { !$0.lessons.isEmpty })
    XCTAssertEqual(MockCatalogService.source(from: biology), biology)
  }
}
