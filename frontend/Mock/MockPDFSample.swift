import Foundation
import UIKit

/// Optional demo input follows the same staging/upload commands as the file picker.
enum MockPDFSample {
  @MainActor static func make() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("演示教材.pdf")
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
    let data = renderer.pdfData { context in
      context.beginPage()
      ("CloudPath Mock · 演示教材\n\n可替换为任意 PDF；后续使用预置学习内容。" as NSString)
        .draw(in: CGRect(x: 40, y: 60, width: 515, height: 200), withAttributes: [.font: UIFont.systemFont(ofSize: 20)])
    }
    try data.write(to: url, options: .atomic)
    return url
  }
}
