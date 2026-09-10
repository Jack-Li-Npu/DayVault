import XCTest

final class AvatarUITests: XCTestCase {
    @MainActor
    func testCompletingANewScheduleUsesALightSummaryAndKeepsEquipmentAvailable() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-inMemoryStore",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
        ]
        app.launch()
        let add = app.buttons["home-add-item"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        saveNewSchedule(named: "Avatar reward test", in: app)

        let complete = app.buttons["完成"]
        XCTAssertTrue(complete.waitForExistence(timeout: 8))
        complete.tap()

        XCTAssertTrue(app.buttons["achievement-summary-open"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["avatar-ceremony-continue"].exists)
        XCTAssertTrue(app.buttons["已完成"].waitForExistence(timeout: 5))
        app.buttons["landing-avatar"].tap()
        XCTAssertTrue(currentCharacter(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(currentCharacter(in: app).label.contains("已完成1件事，穿戴0件成就装备"))
        tapAfterScrolling(app.buttons["avatar-open-wardrobe"], in: app)
        tapAfterScrolling(app.buttons["avatar-reward-starter_band"], in: app)
        tapAfterScrolling(app.buttons["avatar-equip-reward"], in: app)
        app.buttons["avatar-wardrobe-close"].tap()
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴1件成就装备"))
    }

    @MainActor
    func testReviewDefersRealUnlockUntilDismissalAfterAddingFromToday() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-inMemoryStore", "-preview-screen", "today",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
        ]
        app.launch()
        let add = app.buttons["home-add-item"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        saveNewSchedule(named: "Avatar review test", in: app)

        app.buttons["home-more"].tap()
        let review = app.buttons["复盘"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        XCTAssertTrue(app.navigationBars["今日复盘"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Avatar review test"].exists)
        app.buttons["review-complete"].tap()

        XCTAssertTrue(app.navigationBars["今日复盘"].exists)
        XCTAssertFalse(app.staticTexts["新装备 / 来自你的日常"].exists)
        XCTAssertFalse(app.buttons["avatar-ceremony-continue"].exists)
        app.buttons["完成复盘"].tap()

        XCTAssertTrue(app.buttons["achievement-summary-open"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["avatar-ceremony-continue"].exists)
        XCTAssertTrue(app.buttons["已完成"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLockedEquipmentCanBePreviewedButCannotBeEquipped() {
        let app = launchVault()
        XCTAssertTrue(app.staticTexts["这是现在的你。"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["0 / 6 件"].exists)
        captureScreenshot(named: "studio", in: app)

        tapAfterScrolling(app.buttons["avatar-open-wardrobe"], in: app)
        XCTAssertTrue(app.buttons["avatar-reward-starter_band"].waitForExistence(timeout: 5))
        captureScreenshot(named: "wardrobe", in: app)
        tapAfterScrolling(app.buttons["avatar-reward-ten_jacket"], in: app)

        XCTAssertTrue(app.staticTexts["十次行动夹克"].waitForExistence(timeout: 5))
        captureScreenshot(named: "locked-detail", in: app)
        scrollIntoView(app.staticTexts["avatar-preview-only"], in: app)
        XCTAssertTrue(app.staticTexts["avatar-preview-only"].exists)
        XCTAssertFalse(app.buttons["avatar-equip-reward"].exists)
        app.buttons["avatar-reward-detail-close"].tap()
        app.buttons["avatar-wardrobe-close"].tap()

        XCTAssertTrue(app.staticTexts["0 / 6 件"].waitForExistence(timeout: 5))
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴0件成就装备"))
    }

    @MainActor
    func testCompletedScheduleUnlocksEquipmentThatCanBeWorn() {
        let app = launchVault(sampleData: true)
        XCTAssertTrue(app.staticTexts["1 / 6 件"].waitForExistence(timeout: 8))
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴0件成就装备"))

        tapAfterScrolling(app.buttons["avatar-open-wardrobe"], in: app)
        tapAfterScrolling(app.buttons["avatar-reward-starter_band"], in: app)
        let equip = app.buttons["avatar-equip-reward"]
        scrollIntoView(equip, in: app)
        XCTAssertEqual(equip.label, "穿上这件")
        XCTAssertTrue(equip.isEnabled)
        equip.tap()

        let reward = app.buttons["avatar-reward-starter_band"]
        XCTAssertTrue(reward.waitForExistence(timeout: 5))
        XCTAssertTrue(reward.label.contains("穿戴中"))
        app.buttons["avatar-wardrobe-close"].tap()
        XCTAssertTrue(currentCharacter(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴1件成就装备"))
        XCTAssertTrue(app.staticTexts["1 / 6 件"].exists)
    }

    @MainActor
    func testCeremonyPreviewDoesNotGrantEquipmentOrAchievements() {
        let app = launchVault()
        XCTAssertTrue(app.staticTexts["0 / 6 件"].waitForExistence(timeout: 8))
        app.buttons["成就册"].tap()
        XCTAssertTrue(app.staticTexts["00"].waitForExistence(timeout: 5))
        app.buttons["我的角色"].tap()

        tapAfterScrolling(app.buttons["avatar-preview-ceremony"], in: app)
        XCTAssertTrue(app.staticTexts["演出预览 / 不会获得装备"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["avatar-equip-reward"].exists)
        XCTAssertTrue(app.buttons["avatar-ceremony-continue"].waitForExistence(timeout: 5))
        captureScreenshot(named: "ceremony-preview", in: app)
        let close = app.buttons["avatar-ceremony-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(currentCharacter(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴0件成就装备"))
        app.buttons["成就册"].tap()
        XCTAssertTrue(app.staticTexts["00"].waitForExistence(timeout: 5))
        app.buttons["我的角色"].tap()
        XCTAssertTrue(app.staticTexts["0 / 6 件"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testConcealedEquipmentDoesNotRevealItsNameOrUnlockRule() {
        let app = launchVault()
        XCTAssertTrue(app.staticTexts["这是现在的你。"].waitForExistence(timeout: 8))
        tapAfterScrolling(app.buttons["avatar-open-wardrobe"], in: app)
        let reward = app.buttons["avatar-reward-comeback_bandana"]
        scrollIntoView(reward, in: app)
        XCTAssertEqual(reward.label, "未署名装备，尚未获得")
        reward.tap()

        XCTAssertTrue(app.staticTexts["先留一点悬念。某段经历，会让它显露原貌。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["回归头巾"].exists)
        XCTAssertFalse(app.staticTexts["获得方式"].exists)
        XCTAssertFalse(app.buttons["avatar-equip-reward"].exists)
    }

    @MainActor
    func testLargeTypeAndReduceMotionKeepWardrobeAndCeremonyUsable() {
        let app = launchVault(accessibility: true)
        XCTAssertTrue(app.staticTexts["这是现在的你。"].waitForExistence(timeout: 8))
        captureScreenshot(named: "accessibility-studio", in: app)
        tapAfterScrolling(app.buttons["avatar-open-wardrobe"], in: app)
        tapAfterScrolling(app.buttons["avatar-reward-ten_jacket"], in: app)
        XCTAssertTrue(app.staticTexts["十次行动夹克"].waitForExistence(timeout: 5))
        scrollIntoView(app.staticTexts["avatar-preview-only"], in: app)
        XCTAssertFalse(app.buttons["avatar-equip-reward"].exists)
        app.buttons["avatar-reward-detail-close"].tap()
        app.buttons["avatar-wardrobe-close"].tap()

        tapAfterScrolling(app.buttons["avatar-preview-ceremony"], in: app)
        let finish = app.buttons["avatar-ceremony-continue"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        scrollIntoView(finish, in: app)
        XCTAssertTrue(finish.isHittable)
        captureScreenshot(named: "accessibility-ceremony", in: app)
        finish.tap()

        XCTAssertTrue(currentCharacter(in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(currentCharacter(in: app).label.contains("穿戴0件成就装备"))
    }

    @MainActor
    private func launchVault(sampleData: Bool = false, accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-inMemoryStore",
            "-preview-screen", "vault",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        if sampleData { app.launchArguments.append("-preview-sample-data") }
        if accessibility { app.launchArguments.append("-preview-accessibility") }
        app.launch()
        return app
    }

    @MainActor
    private func currentCharacter(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["avatar-current-character"]
    }

    @MainActor
    private func saveNewSchedule(named name: String, in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["加一件事"].waitForExistence(timeout: 5))
        let title = app.textFields["写下这件事"].exists
            ? app.textFields["写下这件事"]
            : app.textViews["写下这件事"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(name)
        app.buttons["加入日程"].tap()
    }

    @MainActor
    private func captureScreenshot(named name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tapAfterScrolling(_ element: XCUIElement, in app: XCUIApplication) {
        scrollIntoView(element, in: app)
        element.tap()
    }

    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 40 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        XCTAssertTrue(element.isHittable)
    }
}
