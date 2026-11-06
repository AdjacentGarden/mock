import Foundation

struct LiveSkillResult: Sendable {
  var content: String
  var noteID: String? = nil
}

/// The live model receives a closed set of local app operations. Its arguments
/// identify course objects; they never identify files, URLs or network requests.
@MainActor enum LiveAssistantSkills {
  private static func text(_ maximum: Int, _ description: String = "") -> JSONValue {
    .object(["type": .string("string"), "minLength": .number(1),
      "maxLength": .number(Double(maximum)), "description": .string(description)])
  }
  private static func integer(_ minimum: Int, _ maximum: Int) -> JSONValue {
    .object(["type": .string("integer"), "minimum": .number(Double(minimum)), "maximum": .number(Double(maximum))])
  }
  private static let scopeProperties: [String: JSONValue] = [
    "course_id": text(200, "从 list_courses 返回的课程 ID；省略时仅使用对话开始时的课程。无课程时先请用户选择。"),
    "book_id": text(200, "必须属于所选课程；省略时使用冻结的当前教材或该课程唯一教材。"),
    "chapter_id": text(200, "必须属于所选教材；省略时仅沿用同一课程和教材的当前章节。")]

  private static func tool(_ name: String, _ description: String,
    _ properties: [String: JSONValue] = [:], required: [String] = []) -> [String: JSONValue] {
    ["type": .string("function"), "function": .object(["name": .string(name), "description": .string(description),
      "parameters": .object(["type": .string("object"), "properties": .object(properties),
        "required": .array(required.map(JSONValue.string)), "additionalProperties": .bool(false)])])]
  }

  /// Standard chat-completions function definitions, also accepted by DeepSeek.
  static var tools: [[String: JSONValue]] {
    let card: JSONValue = .object(["type": .string("object"), "properties": .object([
      "front": text(2_000), "back": text(8_000), "concept": text(200)]),
      "required": .array([.string("front"), .string("back")]), "additionalProperties": .bool(false)])
    return [
      tool("list_courses", "读取本机已有课程、教材和章节 ID，供用户选择正确的保存位置。"),
      tool("read_current_lesson", "读取冻结的当前课文、教学内容和本机教材文本；返回真实内容与来源 ID。", scopeProperties.merging([
        "offset": integer(0, 100_000), "limit": integer(1, 30)]) { _, new in new }),
      tool("list_notes", "列出指定课程的真实本机笔记和版本号。", ["course_id": scopeProperties["course_id"]!,
        "keyword": text(200), "offset": integer(0, 100_000), "limit": integer(1, 100)]),
      tool("read_note", "读取指定课程中的笔记正文和 revision；修改前应先读取。", [
        "course_id": scopeProperties["course_id"]!, "note_id": text(200)], required: ["note_id"]),
      tool("create_note", "将完整笔记正文真实保存到本机指定课程和教材，返回 note_id。不要仅在回复中声称保存。",
        scopeProperties.merging(["title": text(80), "body": text(100_000), "page": integer(1, 1_000_000)]) { _, new in new },
        required: ["title", "body"]),
      tool("update_note", "按 read_note 返回的 revision 修改已有笔记；保留其课程和教材，版本冲突时重新读取。", [
        "course_id": scopeProperties["course_id"]!, "note_id": text(200), "revision": integer(1, 1_000_000_000),
        "title": text(80), "body": text(100_000)], required: ["note_id", "revision"]),
      tool("create_flashcards", "真实创建 1 到 30 张闪卡，保存后可在对应课程的闪卡页看到。",
        scopeProperties.merging(["cards": .object(["type": .string("array"), "minItems": .number(1),
          "maxItems": .number(30), "items": card])]) { _, new in new }, required: ["cards"]),
      tool("create_review_task", "真实创建课程复习任务，在指定日期的学习计划中显示。date 省略则为今天。",
        scopeProperties.merging(["title": text(200), "description": text(8_000),
          "date": text(10, "严格使用 yyyy-MM-dd"), "minutes": integer(1, 240)]) { _, new in new }, required: ["title"])
    ]
  }

  static func execute(name: String, arguments: [String: JSONValue], context: AgentFrozenContext,
    operationID: String, store: AppStore) async throws -> LiveSkillResult {
    try Task.checkCancellation()
    guard let scope = store.noteScope, scope == context.scope else { throw NoteStoreError.scopeMismatch }
    guard !operationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, operationID.count <= 500 else {
      throw AgentValidationError(message: "工具操作 ID 无效")
    }
    try validate(arguments, for: name)
    if name == "list_courses" { return try result(["status": .string("ok"), "courses": .array(courseChoices(store))]) }
    guard let course = try resolveCourse(arguments, context: context, store: store) else {
      return try result(["status": .string("requires_course"), "message": .string("请先选择保存或读取的课程。"),
        "courses": .array(courseChoices(store))])
    }
    try await store.repository.requireLiveCourse(courseID: course.id, scope: scope)
    try checkScope(scope, store: store)

    if name == "list_notes" {
      let keyword = try optionalText(arguments, "keyword", max: 200)
      let all = try await store.repository.loadStoredNotes(scope: scope).filter {
        $0.note.anchor?.courseID == course.id && (keyword == nil || ($0.note.title + "\n" + $0.note.body).localizedCaseInsensitiveContains(keyword!))
      }
      try checkScope(scope, store: store)
      let offset = try number(arguments, "offset", default: 0, range: 0...100_000)
      let limit = try number(arguments, "limit", default: 30, range: 1...100)
      let rows = Array(all.dropFirst(offset).prefix(limit)).map { row -> JSONValue in
        var item = noteLocation(row.note)
        item["note_id"] = .string(row.note.id); item["title"] = .string(row.note.title)
        item["revision"] = .number(Double(row.revision))
        return .object(item)
      }
      return try result(["status": .string("ok"), "items": .array(rows), "total": .number(Double(all.count)),
        "complete": .bool(offset + rows.count >= all.count),
        "next_offset": offset + rows.count < all.count ? .number(Double(offset + rows.count)) : .null])
    }
    if name == "read_note" {
      let id = try requiredText(arguments, "note_id", max: 200)
      let row = try await ownedNote(id, course: course, scope: scope, store: store)
      var item = noteLocation(row.note)
      item["status"] = .string("ok"); item["note_id"] = .string(id)
      item["revision"] = .number(Double(row.revision)); item["title"] = .string(row.note.title)
      item["body"] = .string(row.note.body)
      return try result(item)
    }

    let mutating = ["create_note", "update_note", "create_flashcards", "create_review_task"].contains(name)
    // Hash raw model arguments and the frozen defaults. A reused operation ID
    // with different arguments must never overwrite or create another artifact.
    let fingerprint: [String: JSONValue] = ["name": .string(name), "arguments": .object(arguments),
      "course_id": .string(course.id), "context_book_id": .string(context.bookID),
      "context_chapter_id": context.chapterID.map(JSONValue.string) ?? .null,
      "context_course_id": context.courseID.map(JSONValue.string) ?? .null, "context_page": .number(Double(context.page))]
    let digest = AgentDigest.sha256(try encode(fingerprint))
    if mutating, let receipt = try await store.repository.liveSkillReceipt(operationID, scope: scope, digest: digest) {
      try checkScope(scope, store: store)
      return try await apply(receipt, scope: scope, store: store)
    }

    if name == "update_note" {
      let id = try requiredText(arguments, "note_id", max: 200)
      let revision = try number(arguments, "revision", range: 1...1_000_000_000)
      var note = try await ownedNote(id, course: course, scope: scope, store: store).note
      let title = try optionalText(arguments, "title", max: 80), body = try optionalText(arguments, "body", max: 100_000)
      guard title != nil || body != nil else { throw AgentValidationError(message: "更新笔记至少需要 title 或 body") }
      if let title { note.title = title }; if let body { note.body = body }
      note.updatedAt = .now; note.conversation = nil
      let existingBookID = note.anchor?.bookID ?? ""
      note.anchor?.courseResourceID = store.courseResourceID(courseID: course.id, bookID: existingBookID)
      note.provenance = NoteProvenance(runID: operationID, toolCallID: operationID, sourceLabel: "deepseek")
      let receipt = try await store.repository.commitLiveSkillNote(note, scope: scope, operationID: operationID,
        digest: digest, condition: .revision(revision))
      try checkScope(scope, store: store, checkCancellation: false)
      return try await apply(receipt, scope: scope, store: store)
    }

    guard let target = try resolveTarget(arguments, course: course, context: context, store: store) else {
      return try result(["status": .string("requires_book"), "course_id": .string(course.id),
        "message": .string("请选择此课程中的教材。"), "books": .array(bookChoices(course, store: store))])
    }
    if name == "read_current_lesson" {
      return try readLesson(target, arguments: arguments, context: context)
    }
    if name == "create_note" {
      let title = try requiredText(arguments, "title", max: 80), body = try requiredText(arguments, "body", max: 100_000)
      let page = try number(arguments, "page", default: target.page, range: 1...max(1, target.source.summary.page_count))
      let anchor = NoteAnchor(courseID: course.id, courseResourceID: target.resourceID, bookID: target.source.id,
        chapterID: target.chapterID, page: page)
      let id = "live-note:" + String(AgentDigest.sha256(scope + "|" + operationID).prefix(32))
      let note = StudyNote(id: id, kind: .text, title: title, body: body, anchor: anchor,
        provenance: NoteProvenance(runID: operationID, toolCallID: operationID, sourceLabel: "deepseek"))
      let receipt = try await store.repository.commitLiveSkillNote(note, scope: scope, operationID: operationID,
        digest: digest, condition: .absent)
      try checkScope(scope, store: store, checkCancellation: false)
      return try await apply(receipt, scope: scope, store: store)
    }

    var rows: [[String: JSONValue]] = []
    if name == "create_flashcards" {
      guard case .array(let cards)? = arguments["cards"], (1...30).contains(cards.count) else {
        throw AgentValidationError(message: "cards 必须包含 1 到 30 张闪卡")
      }
      rows = try cards.map { value in
        guard case .object(let card) = value, Set(card.keys).isSubset(of: ["front", "back", "concept"]) else {
          throw AgentValidationError(message: "每张闪卡仅接受 front、back、concept")
        }
        var row: [String: JSONValue] = ["front": .string(try requiredText(card, "front", max: 2_000)),
          "back": .string(try requiredText(card, "back", max: 8_000)), "mastery": .number(0)]
        if let concept = try optionalText(card, "concept", max: 200) { row["concept"] = .string(concept) }
        return row
      }
    } else if name == "create_review_task" {
      let date = try optionalText(arguments, "date", max: 10) ?? DailyStudyPlanState.day()
      guard validDay(date) else { throw AgentValidationError(message: "date 必须是有效的 yyyy-MM-dd 日期") }
      var row: [String: JSONValue] = ["title": .string(try requiredText(arguments, "title", max: 200)),
        "date": .string(date), "minutes": .number(Double(try number(arguments, "minutes", default: 10, range: 1...240))),
        "kind": .string("recall"), "status": .string("pending")]
      if let description = try optionalText(arguments, "description", max: 8_000) { row["description"] = .string(description) }
      rows = [row]
    } else { throw AgentValidationError(message: "未知的本机技能：" + name) }
    let objects: [AgentLearningObject] = try rows.enumerated().map { index, row in
      var data = row
      data["book_id"] = .string(target.source.id); data["chapter_id"] = target.chapterID.map(JSONValue.string) ?? .null
      if let lesson = target.source.lessons.first(where: { $0.chapter_id == target.chapterID }) { data["lesson_id"] = .string(lesson.id) }
      let id = "live-object:" + String(AgentDigest.sha256(scope + "|" + operationID + ":\(index)").prefix(32))
      let wire: [String: JSONValue] = ["id": .string(id), "revision": .number(1),
        "kind": .string(name == "create_flashcards" ? "flashcard" : "review_task"),
        "course_id": .string(course.id), "course_resource_id": .string(target.resourceID), "data": .object(data)]
      return try JSONDecoder().decode(AgentLearningObject.self, from: JSONEncoder().encode(wire))
    }
    let receipt = try await store.repository.commitLiveSkillObjects(objects, scope: scope, operationID: operationID, digest: digest)
    try checkScope(scope, store: store, checkCancellation: false)
    return try await apply(receipt, scope: scope, store: store)
  }

  private struct Target {
    var course: Course
    var source: SourceContent
    var resourceID: String
    var chapterID: String?
    var page: Int
  }

  private static func checkScope(_ scope: String, store: AppStore, checkCancellation: Bool = true) throws {
    if checkCancellation { try Task.checkCancellation() }
    guard store.noteScope == scope else { throw NoteStoreError.scopeMismatch }
  }
  private static func validate(_ arguments: [String: JSONValue], for name: String) throws {
    guard let definition = tools.first(where: { item in
      if case .object(let function)? = item["function"] { return function["name"]?.stringValue == name }; return false
    }), case .object(let function)? = definition["function"],
      case .object(let schema)? = function["parameters"], case .object(let properties)? = schema["properties"] else {
      throw AgentValidationError(message: "未知的本机技能：" + name)
    }
    guard Set(arguments.keys).isSubset(of: Set(properties.keys)) else { throw AgentValidationError(message: "工具包含不支持的参数") }
    for (key, value) in arguments {
      guard case .object(let specification)? = properties[key] else { continue }
      if specification["type"]?.stringValue == "string" {
        _ = try requiredText([key: value], key, max: Int(specification["maxLength"]?.numberValue ?? 100_000))
      } else if specification["type"]?.stringValue == "integer" {
        _ = try number([key: value], key,
          range: Int(specification["minimum"]?.numberValue ?? 0)...Int(specification["maximum"]?.numberValue ?? 1_000_000))
      }
    }
    if case .array(let required)? = schema["required"] {
      for key in required.compactMap(\.stringValue) where arguments[key] == nil { throw AgentValidationError(message: "缺少参数：" + key) }
    }
  }
  private static func requiredText(_ args: [String: JSONValue], _ key: String, max: Int) throws -> String {
    guard case .string(let value)? = args[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      value.count <= max, !value.contains("\0") else { throw AgentValidationError(message: "参数 \(key) 必须为 1 到 \(max) 字的非空文本") }
    return value
  }
  private static func optionalText(_ args: [String: JSONValue], _ key: String, max: Int) throws -> String? {
    args[key] == nil ? nil : try requiredText(args, key, max: max)
  }
  private static func number(_ args: [String: JSONValue], _ key: String, default fallback: Int? = nil,
    range: ClosedRange<Int>) throws -> Int {
    if args[key] == nil, let fallback { return fallback }
    guard case .number(let value)? = args[key], value.isFinite, let number = Int(exactly: value), range.contains(number) else {
      throw AgentValidationError(message: "参数 \(key) 必须为 \(range.lowerBound) 到 \(range.upperBound) 的整数")
    }
    return number
  }
  private static func resolveCourse(_ args: [String: JSONValue], context: AgentFrozenContext, store: AppStore) throws -> Course? {
    guard let id = try optionalText(args, "course_id", max: 200) ?? context.courseID else { return nil }
    guard let course = store.courses.first(where: { $0.id == id }) else { throw AgentValidationError(message: "课程不存在；请先调用 list_courses 选择本机课程") }
    return course
  }
  private static func source(_ id: String, courseID: String, store: AppStore) -> SourceContent? {
    store.cloudState.localCourseSources[courseID]?.first { $0.id == id } ?? store.sources.first { $0.id == id }
  }
  private static func resolveTarget(_ args: [String: JSONValue], course: Course, context: AgentFrozenContext, store: AppStore) throws -> Target? {
    let sameCourse = context.courseID == course.id
    let frozenBook = sameCourse && course.resourceIDs.contains(context.bookID) ? context.bookID : nil
    guard let bookID = try optionalText(args, "book_id", max: 200) ?? frozenBook ?? (course.resourceIDs.count == 1 ? course.resourceIDs.first : nil) else { return nil }
    guard course.resourceIDs.contains(bookID), let resourceID = store.courseResourceID(courseID: course.id, bookID: bookID) else {
      throw AgentValidationError(message: "教材不属于指定课程，未执行写入")
    }
    guard let source = source(bookID, courseID: course.id, store: store) else { throw AgentValidationError(message: "教材内容尚未保存在本机") }
    let sameBook = sameCourse && context.bookID == bookID
    let chapterID = try optionalText(args, "chapter_id", max: 200) ?? (sameBook ? context.chapterID : nil)
    if let chapterID, !source.chapters.contains(where: { $0.id == chapterID }), !source.lessons.contains(where: { $0.chapter_id == chapterID }) {
      throw AgentValidationError(message: "章节不属于指定教材，未执行写入")
    }
    let chapterPage = source.chapters.first { $0.id == chapterID }?.page_start
    let page = args["chapter_id"] == nil && sameBook ? context.page : chapterPage ?? 1
    return Target(course: course, source: source, resourceID: resourceID, chapterID: chapterID,
      page: min(max(1, page), max(1, source.summary.page_count)))
  }
  private static func ownedNote(_ id: String, course: Course, scope: String, store: AppStore) async throws -> StoredNote {
    guard let row = try await store.repository.loadStoredNote(id, scope: scope), let anchor = row.note.anchor,
      anchor.courseID == course.id, course.resourceIDs.contains(anchor.bookID),
      let resourceID = store.courseResourceID(courseID: course.id, bookID: anchor.bookID),
      anchor.courseResourceID == nil || anchor.courseResourceID == resourceID else {
      throw AgentValidationError(message: "笔记不存在或不属于指定课程，未读取或修改其他课程笔记")
    }
    try checkScope(scope, store: store)
    return row
  }
  private static func courseChoices(_ store: AppStore) -> [JSONValue] {
    store.courses.map { course in .object(["course_id": .string(course.id), "name": .string(course.name),
      "books": .array(bookChoices(course, store: store))]) }
  }
  private static func bookChoices(_ course: Course, store: AppStore) -> [JSONValue] {
    course.resourceIDs.map { id in
      let content = source(id, courseID: course.id, store: store)
      return .object(["book_id": .string(id), "title": .string(content?.summary.title ?? id),
        "chapters": .array((content?.chapters ?? []).map { .object(["chapter_id": .string($0.id), "title": .string($0.title)]) })])
    }
  }
  private static func noteLocation(_ note: StudyNote) -> [String: JSONValue] {
    ["course_id": note.anchor?.courseID.map(JSONValue.string) ?? .null,
      "book_id": note.anchor.map { .string($0.bookID) } ?? .null,
      "chapter_id": note.anchor?.chapterID.map(JSONValue.string) ?? .null]
  }
  private static func readLesson(_ target: Target, arguments: [String: JSONValue], context: AgentFrozenContext) throws -> LiveSkillResult {
    let offset = try number(arguments, "offset", default: 0, range: 0...100_000)
    let limit = try number(arguments, "limit", default: 10, range: 1...30)
    let lessons = target.source.lessons.filter { lesson in
      target.chapterID.map { lesson.chapter_id == $0 } ?? (lesson.page_start <= target.page && lesson.page_end >= target.page)
    }
    let chunks = target.source.chunks.filter { chunk in
      target.chapterID.map { chunk.chapter_id == $0 } ?? (chunk.page_start <= target.page && chunk.page_end >= target.page)
    }
    var rows: [JSONValue] = []
    for lesson in lessons {
      rows.append(.object(["kind": .string("lesson"), "lesson_id": .string(lesson.id), "title": .string(lesson.title),
        "chapter_id": .string(lesson.chapter_id), "summary": .string(lesson.summary),
        "objectives": .array(lesson.objectives.map(JSONValue.string)), "key_concepts": .array(lesson.key_concepts.map(JSONValue.string))]))
      rows += lesson.blocks.map { block in .object(["kind": .string("lesson_block"), "block_id": .string(block.id),
        "title": .string(block.title), "content": .string(block.content), "ai_generated": .bool(block.ai_generated),
        "source_chunk_ids": .array(block.source_chunk_ids.map(JSONValue.string))]) }
    }
    rows += chunks.map { .object(["kind": .string("source_chunk"), "chunk_id": .string($0.id),
      "chapter_id": .string($0.chapter_id), "page_start": .number(Double($0.page_start)),
      "page_end": .number(Double($0.page_end)), "text": .string($0.text)]) }
    let page = Array(rows.dropFirst(offset).prefix(limit))
    let sameLocation = context.courseID == target.course.id && context.bookID == target.source.id && context.chapterID == target.chapterID
    return try result(["status": .string(rows.isEmpty ? "no_local_content" : "ok"), "course_id": .string(target.course.id),
      "book_id": .string(target.source.id), "book_title": .string(target.source.summary.title),
      "chapter_id": target.chapterID.map(JSONValue.string) ?? .null, "page": .number(Double(target.page)),
      "selection": .string(sameLocation ? context.selection : ""), "items": .array(page),
      "total": .number(Double(rows.count)), "complete": .bool(offset + page.count >= rows.count),
      "next_offset": offset + page.count < rows.count ? .number(Double(offset + page.count)) : .null])
  }
  private static func validDay(_ value: String) -> Bool {
    guard value.count == 10, value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return false }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyy-MM-dd"; formatter.isLenient = false
    guard let date = formatter.date(from: value) else { return false }
    return formatter.string(from: date) == value
  }
  private static func encode(_ value: [String: JSONValue]) throws -> String {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }
  private static func result(_ value: [String: JSONValue], noteID: String? = nil) throws -> LiveSkillResult {
    var payload = value
    payload["ok"] = .bool(["ok", "saved"].contains(value["status"]?.stringValue ?? ""))
    return LiveSkillResult(content: try encode(payload), noteID: noteID)
  }
  private static func apply(_ receipt: LiveSkillReceipt, scope: String, store: AppStore) async throws -> LiveSkillResult {
    if let id = receipt.result["note_id"]?.stringValue,
      let row = try await store.repository.loadStoredNote(id, scope: scope) {
      try checkScope(scope, store: store, checkCancellation: false)
      store.applyCommitted([row], scope: scope)
    }
    if receipt.result["ids"] != nil {
      let objects = try await store.repository.loadAgentLearningObjects(scope: scope)
      try checkScope(scope, store: store, checkCancellation: false)
      store.assistantState.learningObjects = objects
    }
    return try result(receipt.result, noteID: receipt.result["note_id"]?.stringValue)
  }
}

/// Completion receipts share the SQLite transaction with their note or learning
/// objects, so interrupted requests and repeated tool calls cannot duplicate work.
fileprivate struct LiveSkillReceipt: Codable, Sendable {
  var digest: String
  var result: [String: JSONValue]
}

extension LocalBookCourseRepository {
  fileprivate func liveSkillReceipt(_ operationID: String, scope: String, digest: String) throws -> LiveSkillReceipt? {
    guard let data = try db.get("live-assistant-skill:" + scope, operationID).first else { return nil }
    let receipt = try decoder.decode(LiveSkillReceipt.self, from: data)
    guard receipt.digest == digest else { throw NoteStoreError.receiptConflict(toolCallID: operationID) }
    return receipt
  }

  fileprivate func commitLiveSkillNote(_ note: StudyNote, scope: String, operationID: String,
    digest: String, condition: NoteWriteCondition) throws -> LiveSkillReceipt {
    try db.transaction {
      try Task.checkCancellation()
      guard let courseID = note.anchor?.courseID, note.anchor?.courseResourceID != nil else { throw NoteStoreError.scopeMismatch }
      try requireLiveCourse(courseID: courseID, scope: scope)
      if let receipt = try liveSkillReceipt(operationID, scope: scope, digest: digest) { return receipt }
      let saved = try writeNote(note, scope: scope, condition: condition)
      let receipt = LiveSkillReceipt(digest: digest, result: ["status": .string("saved"), "note_id": .string(note.id),
        "revision": .number(Double(saved.revision)), "course_id": .string(courseID),
        "book_id": .string(note.anchor!.bookID), "chapter_id": note.anchor?.chapterID.map(JSONValue.string) ?? .null])
      try db.put("live-assistant-skill:" + scope, operationID, encoder.encode(receipt))
      return receipt
    }
  }

  fileprivate func commitLiveSkillObjects(_ additions: [AgentLearningObject], scope: String,
    operationID: String, digest: String) throws -> LiveSkillReceipt {
    try db.transaction {
      try Task.checkCancellation()
      for object in additions { try requireLiveCourse(courseID: object.course_id, scope: scope) }
      if let receipt = try liveSkillReceipt(operationID, scope: scope, digest: digest) { return receipt }
      var objects = try loadAgentLearningObjects(scope: scope)
      let existing = Set(objects.map(\.id))
      guard additions.allSatisfy({ !existing.contains($0.id) }) else { throw NoteStoreError.receiptConflict(toolCallID: operationID) }
      objects += additions
      try saveAgentLearningObjects(objects, scope: scope)
      let receipt = LiveSkillReceipt(digest: digest, result: ["status": .string("saved"),
        "ids": .array(additions.map { .string($0.id) }), "course_id": .string(additions.first!.course_id),
        "book_id": additions.first!.data["book_id"] ?? .null, "source": .string("local")])
      try db.put("live-assistant-skill:" + scope, operationID, encoder.encode(receipt))
      return receipt
    }
  }
}
