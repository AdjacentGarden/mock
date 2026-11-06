import Foundation
import XCTest
@testable import BookCourse

private final class RuntimeModelProtocol: URLProtocol {
  static var responses: [(Int, String)] = []
  static var delay: TimeInterval = 0
  private var work: DispatchWorkItem?
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let response = Self.responses.isEmpty ? (500, "{}") : Self.responses.removeFirst()
    let item = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.client?.urlProtocol(self, didReceive: HTTPURLResponse(url: self.request.url!, statusCode: response.0,
        httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
      self.client?.urlProtocol(self, didLoad: Data(response.1.utf8))
      self.client?.urlProtocolDidFinishLoading(self)
    }
    work = item
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: item)
  }
  override func stopLoading() { work?.cancel() }
}

@MainActor final class MockDeepSeekRuntimeTests: XCTestCase {
  private func makeStore() async throws -> (AppStore, URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("live-runtime-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: folder, includeFixtures: true), cloud: nil)
    await store.boot()
    let course = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains("book_biology_2") })
    store.selectCourse(course.id); store.selectSource("book_biology_2"); store.route = .lesson
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RuntimeModelProtocol.self]
    store.agent.liveClientOverride = DeepSeekClient(apiKey: "test-key", session: URLSession(configuration: configuration))
    RuntimeModelProtocol.delay = 0
    return (store, folder)
  }

  private func completion(_ content: String, tools: [[String: Any]] = []) throws -> String {
    let message: [String: Any] = ["content": content, "tool_calls": tools]
    return String(decoding: try JSONSerialization.data(withJSONObject: ["choices": [["message": message, "finish_reason": "stop"]]]), as: UTF8.self)
  }
  private func noteCall() -> [String: Any] {
    ["id": "call-note", "type": "function", "function": ["name": "create_note",
      "arguments": "{\"title\":\"真实工具测试\",\"body\":\"减数分裂：染色体复制一次，细胞连续分裂两次。\"}"]]
  }

  func testModelToolCreatesDurableNoteAndRunWithoutCloud() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    RuntimeModelProtocol.responses = [(200, try completion("", tools: [noteCall()])), (200, try completion("笔记已保存。"))]
    let answer = try await store.agent.answerUnified(sessionID: "runtime", messageID: "question", request: "建立笔记",
      context: store.agent.frozenContext(session: store.assistantSessionContext), history: [], attachments: [], ephemeral: false)
    XCTAssertEqual(answer.sourceLabel, "deepseek")
    let run = try XCTUnwrap(store.agent.active)
    XCTAssertEqual(run.status, .completed)
    XCTAssertEqual(run.steps.first?.outcomes.first?.status, "ok")
    let id = try XCTUnwrap(run.committedNoteIDs.first)
    XCTAssertTrue(store.notes.contains { $0.id == id && $0.body.contains("染色体") })
    await store.flush()
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: true)
    let note = try await reopened.loadStoredNote(id, scope: try XCTUnwrap(store.noteScope))
    XCTAssertEqual(note?.note.title, "真实工具测试")
    let savedRun = try await reopened.loadRun(run.id, scope: run.scope)
    XCTAssertEqual(savedRun?.status, .completed)
    XCTAssertNil(store.cloud)
  }

  func testModelFailureRetainsCommittedNoteAndShowsFailure() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    RuntimeModelProtocol.responses = [(200, try completion("", tools: [noteCall()])), (429, "{}")]
    do {
      _ = try await store.agent.answerUnified(sessionID: "failure", messageID: "q", request: "建立笔记",
        context: store.agent.frozenContext(session: store.assistantSessionContext), history: [], attachments: [], ephemeral: false)
      XCTFail("Provider failure must not become a canned success")
    } catch { XCTAssertEqual(error as? DeepSeekError, .http(429)) }
    let run = try XCTUnwrap(store.agent.active)
    XCTAssertEqual(run.status, .failed)
    let id = try XCTUnwrap(run.committedNoteIDs.first)
    XCTAssertTrue(store.notes.contains { $0.id == id })
    XCTAssertFalse(store.agent.isWorking)
    await store.flush()
  }

  func testCancelAbortsNetworkBeforeAnyToolWrite() async throws {
    let (store, folder) = try await makeStore()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    RuntimeModelProtocol.delay = 1
    RuntimeModelProtocol.responses = [(200, try completion("", tools: [noteCall()]))]
    let count = store.notes.count
    let request = Task { @MainActor in
      try await store.agent.answerUnified(sessionID: "cancel", messageID: "q", request: "建立笔记",
        context: store.agent.frozenContext(session: store.assistantSessionContext), history: [], attachments: [], ephemeral: false)
    }
    while !store.agent.isWorking { try await Task.sleep(for: .milliseconds(10)) }
    try await Task.sleep(for: .milliseconds(50))
    store.agent.cancel()
    do { _ = try await request.value; XCTFail("Cancelled request must stop") } catch is CancellationError { }
    XCTAssertEqual(store.notes.count, count)
    XCTAssertEqual(store.agent.active?.status, .cancelled)
    XCTAssertFalse(store.agent.isWorking)
    await store.flush()
  }
}

/// Explicitly opt in on a QA simulator by placing .enable-deepseek-live-tests in
/// its app Documents directory. Default unit tests never use a real credential.
@MainActor final class MockDeepSeekLiveTests: XCTestCase {
  func testRealQuestionsNotesFlashcardsAndReviewPersist() async throws {
    let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
    guard FileManager.default.fileExists(atPath: documents.appendingPathComponent(".enable-deepseek-live-tests").path) else {
      throw XCTSkip("Live model acceptance is explicitly opt-in")
    }
    XCTAssertTrue(LiveAssistantConfiguration.hasKey, "Configure the QA app Keychain before live acceptance")
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("deepseek-live-" + UUID().uuidString)
    let store = AppStore(repository: try LocalBookCourseRepository(directory: folder, includeFixtures: true), cloud: nil)
    await store.boot()
    defer { store.suspendCourseUploads(); try? FileManager.default.removeItem(at: folder) }
    let course = try XCTUnwrap(store.courses.first { $0.resourceIDs.contains("book_biology_2") })
    store.selectCourse(course.id); store.selectSource("book_biology_2"); store.route = .lesson
    let context = store.agent.frozenContext(session: store.assistantSessionContext)
    let session = "live-" + UUID().uuidString
    let first = try await store.agent.answerUnified(sessionID: session, messageID: "q1", request: "只回答五加七的结果。",
      context: context, history: [], attachments: [], ephemeral: false)
    XCTAssertTrue(first.text.contains("12") || first.text.contains("十二"))
    XCTAssertEqual(first.sourceLabel, "deepseek")
    let title = "AI验收笔记-" + String(UUID().uuidString.prefix(8))
    let second = try await store.agent.answerUnified(sessionID: session, messageID: "q2",
      request: "请实际调用 create_note，在当前课程创建标题为‘\(title)’的笔记。正文解释减数分裂的核心过程，必须包含‘染色体复制一次，细胞连续分裂两次’。完成后简短告诉我。",
      context: context, history: [ChatMessage(role: "user", text: "五加七等于多少？"), ChatMessage(role: "assistant", text: first.text)], attachments: [], ephemeral: false)
    let note = try XCTUnwrap(store.notes.first { $0.title == title }, "A real model reply alone is not a saved note")
    XCTAssertTrue(note.body.contains("连续分裂两次"))
    XCTAssertTrue(store.agent.active?.steps.flatMap(\.toolCalls).contains { $0.name == "create_note" } == true)
    XCTAssertTrue(store.agent.active?.committedNoteIDs.contains(note.id) == true)
    let third = try await store.agent.answerUnified(sessionID: session, messageID: "q3",
      request: "读取刚才笔记（note_id=\(note.id)）并用 update_note 追加小节‘复习提示’。再根据这份笔记用 create_flashcards 创建两张问答闪卡，用 create_review_task 安排今天3分钟的复习任务，标题‘\(title)-复习’。全部实际保存，最后简短回复。",
      context: context, history: [ChatMessage(role: "user", text: "创建笔记：" + title), ChatMessage(role: "assistant", text: second.text)], attachments: [], ephemeral: false)
    XCTAssertFalse(third.text.isEmpty)
    let names = Set(store.agent.active?.steps.flatMap(\.toolCalls).map(\.name) ?? [])
    XCTAssertTrue(names.isSuperset(of: ["read_note", "update_note", "create_flashcards", "create_review_task"]))
    let updated = try XCTUnwrap(store.notes.first { $0.id == note.id })
    XCTAssertTrue(updated.body.contains("复习提示"))
    XCTAssertEqual(store.agentFlashcards.count, 2)
    let reviewObjects = store.assistantState.learningObjects.filter { $0.kind == "review_task" }.map(\.data)
    XCTAssertTrue(store.agentPlanTasks(courseID: course.id, date: DailyStudyPlanState.day()).contains { $0.title == title + "-复习" },
      "Actual review objects: \(reviewObjects)")
    await store.flush()
    let reopened = try LocalBookCourseRepository(directory: folder, includeFixtures: true)
    let persisted = try await reopened.loadStoredNote(note.id, scope: try XCTUnwrap(store.noteScope))
    XCTAssertEqual(persisted?.note.body, updated.body)
    let restored = AppStore(repository: reopened, cloud: nil)
    await restored.boot()
    restored.selectCourse(course.id); restored.selectSource("book_biology_2")
    XCTAssertEqual(restored.agentFlashcards.count, 2)
    XCTAssertTrue(restored.agentPlanTasks(courseID: course.id, date: DailyStudyPlanState.day()).contains { $0.title == title + "-复习" })
    restored.suspendCourseUploads()
  }
}
