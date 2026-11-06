import XCTest

/// Visible smoke checks against local mock data; no remote account or API is used.
final class MockUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  private func launch(_ route: String, flags: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--fixture", "--fixture-session", "mock-ui-" + UUID().uuidString,
      "--route", route, "--chapter", "c2s1", "--fixture-reduce-motion"] + flags
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    return app
  }

  private func tap(_ element: XCUIElement, in app: XCUIApplication) {
    XCTAssertTrue(element.waitForExistence(timeout: 15))
    for _ in 0..<12 {
      if element.isHittable { break }
      let scroll = app.scrollViews.allElementsBoundByIndex.last ?? app
      scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.78)).press(
        forDuration: 0.05,
        thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.30)))
    }
    XCTAssertTrue(element.isHittable, "Control must be reachable: \(element)")
    element.tap()
  }

  private func evidence(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func wait(_ description: String, timeout: TimeInterval = 15,
    condition: @escaping () -> Bool) {
    let expected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, description)
  }

  func testNormalLaunchCompletesOnboardingWithoutAServiceOrFixtureFlag() {
    let app = XCUIApplication()
    app.launchArguments = ["--cloud-test-session", "mock-normal-" + UUID().uuidString, "--fixture-reduce-motion"]
    app.launchEnvironment["BOOKCOURSE_API_BASE_URL"] = "https://backend.invalid"
    app.launch()
    let name = app.textFields["onboarding.name"]
    XCTAssertTrue(name.waitForExistence(timeout: 20))
    XCTAssertFalse(app.textFields["cloud.email"].exists)
    name.tap()
    name.typeText("Mock learner\n")
    for _ in 0..<5 { tap(app.buttons["onboarding.skip"], in: app) }
    XCTAssertTrue(app.buttons["study.course.switch"].waitForExistence(timeout: 15))
    evidence("mock-normal-launch-ready", app: app)
  }

  func testPDFUploadPreprocessingAndCourseGenerationAreVisible() {
    let app = launch("upload")
    tap(app.buttons["upload.sample"], in: app)
    XCTAssertTrue(app.buttons["upload.save"].isEnabled)
    tap(app.buttons["upload.save"], in: app)
    let success = app.alerts["上传成功"]
    XCTAssertTrue(success.waitForExistence(timeout: 15))
    evidence("mock-pdf-upload-success", app: app)
    success.buttons["继续整理"].tap()
    let processing = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "预处理")).firstMatch
    XCTAssertTrue(processing.waitForExistence(timeout: 5))
    evidence("mock-pdf-preprocessing", app: app)
    let selections = [
      ("urgency", "steady"), ("timePattern", "block"), ("goals", "systematic"),
      ("contentFoci", "principles"), ("aids", "chat"), ("reviews", "periodic"),
    ]
    for (index, selection) in selections.enumerated() {
      tap(app.buttons["courseSetup.option.\(selection.0).\(selection.1)"], in: app)
      if index >= 2 { tap(app.buttons["courseSetup.next"], in: app) }
    }
    let confirm = app.buttons["chapters.confirm"]
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    evidence("mock-pdf-confirm-outline", app: app)
    tap(confirm, in: app)
    wait("Generation should visibly disable its confirmation button", timeout: 3) {
      confirm.exists && !confirm.isEnabled && confirm.label.contains("正在生成")
    }
    evidence("mock-course-generating", app: app)
    XCTAssertTrue(app.buttons["study.course.switch"].waitForExistence(timeout: 15))
    XCTAssertFalse(app.staticTexts["chapters.confirm"].exists)
    evidence("mock-generated-course-ready", app: app)
  }

  func testImageAndVideoGenerationProduceLocalResultsAndVideoPlays() {
    let app = launch("lesson")
    XCTAssertTrue(app.staticTexts["lesson.page"].waitForExistence(timeout: 20))
    tap(app.buttons["lesson.image.generate.open"], in: app)
    tap(app.buttons["lesson.media.generate"], in: app)
    XCTAssertTrue(app.descendants(matching: .any)["lesson.media.loading"].firstMatch.waitForExistence(timeout: 3))
    let image = app.descendants(matching: .any)["lesson.media.image"].firstMatch
    XCTAssertTrue(image.waitForExistence(timeout: 10))
    XCTAssertFalse(app.staticTexts["lesson.media.error"].exists)
    evidence("mock-generated-image", app: app)
    app.buttons["lesson.media.close"].tap()

    tap(app.buttons["lesson.video.generate.open"], in: app)
    tap(app.buttons["lesson.media.generate"], in: app)
    XCTAssertTrue(app.descendants(matching: .any)["lesson.media.loading"].firstMatch.waitForExistence(timeout: 3))
    let player = app.descendants(matching: .any)["lesson.media.player"].firstMatch
    XCTAssertTrue(player.waitForExistence(timeout: 10))
    wait("The bundled video should advance beyond its first frame") {
      (Double(player.value as? String ?? "") ?? 0) > 0.2
    }
    XCTAssertFalse(app.staticTexts["视频暂时无法播放，请关闭后重新打开。"].exists)
    evidence("mock-generated-video-playing", app: app)
    app.buttons["lesson.media.close"].tap()
    tap(app.buttons["lesson.video.generate.open"], in: app)
    XCTAssertTrue(player.waitForExistence(timeout: 10), "The completed local video should reopen")
    evidence("mock-video-reopened", app: app)
  }

  func testAssistantAnswersLocallyAndCorePagesRemainReachable() {
    let app = launch("lesson", flags: ["--assistant"])
    let input = app.descendants(matching: .any)["guide-input"].firstMatch
    XCTAssertTrue(input.waitForExistence(timeout: 20))
    input.tap()
    input.typeText("Hi")
    app.buttons["guide-send"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["guide-ai-message"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "你好！我们可以一起")).firstMatch.exists)
    evidence("mock-assistant-local-answer", app: app)
    app.buttons["global-assistant-close"].tap()
    XCTAssertTrue(app.staticTexts["lesson.page"].waitForExistence(timeout: 10))
    app.buttons["navigation.back"].firstMatch.tap()
    tap(app.buttons["tab-community"], in: app)
    XCTAssertTrue(app.textFields["community.search"].waitForExistence(timeout: 10))
    evidence("mock-discovery", app: app)
    tap(app.buttons["tab-profile"], in: app)
    XCTAssertTrue(app.staticTexts["PROFILE"].firstMatch.waitForExistence(timeout: 10))
    evidence("mock-profile", app: app)
  }
}
