import Foundation

/// Authored, versioned fixtures shared by lessons, practice, media and the assistant.
/// They are bundled data, never obtained from the uploaded PDF or a remote model.
enum MockBookContent {
  static let version = 2
  static let bookIDs = [
    "catalog_high_school_math_required_2", "catalog_physics_required_3",
    "catalog_chemistry_required_2", "catalog_english_required_3", "catalog_advanced_mathematics_1",
    "catalog_theoretical_mechanics_1", "catalog_micro_psychology_set",
    "community_ecology", "community_motion", "community_functions",
  ]
  static let communitySourceIDs: [String: String] = [
    "community_genetics": "book_biology_2",
    "community_higher_mathematics": "catalog_advanced_mathematics_1",
    "community_high_school_mathematics_2": "catalog_high_school_math_required_2",
    "community_high_school_physics_3": "catalog_physics_required_3",
    "community_high_school_chemistry_2": "catalog_chemistry_required_2",
    "community_high_school_english_3": "catalog_english_required_3",
    "community_theoretical_mechanics": "catalog_theoretical_mechanics_1",
    "community_micro_psychology": "catalog_micro_psychology_set",
    "community_ecology": "community_ecology", "community_functions": "community_functions", "community_motion": "community_motion",
  ]
  struct Book: Decodable, Sendable {
    var book_id: String
    var version: Int
    var topics: [Topic]
  }
  struct Topic: Decodable, Sendable {
    struct Block: Decodable, Sendable { var block_type: String; var title: String; var content: String }
    struct Card: Decodable, Sendable { var front: String; var back: String; var concept: String }
    struct Question: Decodable, Sendable {
      var question_type: String; var prompt: String; var choices: [String]
      var answer: String; var explanation: String; var concept: String
    }
    var chapter_id: String
    var summary: String
    var objectives: [String]
    var key_concepts: [String]
    var blocks: [Block]
    var flashcards: [Card]
    var quizzes: [Question]
    var diagram_steps: [String]
    var diagram_focus: String
  }
  static let extraSources: [SourceContent] = (try? ContentBundle.load([SourceContent].self, name: "MockBooks/extra-sources")) ?? []
  private static let books: [String: Book] = Dictionary(uniqueKeysWithValues: bookIDs.compactMap { id in
    guard let book = try? ContentBundle.load(Book.self, name: "MockBooks/" + id),
      book.book_id == id, book.version == version else { return nil }
    return (id, book)
  })
  static func book(_ id: String) -> Book? { books[id] }
  static func contentBookID(bookID: String, chapterID: String?) -> String? {
    if book(bookID) != nil { return bookID }
    guard let chapterID else { return nil }
    return bookIDs.first { book($0)?.topics.contains { $0.chapter_id == chapterID } == true }
  }
  static func topic(bookID: String, chapterID: String?) -> Topic? {
    guard let id = contentBookID(bookID: bookID, chapterID: chapterID), let book = book(id) else { return nil }
    return book.topics.first { $0.chapter_id == chapterID } ?? book.topics.first
  }
  static func mediaPath(bookID: String, chapterID: String, kind: String) -> String {
    "assets/mock-books/\(bookID)/\(chapterID)" + (kind == "video" ? ".mp4" : "-diagram.png")
  }
  static func handoutPath(bookID: String, chapterID: String) -> String {
    "assets/mock-books/\(bookID)/\(chapterID)-handout.png"
  }
  static func note(bookID: String, chapterID: String?) -> String? {
    guard let topic = topic(bookID: bookID, chapterID: chapterID) else { return nil }
    return topic.summary + "\n\n" + topic.blocks.map { $0.title + "\n" + $0.content }.joined(separator: "\n\n")
  }
}
