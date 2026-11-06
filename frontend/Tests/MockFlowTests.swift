import Foundation
import UIKit
import XCTest
@testable import BookCourse

/// Exercises the same local commands used by the PDF picker and course screens.
/// A blank PDF deliberately supplies no source text for OCR or content generation.
@MainActor final class MockFlowTests: XCTestCase {
  private func waitFor(_ description: String, timeout: Duration = .seconds(15),
    condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(40))
    }
    XCTAssertTrue(condition(), description)
  }

  private func blankPDF(in directory: URL) throws -> URL {
    let url = directory.appendingPathComponent("任意空白教材.pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 420))
    let data = renderer.pdfData { context in context.beginPage() }
    try data.write(to: url)
    return url
  }

  func testPDFToLearningAndPracticeWorksWithoutBackendOrPDFText() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mock-flow-" + UUID().uuidString)
    let repository = try LocalBookCourseRepository(directory: directory, includeFixtures: false)
    let store = AppStore(repository: repository, cloud: nil)
    defer { store.suspendCourseUploads() }
    await store.boot()
    XCTAssertNil(store.cloud)
    XCTAssertNil(CloudAPI.configured(), "The mock app must never pick up a real service configuration")
    XCTAssertNil(store.bootError)

    store.route = .study
    store.draft.name = "本地 PDF 演示"
    let uploadID = try XCTUnwrap(store.beginCourseUpload([blankPDF(in: directory)]))
    try await waitFor("Upload must expose intermediate progress") {
      store.uploadState.batches.first { $0.id == uploadID }?.files.contains {
        $0.status == .uploading && $0.fraction > 0 && $0.fraction < 1
      } == true
    }
    try await waitFor("Simulated upload should complete") {
      store.uploadState.batches.first { $0.id == uploadID }?.isComplete == true
    }
    let batch = try XCTUnwrap(store.uploadState.batches.first { $0.id == uploadID })
    let bookID = try XCTUnwrap(batch.files.first?.bookID)
    XCTAssertNotNil(store.sourceFileURL(bookID), "The PDF should remain on the device")
    XCTAssertEqual(batch.files.first?.fraction, 1)

    store.continueCourseUpload(uploadID)
    let preparation = Task { @MainActor in await store.processImport() }
    try await waitFor("Parsing/preprocessing must expose progress") {
      store.processingProgress > 0 && store.processingProgress < 1
        && store.importJob?.status == .running
    }
    await preparation.value
    XCTAssertNil(store.importError)
    XCTAssertTrue(store.draft.parseCompleted)
    XCTAssertEqual(store.importJob?.status, .completed)
    XCTAssertFalse(store.chapters.isEmpty)

    store.confirmChapters()
    try await waitFor("Course generation must show a loading state") { store.mockCourseGenerating }
    try await waitFor("Mock learning content should finish generating") { !store.mockCourseGenerating }
    XCTAssertNil(store.mockCourseGenerationError)
    XCTAssertTrue(store.hasStudyContent)
    XCTAssertNil(store.studyCoursePreparation, "The finished course must be usable immediately")
    XCTAssertFalse(store.lessons.isEmpty)
    XCTAssertFalse(store.currentSource?.flashcards.isEmpty ?? true)
    XCTAssertFalse(store.currentSource?.quizzes.isEmpty ?? true)
    XCTAssertFalse(store.plan?.tasks.isEmpty ?? true)

    let lesson = try XCTUnwrap(store.lessons.first { ["ready", "generated"].contains($0.status) })
    store.openLesson(lesson)
    XCTAssertEqual(store.route, .lesson)
    XCTAssertEqual(store.activeLesson?.id, lesson.id)
    let card = try XCTUnwrap(store.flashcards.first)
    store.setMastery(card.id, mastered: true)
    XCTAssertTrue(store.isMastered(card.id))
    let question = try XCTUnwrap(store.quizzes.first)
    store.submitAssignment(question: question, answer: question.answer)
    try await waitFor("Practice must produce feedback") { store.latestDiagnosis != nil }
    XCTAssertEqual(store.latestDiagnosis?.assignment_id, question.id)
    XCTAssertFalse(store.latestDiagnosis?.mistake_recorded ?? true)
    store.completeLesson()
    XCTAssertTrue(store.completedChapterIDs.contains(lesson.chapter_id))
    let courseID = try XCTUnwrap(store.selectedCourseID)
    await store.flush()
    store.suspendCourseUploads()

    let reopened = AppStore(repository: try LocalBookCourseRepository(directory: directory, includeFixtures: false), cloud: nil)
    defer { reopened.suspendCourseUploads() }
    await reopened.boot()
    reopened.selectCourse(courseID)
    XCTAssertNil(reopened.bootError)
    XCTAssertTrue(reopened.hasStudyContent)
    XCTAssertNotNil(reopened.sourceFileURL(bookID))
    XCTAssertTrue(reopened.isMastered(card.id))
    XCTAssertTrue(reopened.completedChapterIDs.contains(lesson.chapter_id))
  }

  func testAddingPDFKeepsExistingMaterialsLessonsAndProgress() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mock-add-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: directory, includeFixtures: true), cloud: nil)
    defer { store.suspendCourseUploads() }
    await store.boot()
    let original = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains("book_biology_2") })
    store.selectCourse(original.id)
    let firstLesson = try XCTUnwrap(store.lessons.first)
    store.openLesson(firstLesson)
    store.completeLesson()
    let oldLessons = store.lessons
    let uploadID = try XCTUnwrap(store.beginCourseUpload([blankPDF(in: directory)], targetCourseID: original.id))
    try await waitFor("Added PDF should upload") { store.uploadState.batches.first { $0.id == uploadID }?.isComplete == true }
    store.continueCourseUpload(uploadID)
    XCTAssertTrue(store.draft.resourceIDs.contains("book_biology_2"))
    await store.processImport()
    XCTAssertEqual(store.sources.first { $0.id == "book_biology_2" }?.lessons, oldLessons)
    store.confirmChapters()
    try await waitFor("Added materials should finish generating") { !store.mockCourseGenerating }
    XCTAssertNil(store.mockCourseGenerationError)
    XCTAssertEqual(store.currentCourse?.resourceIDs.count, 2)
    XCTAssertTrue(store.currentCourse?.resourceIDs.contains("book_biology_2") == true)
    store.selectSource("book_biology_2")
    XCTAssertEqual(store.lessons, oldLessons)
    XCTAssertTrue(store.completedChapterIDs.contains(firstLesson.chapter_id))
    await store.flush()
  }

  func testCancelledMockUploadCanRetryUsingItsSavedLocalOriginal() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mock-retry-" + UUID().uuidString)
    let repository = try LocalBookCourseRepository(directory: directory, includeFixtures: false)
    let store = AppStore(repository: repository, cloud: nil)
    defer { store.suspendCourseUploads() }
    await store.boot()
    let uploadID = try XCTUnwrap(store.beginCourseUpload([blankPDF(in: directory)]))
    try await waitFor("Upload must begin before cancellation") {
      store.uploadState.batches.first { $0.id == uploadID }?.files.first?.status == .uploading
    }
    store.cancelCourseUpload(uploadID)
    let paused = try XCTUnwrap(store.uploadState.batches.first { $0.id == uploadID })
    XCTAssertEqual(paused.files.first?.status, .cancelled)
    XCTAssertFalse(paused.isComplete)
    let localPath = try XCTUnwrap(paused.files.first?.relativePath)
    XCTAssertTrue(FileManager.default.fileExists(atPath: repository.attachmentURL(localPath).path))
    store.retryCourseUpload(uploadID)
    try await waitFor("Retry should finish without selecting the PDF again") {
      store.uploadState.batches.first { $0.id == uploadID }?.isComplete == true
    }
    XCTAssertEqual(store.uploadState.batches.first { $0.id == uploadID }?.files.first?.relativePath, localPath)
    await store.flush()
  }
}
