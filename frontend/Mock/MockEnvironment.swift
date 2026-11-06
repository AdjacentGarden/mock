import Foundation
import SwiftUI

/// This repository always runs locally, including Release and configured launch environments.
enum MockEnvironment {
  static let enabled = true
}

enum MockDelay {
  static func wait(_ milliseconds: Int = 800) async throws {
    try await Task.sleep(for: .milliseconds(milliseconds))
    try Task.checkCancellation()
  }
}

/// Reused at asynchronous read boundaries so cached data still demonstrates loading.
struct MockLoadingView<Content: View>: View {
  let title: String
  let identity: String
  @ViewBuilder var content: () -> Content
  @Environment(\.bookCourseReduceMotion) private var reduceMotion
  @State private var loadedIdentity: String?
  var body: some View {
    Group {
      if loadedIdentity == identity {
        content().transition(reduceMotion ? .identity : .opacity)
      } else {
        ProgressView(title).frame(maxWidth: .infinity, maxHeight: .infinity)
          .accessibilityIdentifier("mock.loading")
      }
    }.task(id: identity) {
      do {
        try await MockDelay.wait()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { loadedIdentity = identity }
      } catch { }
    }
  }
}
