import Foundation
import XCTest
@testable import BookCourse

@MainActor final class MockLocalAgentReviewTests: XCTestCase {
  private let day = "2026-11-07"

  private func makeStore() async throws -> (AppStore, URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("local-agent-reviews-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: folder, includeFixtures: true), cloud: nil)
    await store.boot()
    XCTAssertNil(store.bootError)
    let course = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains("book_biology_2") })
    store.selectCourse(course.id)
    store.selectSource("book_biology_2")
    store.route = .lesson
    return (store, folder)
  }

  private func createReview(_ store: AppStore) async throws -> CloudStudyPlanTask {
    let context = store.agent.frozenContext(session: store.assistantSessionContext)
    _ = try await LiveAssistantSkills.execute(name: "create_review_task", arguments: [
      "title": .string("减数分裂复习"), "date": .string(day), "minutes": .number(3),
      "description": .string("回忆染色体复制和细胞分裂次数。")], context: context,
      operationID: "review-test", store: store)
    return try XCTUnwrap(store.localAgentReviewTasks(day: day).first)
  }

  func testReviewDateAndOpeningUseLocalCourseContentWithoutCloud() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let review = try await createReview(store)
    XCTAssertEqual(store.localAgentReviewTasks(day: day).map(\.title), ["减数分裂复习"])
    XCTAssertTrue(store.localAgentReviewTasks(day: "2026-11-08").isEmpty)
    let context = store.agent.frozenContext(session: store.assistantSessionContext)
    _ = try await LiveAssistantSkills.execute(name: "create_flashcards", arguments: [
      "cards": .array([.object(["front": .string("复制几次？"), "back": .string("一次。")])])],
      context: context, operationID: "review-card-test", store: store)
    let courseIndex = try XCTUnwrap(store.courses.firstIndex { $0.id == store.selectedCourseID })
    let otherBook = try XCTUnwrap(store.sources.first { $0.id != review.book_id })
    if !store.courses[courseIndex].resourceIDs.contains(otherBook.id) {
      store.courses[courseIndex].resourceIDs.append(otherBook.id)
    }
    store.selectSource(otherBook.id)
    try store.openLocalAgentReviewTask(review, day: day)
    XCTAssertEqual(store.selectedBookID, review.book_id)
    XCTAssertEqual(store.selectedChapterID, review.chapter_id)
    XCTAssertEqual(store.route, .flashcards)
    XCTAssertNil(store.cloud)
    await store.flush()
  }

  func testCompletingReviewIsDurableAndPreservesNewerLearningObjects() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let review = try await createReview(store)
    let scope = try XCTUnwrap(store.noteScope)
    let courseID = try XCTUnwrap(store.selectedCourseID)
    let original = try XCTUnwrap(store.assistantState.learningObjects.first { $0.id == review.id })
    var newer = original
    newer.id = "later-review"
    newer.data["title"] = .string("后来建立的复习")
    // Simulate another local writer committing after the screen's snapshot.
    try await store.repository.saveAgentLearningObjects(store.assistantState.learningObjects + [newer], scope: scope)
    try await store.completeLocalAgentReviewTask(review, day: day)
    XCTAssertTrue(store.localAgentReviewTasks(day: day).first { $0.id == review.id }?.isDone == true)
    XCTAssertTrue(store.assistantState.learningObjects.contains { $0.id == newer.id })
    try await store.completeLocalAgentReviewTask(review, day: day)
    XCTAssertEqual(store.assistantState.learningObjects.first { $0.id == review.id }?.revision, original.revision + 1)
    await store.flush()
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: true)
    let restored = AppStore(repository: reopened, cloud: nil)
    await restored.boot()
    defer { restored.suspendCourseUploads() }
    restored.selectCourse(courseID)
    XCTAssertTrue(restored.localAgentReviewTasks(day: day).first { $0.id == review.id }?.isDone == true)
    XCTAssertTrue(restored.localAgentReviewTasks(day: day).contains { $0.id == newer.id && !$0.isDone })
    await restored.flush()
  }
}
