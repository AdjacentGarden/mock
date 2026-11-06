import Foundation

/// Makes directory-only discovery fixtures playable without altering their outline.
/// These generic learning examples are preset copy, not extracted textbook content.
enum MockCatalogService {
  static func source(from original: SourceContent) -> SourceContent {
    guard original.lessons.isEmpty, !original.chapters.isEmpty else { return original }
    var source = original
    let parents = Set(original.chapters.compactMap(\.parent_id))
    let leaves = original.chapters.filter { !parents.contains($0.id) }
    let userID = "mock_learner"
    for (offset, chapter) in leaves.enumerated() {
      let prefix = original.id + "::mock::" + chapter.id
      let lessonID = prefix + "::lesson"
      let concept = chapter.title
      let overview = "本节以「\(concept)」为主题演示学习流程。以下为预置 mock 学习示例：先找核心概念，再梳理适用条件与结论，最后通过练习检查理解。"
      let method = "先用一句话说明「\(concept)」要解决什么问题。接着列出两个关键词，并说明它们之间的关系。最后合上讲解，用自己的话复述，而不是逐句背诵。"
      let example = "示例练习：把一个学习要点整理成「概念是什么 → 在什么条件下适用 → 如何举例说明」。如果说不清其中一步，就回到对应的讲解再次整理。"
      source.lessons.append(Lesson(book_id: original.id, lesson_id: lessonID, chapter_id: chapter.id,
        title: concept, source_title: chapter.source_title, page_start: 0, page_end: 0,
        lesson_kind: "lesson", status: "ready", confidence: 100,
        objectives: ["概括本节的核心概念", "用条件和例子检查理解"],
        key_concepts: [concept, "概念、条件与应用"], summary: overview,
        blocks: [
          LessonBlock(block_id: prefix + "::explanation", block_type: "explanation",
            title: "学习思路 · 预置演示", content: method, citations: [], source_chunk_ids: [],
            asset_ids: [], ai_generated: true),
          LessonBlock(block_id: prefix + "::example", block_type: "worked_example",
            title: "表达与应用", content: example, citations: [], source_chunk_ids: [],
            asset_ids: [], ai_generated: true),
        ], source_chunk_ids: [], asset_ids: [], warnings: []))

      source.flashcards.append(Flashcard(card_id: prefix + "::card", book_id: original.id,
        lesson_id: lessonID, chapter_id: chapter.id, front: "怎样检查自己是否理解「\(concept)」？",
        back: "说明核心概念，交代适用条件，再用一个例子解释。", concept: concept,
        source_chunk_ids: [], page_start: 0, page_end: 0, mastery: 0,
        reason: "预置 mock 闪卡，用于演示翻面、熟悉度标记与复习。", source_kind: "ai_supplement"))

      func question(_ suffix: String, _ kind: String, _ prompt: String, choices: [String],
        answer: String, explanation: String) -> QuizQuestion {
        QuizQuestion(question_id: prefix + "::" + suffix, book_id: original.id,
          lesson_id: lessonID, chapter_id: chapter.id, prompt: prompt, choices: choices,
          answer: answer, explanation: explanation, concept: concept, source_chunk_ids: [],
          page_start: 0, page_end: 0, question_type: kind,
          instruction: "预置 mock 练习", source_kind: "ai_supplement")
      }
      source.quizzes += [
        question("judgment", "judgment", "学习「\(concept)」时，只记住结论就代表已经理解适用条件。",
          choices: ["正确", "错误"], answer: "错误",
          explanation: "记住结论只是第一步，还应能说明适用条件并举例检验。"),
        question("choice", "choice", "复习「\(concept)」时，哪种方式更适合检查理解？",
          choices: ["只看标题", "只重复结论", "说明条件并举一个例子", "跳过练习"],
          answer: "说明条件并举一个例子", explanation: "把概念、条件和例子联系起来，可以发现理解中的遗漏。"),
        question("short-answer", "short-answer", "请用「概念—条件—例子」三步复述「\(concept)」的一个学习要点。",
          choices: [], answer: "先说清概念，再说明适用条件，最后用一个例子解释。",
          explanation: "参考表达包括核心概念、适用条件和一个例子。此题用于演示作答与反馈流程。"),
      ]

      for (kind, title, minutes) in [("learn", "学习", 12), ("practice", "练习", 8), ("review", "复习闪卡", 5)] {
        source.plan.tasks.append(StudyTask(task_id: prefix + "::" + kind, user_id: userID,
          day: offset + 1, title: title + " · " + concept, task_type: kind, minutes: minutes,
          chapter_id: chapter.id, lesson_id: lessonID, status: "pending", weak_points: []))
      }
    }
    source.plan.user_id = userID
    source.plan.book_id = original.id
    source.plan.days = max(1, leaves.count)
    source.plan.daily_minutes = 25
    source.summary.status = "ready"
    source.summary.content_mode = "mock_catalog"
    source.summary.next_title = leaves.first?.title
    return source
  }
}
