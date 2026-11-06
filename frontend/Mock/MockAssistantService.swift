import Foundation

/// Canned demo responses. Neither the selected PDF nor attachments are sent to a model.
enum MockAssistantService {
  static let transcript = "减数分裂前，染色体复制一次，随后细胞连续分裂两次，最终形成染色体数目减半的生殖细胞。"
  static let organizedNote = "减数分裂要点\n\n1. 染色体在分裂前复制一次。\n2. 第一次分裂分离同源染色体，第二次分裂分离姐妹染色单体。\n3. 结果是形成染色体数目减半的生殖细胞。\n\n自测：为什么不能把两次分裂理解成两次复制？"

  static func answer(question: String, title: String, selection: String = "",
    attachments: Int = 0) async throws -> AssistantAnswer {
    try await Task.sleep(for: .milliseconds(900))
    try Task.checkCancellation()
    let text: String
    if question.contains("你好") || question.lowercased() == "hi" {
      text = "你好！我们可以一起梳理知识点、做一道练习，或安排今天的学习。"
    } else if question.contains("计划") || question.contains("安排") {
      text = "今天可以安排 25 分钟：先用 10 分钟阅读本节讲解，接着用 8 分钟完成练习，最后用 7 分钟复习闪卡。完成后，在学习计划中标记任务即可。"
    } else if question.contains("出题") || question.contains("一道题") || question.contains("练习") {
      text = "来做一道示例题：减数分裂过程中，染色体复制和细胞分裂分别发生几次？\n\nA. 复制一次，分裂一次\nB. 复制一次，分裂两次\nC. 复制两次，分裂两次\n\n答案是 B。可以到“章节练习”继续作答，并查看解析。"
    } else if question.contains("比较") || question.contains("区别") {
      text = "可以从过程和结果两方面比较：第一次分裂主要分离同源染色体，染色体数目减半；第二次分裂主要分离姐妹染色单体。记忆时抓住“分开的对象不同”这个关键点。"
    } else if !selection.isEmpty {
      text = "这段内容可以先抓住一句话：\(String(selection.prefix(180)))\n\n学习时先找出概念，再按发生顺序梳理过程，最后用自己的话复述结果。你可以点击辅助图或视频，配合本节示例继续理解。"
    } else if attachments > 0 {
      text = "已收到附件。这是一段预设的演示讲解：先识别材料中的核心概念，再把它整理成“条件 → 过程 → 结果”，最后通过一道练习检查理解。附件保留在当前设备。"
    } else {
      let subject = title.isEmpty ? "本节知识点" : title
      text = "学习“\(subject)”时，可以先理解发生了什么，再追问为什么会这样。\n\n以减数分裂为例：染色体复制一次，细胞连续分裂两次，使生殖细胞的染色体数目减半。把它与受精作用联系起来，就能理解亲子代染色体数目如何保持稳定。\n\n你可以继续查看本节的辅助图、视频和练习。"
    }
    return AssistantAnswer(answer: text, citations: [], sourceLabel: "mock")
  }

  /// Copies bytes only; PDF structure, OCR, document extraction and models are never consulted.
  static func attachment(original: Data, filename: String, isImage: Bool, thumbnail: Data?,
    repository: LocalBookCourseRepository,
    onProgress: @escaping AssistantAttachmentImporter.Progress) async throws -> AssistantAttachment {
    onProgress("正在模拟上传附件…")
    try await Task.sleep(for: .milliseconds(650))
    onProgress("正在准备演示内容…")
    try await Task.sleep(for: .milliseconds(650))
    try Task.checkCancellation()
    let demoText = "本地附件演示：" + filename + "\n\n" + transcript + "\n\n此段文字来自预设数据，未解析附件正文。"
    let ext = (filename as NSString).pathExtension
    let path = try await repository.saveAttachment(original, extension: ext)
    var thumbnailPath: String?
    var textPath: String?
    do {
      textPath = try await repository.saveAttachment(Data(demoText.utf8), extension: "txt")
      if let thumbnail { thumbnailPath = try await repository.saveAttachment(thumbnail, extension: "jpg") }
      try Task.checkCancellation()
      onProgress("附件准备完成")
      return AssistantAttachment(filename: filename, kind: isImage ? .image : .document,
        byteCount: original.count, path: path, thumbnailPath: thumbnailPath, text: "", textPath: textPath,
        characterCount: demoText.count, pageCount: 1)
    } catch {
      for item in [path, thumbnailPath, textPath].compactMap({ $0 }) {
        try? FileManager.default.removeItem(at: repository.attachmentURL(item))
      }
      throw error
    }
  }

  static func photo(bookID: String, imageHash: String,
    onProgress: @MainActor @Sendable (String) -> Void) async throws -> StudioJob {
    await onProgress("transcribing")
    try await Task.sleep(for: .milliseconds(650))
    await onProgress("organizing")
    try await Task.sleep(for: .milliseconds(850))
    try Task.checkCancellation()
    return StudioJob(id: "mock-photo-" + UUID().uuidString, book_id: bookID,
      kind: "photo_note", status: "succeeded", result: [
        "title": .string("减数分裂 · 示例笔记"), "transcript": .string(transcript),
        "polished": .string(organizedNote), "image_sha256": .string(imageHash), "uncertain": .array([]),
      ])
  }

  static func voice(onProgress: @MainActor @Sendable (String) -> Void) async throws -> String {
    await onProgress("transcribing")
    try await Task.sleep(for: .milliseconds(700))
    await onProgress("organizing")
    try await Task.sleep(for: .milliseconds(800))
    try Task.checkCancellation()
    return organizedNote
  }
}
