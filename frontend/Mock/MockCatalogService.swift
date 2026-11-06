import Foundation

/// Gives every catalog lesson the same four-part teaching and six-card practice
/// structure as the biology demo, using subject-specific authored content.
enum MockCatalogService {
  static func source(from original: SourceContent) -> SourceContent {
    guard let book = MockBookContent.book(original.id) else { return original }
    if original.summary.content_mode == "mock_catalog_v2" { return original }
    var source = original
    source.lessons = []; source.chunks = []; source.assets = []; source.flashcards = []; source.quizzes = []
    source.plan.tasks = []
    let chapters = Dictionary(uniqueKeysWithValues: original.chapters.map { ($0.id, $0) })
    let oldCards = Dictionary(uniqueKeysWithValues: original.flashcards.map { ($0.id, $0) })
    let oldTasks = Dictionary(uniqueKeysWithValues: original.plan.tasks.map { ($0.id, $0) })
    let topics = book.topics.filter { chapters[$0.chapter_id] != nil }
    let metadata: [String: JSONValue] = ["mock": .bool(true), "source_kind": .string("mock_handout"),
      "physical_page_verified": .bool(false), "label": .string("本地示例讲义 · 原创预置内容")]
    for (offset, topic) in topics.enumerated() {
      guard let chapter = chapters[topic.chapter_id] else { continue }
      let prefix = original.id + "::mock::" + chapter.id
      let lessonID = prefix + "::lesson"
      let page = max(1, chapter.page_start)
      let end = max(page, chapter.page_end)
      let imageID = prefix + "::diagram"
      let imagePath = MockBookContent.mediaPath(bookID: original.id, chapterID: chapter.id, kind: "image")
      var blocks: [LessonBlock] = []
      for (index, block) in topic.blocks.enumerated() {
        let chunkID = prefix + "::chunk\(index + 1)"
        source.chunks.append(SourceChunk(chunk_id: chunkID, book_id: original.id, chapter_id: chapter.id,
          page_start: page, page_end: end, content_type: "text", text: block.content,
          asset_ids: [imageID], key_concepts: topic.key_concepts, source_metadata: metadata))
        blocks.append(LessonBlock(block_id: prefix + "::block\(index + 1)", block_type: block.block_type,
          title: block.title, content: block.content,
          citations: [LessonCitation(chunk_id: chunkID, page_start: page, page_end: page,
            quote: String(block.content.prefix(220)), source_metadata: metadata)],
          source_chunk_ids: [chunkID], asset_ids: block.block_type == "diagram" ? [imageID] : [], ai_generated: true))
      }
      let chunkIDs = blocks.flatMap(\.source_chunk_ids)
      source.lessons.append(Lesson(book_id: original.id, lesson_id: lessonID, chapter_id: chapter.id,
        title: chapter.title, source_title: chapter.source_title, page_start: page, page_end: end,
        lesson_kind: "lesson", status: "ready", confidence: 100,
        objectives: topic.objectives, key_concepts: topic.key_concepts, summary: topic.summary,
        blocks: blocks, source_chunk_ids: chunkIDs, asset_ids: [imageID], warnings: []))
      source.assets.append(BookAsset(asset_id: imageID, book_id: original.id, chapter_id: chapter.id,
        source_type: "ai_generated", page: page, type: "image", caption: chapter.title + " · 概念图解",
        image_url: imagePath, thumbnail_url: imagePath, source_chunk_ids: chunkIDs,
        concepts: topic.key_concepts, metadata: metadata))
      for (index, card) in topic.flashcards.enumerated() {
        let id = prefix + (index == 0 ? "::card" : "::card\(index + 1)")
        source.flashcards.append(Flashcard(card_id: id, book_id: original.id, lesson_id: lessonID,
          chapter_id: chapter.id, front: card.front, back: card.back, concept: card.concept,
          source_chunk_ids: chunkIDs, page_start: page, page_end: end,
          mastery: oldCards[id]?.mastery ?? 0, reason: "本节要点回忆与迁移练习", due: oldCards[id]?.due,
          source_kind: "mock_authored", source_quote: topic.summary))
      }
      for question in topic.quizzes {
        source.quizzes.append(QuizQuestion(question_id: prefix + "::" + question.question_type,
          book_id: original.id, lesson_id: lessonID, chapter_id: chapter.id, prompt: question.prompt,
          choices: question.choices, answer: question.answer, explanation: question.explanation,
          concept: question.concept, source_chunk_ids: chunkIDs, page_start: page, page_end: end,
          question_type: question.question_type, instruction: "根据本节示例讲义完成练习",
          source_kind: "mock_authored", source_quote: topic.summary))
      }
      for (kind, label, minutes) in [("learn", "图文学习", 12), ("practice", "章节练习", 8), ("review", "闪卡复习", 5)] {
        let id = prefix + "::" + kind
        source.plan.tasks.append(StudyTask(task_id: id, user_id: "mock_learner", day: offset + 1,
          title: label + " · " + chapter.title, task_type: kind, minutes: minutes,
          chapter_id: chapter.id, lesson_id: lessonID, status: oldTasks[id]?.status ?? "pending", weak_points: []))
      }
    }
    source.plan.user_id = "mock_learner"; source.plan.book_id = original.id
    source.plan.days = max(1, topics.count); source.plan.daily_minutes = 25
    source.summary.status = "ready"; source.summary.content_mode = "mock_catalog_v2"
    source.summary.chapter_count = source.chapters.filter { $0.parent_id == nil }.count
    source.summary.chunk_count = source.chunks.count; source.summary.asset_count = source.assets.count
    source.summary.next_title = source.lessons.first?.title
    return source
  }

  static func listings(from originals: [CommunityBook]) -> [CommunityBook] {
    var values = originals
    if !values.contains(where: { $0.id == "community_micro_psychology" }),
      let source = MockBookContent.extraSources.first(where: { $0.id == "catalog_micro_psychology_set" }) {
      values.append(CommunityBook(id: "community_micro_psychology", title: source.summary.title,
        catalogTitle: "微表情·微动作·微反应", owner: "本地演示课程", cover: source.summary.cover_url ?? "",
        subject: "心理学", grade: "通识", version: "原创示例", learners: 0, progress: 0,
        flashcardCount: 54, recommended: false, tags: ["行为观察", "交流情境"],
        description: "分三组学习行为观察、情境解释与澄清沟通。", chapters: source.chapters.filter { $0.parent_id == nil }.map(\.title)))
    }
    return values.map { original in
      var entry = original
      let id = MockBookContent.communitySourceIDs[entry.id] ?? entry.id
      if let book = MockBookContent.book(id) {
        entry.catalog_origin = CatalogOrigin(book_id: id)
        entry.flashcardCount = book.topics.count * 6
        entry.description = "包含 \(book.topics.count) 个课时、\(book.topics.count * 6) 张闪卡、\(book.topics.count * 3) 道练习，配有逐节图解、讲解短片和本地示例讲义。"
        entry.tags = ["完整课程", "图文讲解", "闪卡", "练习", "视频"]
      } else if id == "book_biology_2" {
        entry.flashcardCount = 90
      }
      return entry
    }
  }

  static func handoutPath(source: SourceContent?, page: Int) -> String? {
    guard let source, MockBookContent.book(source.id) != nil else { return nil }
    let lesson = source.lessons.filter { $0.page_start <= page && $0.page_end >= page }
      .min { ($0.page_end - $0.page_start) < ($1.page_end - $1.page_start) }
      ?? source.lessons.last { $0.page_start <= page } ?? source.lessons.first
    guard let lesson else { return nil }
    return MockBookContent.handoutPath(bookID: source.id, chapterID: lesson.chapter_id)
  }
}
