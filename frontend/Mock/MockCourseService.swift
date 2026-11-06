import Foundation

/// Preset teaching data. No PDF parser, OCR, server or model runs here.
enum MockCourseService {
  static let preparationStages: [(String, String)] = [
    ("queued", "已交给后端预处理（模拟）"),
    ("indexing", "正在解析教材（模拟）"),
    ("structuring", "正在整理目录与章节（模拟）"),
    ("diagnostics", "正在准备学习诊断题（模拟）"),
  ]

  static func preparedSource(from original: SourceContent, includeLearning: Bool = false) throws -> SourceContent {
    let presets = try ContentBundle.load([SourceContent].self, name: "sources") + MockBookContent.extraSources
    let title = original.summary.title.lowercased()
    let matches: [(String, [String])] = [
      ("catalog_micro_psychology_set", ["心理", "表情", "psychology"]),
      ("catalog_theoretical_mechanics_1", ["理论力学", "mechanics"]),
      ("community_ecology", ["生态", "ecology"]),
      ("community_motion", ["力与运动", "运动实验"]),
      ("community_functions", ["函数与导数", "functions"]),
      ("catalog_advanced_mathematics_1", ["高等数学", "微积分", "calculus"]),
      ("catalog_high_school_math_required_2", ["数学", "math"]),
      ("catalog_physics_required_3", ["物理", "physics"]),
      ("catalog_chemistry_required_2", ["化学", "chemistry"]),
      ("catalog_english_required_3", ["英语", "english"]),
    ]
    let templateID = MockBookContent.book(original.id) != nil ? original.id
      : matches.first { $0.1.contains(where: title.contains) }?.0 ?? "book_biology_2"
    guard let preset = presets.first(where: { $0.id == templateID }) else {
      throw ContentError.missing("mock 学习内容")
    }
    var result = MockCatalogService.source(from: preset)
    // Book ownership changes; chapter/lesson IDs stay stable within each book as in the real API.
    result.summary.book_id = original.id
    result.summary.title = original.summary.title
    result.summary.filename = original.summary.filename
    result.summary.status = "ready"
    result.summary.content_mode = "mock"
    result.summary.next_title = "演示课程 · 预置学习内容"
    result.summary.updated_at = Date().timeIntervalSince1970
    for i in result.lessons.indices {
      result.lessons[i].book_id = original.id
      result.lessons[i].status = "ready"
      result.lessons[i].warnings = []
    }
    for i in result.chunks.indices { result.chunks[i].book_id = original.id }
    for i in result.assets.indices { result.assets[i].book_id = original.id }
    for i in result.flashcards.indices { result.flashcards[i].book_id = original.id }
    for i in result.quizzes.indices { result.quizzes[i].book_id = original.id }
    result.plan.book_id = original.id
    // All dates are relative to this demo session; every task starts incomplete.
    for i in result.plan.tasks.indices { result.plan.tasks[i].status = "pending" }
    if !includeLearning {
      result.lessons = []; result.flashcards = []; result.quizzes = []; result.plan.tasks = []
    }
    return result
  }
}

@MainActor extension AppStore {
  func runMockCourseImport(_ id: String, epoch: UUID) async {
    guard let record = courseImport(for: id) else { return }
    updateCourseImport(id) {
      $0.started = true; $0.error = nil; $0.onDeviceOnly = false
      $0.job = ImportJob(bookIDs: record.books.map(\.id), status: .running)
    }
    do {
      for (offset, book) in record.books.enumerated() {
        guard let source = sources.first(where: { $0.id == book.id }) else {
          throw ContentError.missing("待处理教材")
        }
        // Existing books keep their completed lessons when adding more materials.
        if !source.lessons.isEmpty {
          updateCourseImport(id) { value in
            if let index = value.books.firstIndex(where: { $0.id == book.id }) {
              value.books[index].status = .completed; value.books[index].progress = 1
            }
          }
          continue
        }
        for (stageIndex, stage) in MockCourseService.preparationStages.enumerated() {
          try Task.checkCancellation()
          guard epoch == cloudState.epoch else { throw CancellationError() }
          let fraction = Double(stageIndex) / Double(MockCourseService.preparationStages.count)
          updateCourseImport(id) { value in
            value.job.progress = (Double(offset) + fraction) / Double(record.books.count)
            value.job.message = stage.1; value.job.preparationStage = stage.0
            if let index = value.books.firstIndex(where: { $0.id == book.id }) {
              value.books[index].status = .running; value.books[index].stage = stage.0
              value.books[index].progress = fraction; value.books[index].message = stage.1
            }
          }
          try await MockDelay.wait(600)
        }
        guard epoch == cloudState.epoch, let index = sources.firstIndex(where: { $0.id == book.id }) else {
          throw CancellationError()
        }
        sources[index] = try MockCourseService.preparedSource(from: source)
        updateCourseImport(id) { value in
          if let index = value.books.firstIndex(where: { $0.id == book.id }) {
            value.books[index].status = .completed; value.books[index].stage = "ready"
            value.books[index].progress = 1; value.books[index].message = "预处理成功（模拟）"
          }
        }
      }
      try await repository.saveSources(sources)
      try Task.checkCancellation()
      guard epoch == cloudState.epoch else { throw CancellationError() }
      updateCourseImport(id) {
        $0.job.status = .completed; $0.job.progress = 1
        $0.job.message = "教材解析与预处理成功（模拟）"; $0.draft.parseCompleted = true
      }
      if Set(draft.resourceIDs) == Set(record.books.map(\.id)) { draft.parseCompleted = true }
      showToast("预处理成功", kind: .success, subtitle: "已准备好演示目录与诊断题")
      // Keep the complete state visible before moving to the course questionnaire.
      try await MockDelay.wait(500)
    } catch {
      guard epoch == cloudState.epoch else { return }
      updateCourseImport(id) {
        $0.job.status = error is CancellationError ? .interrupted : .failed
        $0.error = error is CancellationError ? "整理已暂停，可以继续" : error.localizedDescription
        for i in $0.books.indices where $0.books[i].status == .running { $0.books[i].status = $0.job.status }
      }
    }
  }

  func generateMockCourse() {
    guard !mockCourseGenerating else { return }
    mockCourseGenerating = true
    mockCourseGenerationError = nil
    let ids = draft.resourceIDs
    let epoch = cloudState.epoch
    Task { @MainActor in
      defer { mockCourseGenerating = false }
      do {
        processingMessage = "正在生成学习内容（模拟）…"
        try await MockDelay.wait(900)
        var generated = sources
        for id in ids {
          guard let index = generated.firstIndex(where: { $0.id == id }) else { throw ContentError.missing(id) }
          // Adding a new PDF leaves the original books' content and progress available.
          if !generated[index].lessons.isEmpty, chapterDrafts[id] == nil { continue }
          var source = try MockCourseService.preparedSource(from: generated[index], includeLearning: true)
          // Apply the user's confirmed outline and keep all dependent rows consistent.
          let outline = chapterDrafts[id] ?? generated[index].chapters
          source.chapters = outline
          let allowed = Set(outline.map(\.id))
          source.lessons.removeAll { !allowed.contains($0.chapter_id) }
          for i in source.lessons.indices {
            if let chapter = outline.first(where: { $0.id == source.lessons[i].chapter_id }) {
              source.lessons[i].title = chapter.title
            }
          }
          source.flashcards.removeAll { !allowed.contains($0.chapter_id) }
          source.quizzes.removeAll { !allowed.contains($0.chapter_id) }
          source.plan.tasks.removeAll { $0.chapter_id.map { !allowed.contains($0) } ?? false }
          source.summary.chapter_count = outline.filter { $0.parent_id == nil }.count
          generated[index] = source
        }
        processingMessage = "正在生成练习、闪卡和学习计划（模拟）…"
        try await MockDelay.wait(900)
        guard epoch == cloudState.epoch, ids == draft.resourceIDs else { throw CancellationError() }
        try await repository.saveSources(generated)
        sources = generated
        for id in ids { chapterDrafts.removeValue(forKey: id) }
        createCourse(name: draft.name, resourceIDs: ids, diagnosis: draft.diagnosis)
        showToast("课程生成成功", kind: .success)
        go(.study)
      } catch is CancellationError { }
      catch { mockCourseGenerationError = error.localizedDescription }
    }
  }
}
