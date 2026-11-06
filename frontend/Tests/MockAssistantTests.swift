import Foundation
import XCTest
@testable import BookCourse

@MainActor final class MockAssistantTests: XCTestCase {
  private func makeStore() async throws -> (AppStore, URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mock-assistant-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: folder, includeFixtures: true), cloud: nil)
    await store.boot()
    XCTAssertNil(store.bootError)
    XCTAssertNil(store.cloud)
    let course = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains("book_biology_2") })
    store.selectCourse(course.id)
    store.selectSource("book_biology_2")
    store.route = .lesson
    return (store, folder)
  }

  private func waitFor(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(3)
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertTrue(condition())
  }

  func testUnifiedReplyExposesLoadingAndWorksWithoutCloud() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let context = store.agent.frozenContext(session: store.assistantSessionContext)
    let request = Task { @MainActor in
      try await store.agent.answerUnified(sessionID: "demo", messageID: "message", request: "安排今天的学习计划",
        context: context, history: [], attachments: [], ephemeral: false)
    }
    try await waitFor { store.agent.isWorking }
    XCTAssertEqual(store.agent.active?.status, .running)
    XCTAssertNil(store.agent.active?.finalText)
    let answer = try await request.value
    XCTAssertTrue(answer.text.contains("25 分钟"))
    XCTAssertEqual(answer.sourceLabel, "mock")
    XCTAssertTrue(answer.citations.isEmpty)
    XCTAssertFalse(store.agent.isWorking)
    XCTAssertEqual(store.agent.active?.status, .completed)
    XCTAssertNil(DeveloperSecrets.key())
    await store.flush()
  }

  func testSelectionCanSaveLocalNoteAndSurvivesRepositoryReload() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    var context = store.agent.frozenContext(session: store.assistantSessionContext)
    context.selection = "染色体复制一次，细胞连续分裂两次。"
    XCTAssertNotNil(context.courseID)
    let answer = try await store.agent.answerUnified(sessionID: "note-demo", messageID: "note-message",
      request: "把这段整理成笔记并保存", context: context, history: [], attachments: [], ephemeral: false)
    XCTAssertTrue(answer.text.contains("已将这段学习要点保存"))
    let id = try XCTUnwrap(store.agent.active?.committedNoteIDs.first)
    let note = try XCTUnwrap(store.notes.first { $0.id == id })
    XCTAssertEqual(note.anchor?.bookID, context.bookID)
    XCTAssertEqual(note.anchor?.quote, context.selection)
    await store.flush()
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: true)
    let restored = try await reopened.loadStoredNote(id, scope: try XCTUnwrap(store.noteScope))
    XCTAssertEqual(restored?.note.body, note.body)
  }

  func testCancelStopsReplyBeforeNoteWriteAndAllowsRetry() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    var context = store.agent.frozenContext(session: store.assistantSessionContext)
    context.selection = "被取消的演示内容"
    let before = store.notes.count
    let request = Task { @MainActor in
      try await store.agent.answerUnified(sessionID: "cancel-demo", messageID: "cancel-message",
        request: "保存笔记", context: context, history: [], attachments: [], ephemeral: false)
    }
    try await waitFor { store.agent.isWorking }
    store.agent.cancel()
    do { _ = try await request.value; XCTFail("Cancelled demo must not publish a reply") }
    catch is CancellationError { }
    XCTAssertEqual(store.notes.count, before)
    XCTAssertEqual(store.agent.active?.status, .cancelled)
    XCTAssertFalse(store.agent.isWorking)
    let retry = try await store.agent.answerUnified(sessionID: "cancel-demo", messageID: "retry-message",
      request: "你好", context: context, history: [], attachments: [], ephemeral: false)
    XCTAssertTrue(retry.text.contains("你好"))
    await store.flush()
  }

  func testPhotoAndVoiceGenerationReportPhasesAndReturnCompleteLocalData() async throws {
    var photoPhases: [String] = []
    let job = try await MockAssistantService.photo(bookID: "book_local_demo", imageHash: "local-hash") { photoPhases.append($0) }
    XCTAssertEqual(photoPhases, ["transcribing", "organizing"])
    XCTAssertEqual(job.status, "succeeded")
    XCTAssertEqual(job.book_id, "book_local_demo")
    XCTAssertFalse(job.transcript.isEmpty)
    XCTAssertFalse(job.polished.isEmpty)
    var voicePhases: [String] = []
    let text = try await MockAssistantService.voice { voicePhases.append($0) }
    XCTAssertEqual(voicePhases, ["transcribing", "organizing"])
    XCTAssertFalse(text.isEmpty)
    let controller = NotesAudioController()
    await controller.start()
    XCTAssertTrue(controller.isSample)
    let file = try XCTUnwrap(controller.audioURL)
    XCTAssertTrue(file.isFileURL)
    try await Task.sleep(for: .milliseconds(450))
    controller.stop()
    XCTAssertGreaterThan(controller.seconds, 0)
    XCTAssertGreaterThan(try Data(contentsOf: file).count, 44)
    controller.shutdown()
    try? FileManager.default.removeItem(at: file)
  }

  func testConfiguredVoiceInputUsesAnEditableMockDraftWithoutPermissions() async throws {
    let input = AssistantVoiceInput.configured()
    input.enterVoice()
    input.beginHold()
    XCTAssertEqual(input.phase, .recording)
    try await Task.sleep(for: .milliseconds(400))
    input.endHold()
    XCTAssertEqual(input.phase, .transcribing)
    try await waitFor { input.phase == .text }
    XCTAssertTrue(input.draft.contains("减数分裂"))
    XCTAssertNil(input.error)
    input.returnToText()
  }
  func testPDFAttachmentOnlyCopiesBytesAndProvidesPresetText() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let input = folder.appendingPathComponent("无正文示例.pdf")
    // Intentionally has no PDF page tree: success proves the mock importer does not parse it.
    let bytes = Data("%PDF-1.4\n% demo without document text or pages\n%%EOF".utf8)
    try bytes.write(to: input)
    let phases = ProgressRecorder()
    let attachment = try await AssistantAttachmentImporter.file(input, repository: store.repository) { phases.append($0) }
    XCTAssertEqual(attachment.kind, .document)
    XCTAssertEqual(try Data(contentsOf: store.attachmentURL(attachment.path)), bytes)
    let textPath = try XCTUnwrap(attachment.textPath)
    let text = try String(contentsOf: store.attachmentURL(textPath), encoding: .utf8)
    XCTAssertTrue(text.contains("未解析附件正文"))
    XCTAssertGreaterThan(attachment.characterCount ?? 0, 0)
    XCTAssertEqual(phases.values.last, "附件准备完成")
    XCTAssertGreaterThanOrEqual(phases.values.count, 3)
    let capability = await store.appleTextbookSearch.capability()
    XCTAssertEqual(capability.mode, .lexical)
    await store.flush()
  }

}

private final class ProgressRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var items: [String] = []
  func append(_ value: String) { lock.lock(); items.append(value); lock.unlock() }
  var values: [String] { lock.lock(); defer { lock.unlock() }; return items }
}
