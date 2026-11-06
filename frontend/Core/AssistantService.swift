import Foundation

struct AssistantAnswer: Sendable {
  var answer: String
  var citations: [Citation]
  var sourceLabel: String? = nil
  var courseIDs: [String] = []
}

/// The demo never reads credentials or connects to a model provider.
enum DeveloperSecrets {
  static func key() -> String? { nil }
  static func setKey(_ key: String) throws { }
}

actor AssistantService {
  init(forceOffline: Bool = true) { }
  func ask(question: String, bookID: String, bookIDs: [String], chapterID: String?,
    sources: [SourceContent], history: [ChatMessage]) async throws -> AssistantAnswer {
    let source = sources.first { $0.id == bookID }
    let title = source?.chapters.first { $0.id == chapterID }?.title ?? source?.summary.title ?? ""
    return try await MockAssistantService.answer(question: question, title: title)
  }
}
