import Foundation
import XCTest
@testable import BookCourse

@MainActor final class MockLiveSkillTests: XCTestCase {
  private func makeStore() throws -> (AppStore, URL, AgentFrozenContext) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-skills-" + UUID().uuidString)
    let repository = try LocalBookCourseRepository(directory: folder, includeFixtures: false)
    let store = AppStore(repository: repository, cloud: nil)
    store.courses = [
      Course(id: "course-a", name: "课程 A", resourceIDs: ["shared-book"], activeResourceID: "shared-book"),
      Course(id: "course-b", name: "课程 B", resourceIDs: ["shared-book", "other-book"], activeResourceID: "other-book")]
    store.sources = [source("shared-book", chapter: "chapter-a", content: "冻结课程的真实本机课文"),
      source("other-book", chapter: "chapter-b", content: "另一份教材")]
    // The visible selection differs deliberately from the conversation's frozen course.
    store.selectedCourseID = "course-b"; store.selectedBookID = "other-book"
    let context = AgentFrozenContext(scope: LocalBookCourseRepository.localNoteScope, courseID: "course-a",
      bookID: "shared-book", bookTitle: "教材 shared-book", sourceVersion: "v1", chapterID: "chapter-a",
      page: 2, printedPage: nil, selection: "冻结选区", currentNoteID: nil, capturedAt: .now)
    return (store, folder, context)
  }

  private func source(_ id: String, chapter: String, content: String) -> SourceContent {
    let chapter = Chapter(chapter_id: chapter, level: 1, source_title: "第一节", ai_title: "", page_start: 1,
      page_end: 10, confidence: 1, status: "ready", source: "local")
    let block = LessonBlock(block_id: id + "-block", block_type: "text", title: "教学内容", content: content,
      citations: [], source_chunk_ids: [], asset_ids: [], ai_generated: false)
    let lesson = Lesson(book_id: id, lesson_id: id + "-lesson", chapter_id: chapter.id, title: "当前课文",
      source_title: "原文", page_start: 1, page_end: 10, lesson_kind: "reading", status: "ready", confidence: 1,
      objectives: ["理解课文"], key_concepts: ["概念"], summary: content, blocks: [block], source_chunk_ids: [],
      asset_ids: [], warnings: [])
    return SourceContent(summary: SourceSummary(book_id: id, title: "教材 " + id, status: "ready", page_count: 10,
      chapter_count: 1, chunk_count: 0, asset_count: 0, average_confidence: 1, updated_at: 1),
      chapters: [chapter], lessons: [lesson], chunks: [], assets: [], flashcards: [], quizzes: [],
      plan: StudyPlan(user_id: "local", book_id: id, days: 1, daily_minutes: 10, tasks: []))
  }

  private func decode(_ result: LiveSkillResult) throws -> [String: JSONValue] {
    try JSONDecoder().decode([String: JSONValue].self, from: Data(result.content.utf8))
  }

  private func rejected(_ name: String, _ arguments: [String: JSONValue], context: AgentFrozenContext,
    store: AppStore, operationID: String = UUID().uuidString, file: StaticString = #filePath, line: UInt = #line) async {
    do {
      _ = try await LiveAssistantSkills.execute(name: name, arguments: arguments, context: context,
        operationID: operationID, store: store)
      XCTFail("Invalid tool must fail before changing local data", file: file, line: line)
    } catch { }
  }

  func testCreateNoteUsesFrozenOwnershipAndCommitsOnceAcrossReopen() async throws {
    let (store, folder, context) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let args: [String: JSONValue] = ["title": .string("课文笔记"), "body": .string("由模型生成的完整正文")]
    async let firstCall = LiveAssistantSkills.execute(name: "create_note", arguments: args, context: context,
      operationID: "create-once", store: store)
    async let secondCall = LiveAssistantSkills.execute(name: "create_note", arguments: args, context: context,
      operationID: "create-once", store: store)
    let (first, second) = try await (firstCall, secondCall)
    let id = try XCTUnwrap(first.noteID)
    XCTAssertEqual(second.noteID, id)
    XCTAssertEqual(store.notes.count, 1)
    let note = try XCTUnwrap(store.notes.first)
    XCTAssertEqual(note.anchor?.courseID, "course-a")
    XCTAssertEqual(note.anchor?.bookID, "shared-book")
    XCTAssertEqual(note.anchor?.chapterID, "chapter-a")
    XCTAssertEqual(note.anchor?.courseResourceID, store.courseResourceID(courseID: "course-a", bookID: "shared-book"))
    XCTAssertEqual(note.provenance?.sourceLabel, "deepseek")
    XCTAssertEqual(store.noteState.revisions[id], 1)
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: false)
    let restored = try await reopened.loadStoredNote(id, scope: context.scope)
    XCTAssertEqual(restored?.note.body, "由模型生成的完整正文")
    XCTAssertEqual(restored?.revision, 1)
    await rejected("create_note", ["title": .string("更改参数"), "body": .string("不能覆盖原笔记")],
      context: context, store: store, operationID: "create-once")
    XCTAssertEqual(store.notes.first?.title, "课文笔记")
    XCTAssertEqual(try decode(first)["ok"], .bool(true))
  }

  func testUpdateHasRevisionProtectionAndCannotWriteAnotherCoursesNote() async throws {
    let (store, folder, context) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let created = try await LiveAssistantSkills.execute(name: "create_note", arguments: ["title": .string("原题"),
      "body": .string("原文")], context: context, operationID: "new", store: store)
    let id = try XCTUnwrap(created.noteID)
    let edit: [String: JSONValue] = ["note_id": .string(id), "revision": .number(1), "body": .string("修改后的正文")]
    let saved = try await LiveAssistantSkills.execute(name: "update_note", arguments: edit, context: context,
      operationID: "edit", store: store)
    let replayed = try await LiveAssistantSkills.execute(name: "update_note", arguments: edit, context: context,
      operationID: "edit", store: store)
    XCTAssertEqual(saved.content, replayed.content)
    XCTAssertEqual(store.noteState.revisions[id], 2)
    XCTAssertEqual(store.notes.first?.body, "修改后的正文")
    await rejected("update_note", edit, context: context, store: store, operationID: "stale-edit")
    await rejected("update_note", ["course_id": .string("course-b"), "note_id": .string(id),
      "revision": .number(2), "title": .string("错课程")], context: context, store: store)
    let read = try await LiveAssistantSkills.execute(name: "read_note", arguments: ["note_id": .string(id)],
      context: context, operationID: "read", store: store)
    XCTAssertNil(read.noteID, "Read operations must not look like note creation in run progress")
    XCTAssertEqual(try decode(read)["revision"], .number(2))
    XCTAssertEqual(try decode(read)["body"], .string("修改后的正文"))
  }

  func testFlashcardsAndReviewTaskAreDurableAndVisibleInExistingAppViews() async throws {
    let (store, folder, context) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let cards: [String: JSONValue] = ["cards": .array([
      .object(["front": .string("问题一"), "back": .string("答案一"), "concept": .string("概念一")]),
      .object(["front": .string("问题二"), "back": .string("答案二")])])]
    let first = try await LiveAssistantSkills.execute(name: "create_flashcards", arguments: cards,
      context: context, operationID: "cards", store: store)
    _ = try await LiveAssistantSkills.execute(name: "create_flashcards", arguments: cards,
      context: context, operationID: "cards", store: store)
    let task: [String: JSONValue] = ["title": .string("复习本节概念"), "date": .string("2026-11-07"), "minutes": .number(15)]
    let review = try await LiveAssistantSkills.execute(name: "create_review_task", arguments: task,
      context: context, operationID: "review", store: store)
    _ = try await LiveAssistantSkills.execute(name: "create_review_task", arguments: task,
      context: context, operationID: "review", store: store)
    XCTAssertEqual(store.assistantState.learningObjects.count, 3)
    store.selectedCourseID = "course-a"; store.selectedBookID = "shared-book"
    XCTAssertEqual(store.agentFlashcards.map(\.front), ["问题一", "问题二"])
    XCTAssertEqual(store.agentPlanTasks(courseID: "course-a", date: "2026-11-07").first?.minutes, 15)
    XCTAssertEqual(store.dailyStudyPlan("2026-11-07")?.tasks.first?.title, "复习本节概念")
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: false)
    let objects = try await reopened.loadAgentLearningObjects(scope: context.scope)
    XCTAssertEqual(objects.count, 3)
    XCTAssertTrue(objects.allSatisfy { $0.course_id == "course-a" && $0.data["book_id"] == .string("shared-book") })
    XCTAssertTrue(first.content.contains("live-object:"))
    XCTAssertTrue(review.content.contains("live-object:"))
  }

  func testMissingCourseReturnsChoicesAndAmbiguousBookRequiresSelection() async throws {
    let (store, folder, original) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    var context = original; context.courseID = nil
    let args: [String: JSONValue] = ["title": .string("新笔记"), "body": .string("正文")]
    let choice = try await LiveAssistantSkills.execute(name: "create_note", arguments: args, context: context,
      operationID: "choose", store: store)
    XCTAssertEqual(try decode(choice)["status"], .string("requires_course"))
    XCTAssertEqual(try decode(choice)["ok"], .bool(false))
    XCTAssertTrue(choice.content.contains("course-a")); XCTAssertTrue(choice.content.contains("course-b"))
    var other = args; other["course_id"] = .string("course-b")
    let book = try await LiveAssistantSkills.execute(name: "create_note", arguments: other, context: context,
      operationID: "choose-book", store: store)
    XCTAssertEqual(try decode(book)["status"], .string("requires_book"))
    XCTAssertTrue(store.notes.isEmpty)
    let rows = try await store.repository.loadStoredNotes(scope: context.scope)
    XCTAssertTrue(rows.isEmpty)
  }

  func testInvalidModelArgumentsNeverProduceArtifacts() async throws {
    let (store, folder, context) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let valid: [String: JSONValue] = ["title": .string("标题"), "body": .string("正文")]
    for extra: [String: JSONValue] in [
      ["book_id": .string("other-book")], ["chapter_id": .string("chapter-b")], ["page": .number(2.5)],
      ["page": .number(11)], ["title": .string("   ")], ["body": .bool(true)], ["url": .string("https://example.com")]
    ] {
      await rejected("create_note", valid.merging(extra) { _, new in new }, context: context, store: store)
    }
    await rejected("create_flashcards", ["cards": .array([])], context: context, store: store)
    await rejected("create_flashcards", ["cards": .array([.object(["front": .string("只有问题")])])], context: context, store: store)
    await rejected("create_review_task", ["title": .string("复习"), "date": .string("2026-02-30")], context: context, store: store)
    await rejected("create_review_task", ["title": .string("复习"), "minutes": .number(1.5)], context: context, store: store)
    await rejected("delete_note", ["note_id": .string("missing")], context: context, store: store)
    var foreign = context; foreign.scope = "another-account"
    await rejected("create_note", valid, context: foreign, store: store)
    XCTAssertTrue(store.notes.isEmpty)
    XCTAssertTrue(store.assistantState.learningObjects.isEmpty)
    let notes = try await store.repository.loadStoredNotes(scope: context.scope)
    let objects = try await store.repository.loadAgentLearningObjects(scope: context.scope)
    XCTAssertTrue(notes.isEmpty); XCTAssertTrue(objects.isEmpty)
  }

  func testReadsFrozenLessonAndOnlyListsRequestedCoursesNotes() async throws {
    let (store, folder, context) = try makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let read = try await LiveAssistantSkills.execute(name: "read_current_lesson", arguments: [:], context: context,
      operationID: "lesson", store: store)
    XCTAssertEqual(try decode(read)["book_id"], .string("shared-book"))
    XCTAssertEqual(try decode(read)["selection"], .string("冻结选区"))
    XCTAssertTrue(read.content.contains("冻结课程的真实本机课文"))
    _ = try await LiveAssistantSkills.execute(name: "create_note", arguments: ["title": .string("A 的笔记"),
      "body": .string("正文")], context: context, operationID: "note-a", store: store)
    let list = try await LiveAssistantSkills.execute(name: "list_notes", arguments: ["course_id": .string("course-b")],
      context: context, operationID: "notes-b", store: store)
    XCTAssertEqual(try decode(list)["total"], .number(0))
  }
}
