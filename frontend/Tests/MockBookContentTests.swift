import AVFoundation
import XCTest
@testable import BookCourse

@MainActor final class MockBookContentTests: XCTestCase {
  func testEveryOtherBookHasBiologyLevelCoverageAndMatchingLocalMedia() throws {
    let originals = try ContentBundle.load([SourceContent].self, name: "sources") + MockBookContent.extraSources
    var count = 0
    for id in MockBookContent.bookIDs {
      let book = try XCTUnwrap(MockBookContent.book(id), id)
      let original = try XCTUnwrap(originals.first { $0.id == id })
      let parents = Set(original.chapters.compactMap(\.parent_id))
      let leaves = Set(original.chapters.filter { !parents.contains($0.id) }.map(\.id))
      XCTAssertEqual(Set(book.topics.map(\.chapter_id)), leaves, id)
      let source = MockCatalogService.source(from: original)
      XCTAssertEqual(source.summary.content_mode, "mock_catalog_v2")
      XCTAssertEqual(source.lessons.count, leaves.count)
      XCTAssertEqual(source.flashcards.count, leaves.count * 6)
      XCTAssertEqual(source.quizzes.count, leaves.count * 3)
      XCTAssertEqual(source.chunks.count, leaves.count * 4)
      XCTAssertEqual(source.assets.count, leaves.count)
      for topic in book.topics {
        count += 1
        XCTAssertEqual(topic.objectives.count, 3)
        XCTAssertEqual(topic.key_concepts.count, 6)
        XCTAssertEqual(Set(topic.blocks.map(\.block_type)), ["explanation", "diagram", "comparison", "application"])
        XCTAssertEqual(topic.blocks.count, 4)
        XCTAssertEqual(Set(topic.flashcards.map(\.front)).count, 6)
        XCTAssertEqual(Set(topic.quizzes.map(\.question_type)), ["judgment", "choice", "short-answer"])
        for question in topic.quizzes where question.question_type != "short-answer" {
          XCTAssertTrue(question.choices.contains(question.answer), "\(id) \(topic.chapter_id)")
        }
        for block in topic.blocks {
          XCTAssertFalse(block.content.contains("先用一句话说明「"), "Old generic placeholder must be replaced")
          XCTAssertGreaterThanOrEqual(block.content.count, 100, "\(id) \(topic.chapter_id) \(block.title)")
        }
        XCTAssertNotNil(ContentBundle.url(MockBookContent.mediaPath(bookID: id, chapterID: topic.chapter_id, kind: "image")))
        XCTAssertNotNil(ContentBundle.url(MockBookContent.mediaPath(bookID: id, chapterID: topic.chapter_id, kind: "video")))
        XCTAssertNotNil(ContentBundle.url(MockBookContent.handoutPath(bookID: id, chapterID: topic.chapter_id)))
      }
      XCTAssertEqual(MockCatalogService.source(from: source), source)
    }
    XCTAssertEqual(count, 220)
  }

  func testEveryCatalogCourseCanReadAnswerReviewAndOpenItsOwnHandout() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mock-all-books-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: directory, includeFixtures: true))
    await store.boot()
    XCTAssertNil(store.bootError)
    for id in MockBookContent.bookIDs {
      let course = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains(id) }, id)
      store.selectCourse(course.id)
      for lesson in [try XCTUnwrap(store.lessons.first), try XCTUnwrap(store.lessons.last)] {
        store.openLesson(lesson)
        XCTAssertEqual(store.activeLesson?.book_id, id)
        XCTAssertEqual(store.route, .lesson)
        let question = try XCTUnwrap(store.quizzes.first { $0.question_type == "choice" })
        store.submitAssignment(question: question, answer: question.answer)
        XCTAssertEqual(store.latestDiagnosis?.mistake_recorded, false)
        let card = try XCTUnwrap(store.flashcards.first)
        store.setMastery(card.id, mastered: true)
        XCTAssertTrue(store.isMastered(card.id))
        let citation = try XCTUnwrap(lesson.blocks.first?.citations.first)
        store.openCitation(citation)
        XCTAssertEqual(store.route, .source)
        XCTAssertEqual(store.sourceTarget?.bookID, id)
        XCTAssertNotNil(MockCatalogService.handoutPath(source: store.currentSource, page: citation.page_start))
      }
    }
    await store.flush()
    store.suspendCourseUploads()
  }

  func testOldCatalogLessonsUpgradeWithoutLosingCompletedTasksOrCardMastery() throws {
    var old = try XCTUnwrap(ContentBundle.load([SourceContent].self, name: "sources").first { $0.id == MockBookContent.bookIDs[0] })
    old = MockCatalogService.source(from: old)
    let lessonIDs = old.lessons.map(\.id)
    old.summary.content_mode = "mock_catalog"
    old.lessons[0].summary = "旧版泛化占位课程"
    old.plan.tasks[0].status = "done"
    old.flashcards[0].mastery = 0.8
    let upgraded = MockCatalogService.source(from: old)
    XCTAssertEqual(upgraded.lessons.map(\.id), lessonIDs)
    XCTAssertEqual(upgraded.plan.tasks[0].status, "done")
    XCTAssertEqual(upgraded.flashcards[0].mastery, 0.8)
    XCTAssertFalse(upgraded.lessons[0].summary.contains("旧版泛化"))
  }

  func testPDFTemplatesAndAssistantStayWithinTheirSubject() async throws {
    let originals = try ContentBundle.load([SourceContent].self, name: "sources") + MockBookContent.extraSources
    for id in MockBookContent.bookIDs {
      let original = try XCTUnwrap(originals.first { $0.id == id })
      var local = original
      local.summary.book_id = "book_local_uploaded_" + id
      let prepared = try MockCourseService.preparedSource(from: local, includeLearning: true)
      XCTAssertEqual(prepared.id, local.id)
      XCTAssertTrue(prepared.lessons.allSatisfy { $0.book_id == local.id })
      let chapter = try XCTUnwrap(prepared.lessons.first?.chapter_id)
      let topic = try XCTUnwrap(MockBookContent.topic(bookID: local.id, chapterID: chapter))
      let response = try await MockAssistantService.answer(question: "解释本节知识点", title: original.summary.title,
        bookID: local.id, chapterID: chapter)
      XCTAssertTrue(response.answer.contains(topic.summary))
      XCTAssertFalse(response.answer.contains("减数分裂"))
      let asset = AVURLAsset(url: try XCTUnwrap(ContentBundle.url(MockBookContent.mediaPath(bookID: id, chapterID: chapter, kind: "video"))))
      let playable = try await asset.load(.isPlayable)
      let duration = try await asset.load(.duration)
      XCTAssertTrue(playable)
      XCTAssertEqual(duration.seconds, 6, accuracy: 0.2)
    }
  }
}
