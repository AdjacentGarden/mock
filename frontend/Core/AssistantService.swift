import Foundation

struct AssistantAnswer: Sendable {
  var answer: String
  var citations: [Citation]
  var sourceLabel: String? = nil
  var courseIDs: [String] = []
}

/// The legacy credential slot is disabled. Live AI uses its own dedicated Keychain configuration.
enum DeveloperSecrets {
  static func key() -> String? { nil }
  static func setKey(_ key: String) throws { }
}

actor AssistantService {
  private let forceOffline: Bool
  init(forceOffline: Bool = false) { self.forceOffline = forceOffline }
  func ask(question: String, bookID: String, bookIDs: [String], chapterID: String?,
    sources: [SourceContent], history: [ChatMessage]) async throws -> AssistantAnswer {
    let source = sources.first { $0.id == bookID }
    let title = source?.chapters.first { $0.id == chapterID }?.title ?? source?.summary.title ?? ""
    if forceOffline || ContentBundle.fixtureMode {
      return try await MockAssistantService.answer(question: question, title: title, bookID: bookID, chapterID: chapterID)
    }
    var messages: [[String: JSONValue]] = [["role": .string("system"),
      "content": .string("你是 DeepSeek 学习助手，用中文回答。当前课程标题是‘\(title)’。标题不代表你已经读取教材。此简易入口没有操作工具，不声称已保存笔记或学习任务。")]]
    messages += history.filter { ["user", "assistant"].contains($0.role) }.suffix(24)
      .map { ["role": .string($0.role), "content": .string(String($0.text.prefix(8000)))] }
    messages.append(["role": .string("user"), "content": .string(question)])
    let response = try await DeepSeekClient().complete(messages: messages, tools: [])
    return AssistantAnswer(answer: response.content, citations: [], sourceLabel: "deepseek")
  }
}
