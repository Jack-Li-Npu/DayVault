import XCTest

final class DayVaultUITests: XCTestCase {
    @MainActor
    func testFirstLaunchStartsWithDailyRecordsWithoutAIEntries() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["agenda-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home-add-item"].exists)
        XCTAssertTrue(app.buttons["home-open-goals"].exists)
        XCTAssertTrue(app.buttons["home-more"].exists)
        assertNoAIEntries(in: app)
        XCTAssertEqual(app.tabBars.count, 0)
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "daily-first-launch"
        home.lifetime = .keepAlways
        add(home)
    }

    @MainActor
    func testManualGoalCreationNeedsNoAIOrConsent() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["home-open-goals"].waitForExistence(timeout: 5))
        app.buttons["home-open-goals"].tap()
        let title = app.textFields["goal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["goal-create"].isEnabled)
        title.tap()
        title.typeText("Daily writing")
        app.buttons["goal-create"].tap()

        XCTAssertTrue(app.buttons["goal-detail-close"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Daily writing"].exists)
        XCTAssertTrue(app.staticTexts["已记录 0 次完成"].exists)
        XCTAssertTrue(app.buttons["关联已有记录"].exists)
        XCTAssertFalse(app.buttons["goal-history-archive"].exists)
        assertNoAIEntries(in: app)

        app.buttons["goal-detail-close"].tap()
        app.buttons["goals-close"].tap()
        XCTAssertTrue(app.buttons["home-open-goals"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home-open-goals"].label, "Daily writing")
        XCTAssertTrue(app.buttons["home-add-item"].exists)
    }

    @MainActor
    func testMoreMenuKeepsManualToolsWithoutHiddenAIEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 5))
        app.buttons["home-more"].tap()
        XCTAssertTrue(app.buttons["目标管理"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["日历"].exists)
        XCTAssertTrue(app.buttons["复盘"].exists)
        XCTAssertTrue(app.buttons["设置"].exists)
        assertNoAIEntries(in: app)
        app.buttons["目标管理"].tap()
        XCTAssertTrue(app.textFields["goal-title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTodayShowsASequenceInsteadOfAnHourlyTimeline() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-preview-screen", "today",
            "-preview-sample-data",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["agenda-list"].waitForExistence(timeout: 8))
        let task = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "整理作品集方向")).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["23:00"].exists)

        task.tap()
        XCTAssertTrue(app.buttons["开始"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["保存调整"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCalendarUsesTheEditorialMonthAndSharedAgenda() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-preview-screen", "calendar",
            "-preview-sample-data",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["editorial-month-picker"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.buttons
                .matching(NSPredicate(format: "label CONTAINS %@", "整理作品集方向"))
                .firstMatch
                .waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["23:00"].exists)
    }

    @MainActor
    func testEditorKeepsAdvancedOptionsOutOfTheFirstDecision() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-preview-editor",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["新增事项"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["事项名称"].exists)
        XCTAssertTrue(app.staticTexts["计划日期"].exists)
        XCTAssertFalse(app.staticTexts["分类"].exists)
        XCTAssertFalse(app.staticTexts["优先级"].exists)
        XCTAssertTrue(app.datePickers["日期"].isHittable)
        XCTAssertFalse(app.datePickers["时间"].exists)

        let advanced = app.buttons["editor-advanced-toggle"]
        XCTAssertTrue(advanced.waitForExistence(timeout: 3))
        XCTAssertTrue(advanced.isHittable)
        advanced.tap()

        XCTAssertTrue(app.buttons["editor-time-mode-dateOnly"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["提醒"].exists)
        app.buttons["editor-time-mode-timed"].tap()
        XCTAssertTrue(app.datePickers["时间"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["重复"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["提醒"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDateOnlyRecordNeverShowsAnImplicitMidnight() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-add-item"].waitForExistence(timeout: 5))
        app.buttons["home-add-item"].tap()
        let title = app.textFields["输入事项名称"].exists ? app.textFields["输入事项名称"] : app.textViews["输入事项名称"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Read one chapter")
        app.buttons["加入日程"].tap()
        let record = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Read one chapter")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.label.contains("当天完成"))
        XCTAssertFalse(record.label.contains("00:00"))
        record.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当天完成")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.steppers.firstMatch.exists)
    }

    @MainActor
    func testExistingRecordsCanBeAssociatedWithAManualGoal() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-inMemoryStore", "-preview-sample-data",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["home-open-goals"].waitForExistence(timeout: 5))
        app.buttons["home-open-goals"].tap()
        let title = app.textFields["goal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Portfolio")
        app.buttons["goal-create"].tap()
        XCTAssertTrue(app.buttons["goal-detail-close"].waitForExistence(timeout: 5))
        app.buttons["关联已有记录"].tap()
        let record = app.switches["整理作品集方向"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["确认关联"].isEnabled)
        record.tap()
        XCTAssertTrue(app.buttons["确认关联"].isEnabled)
        app.buttons["确认关联"].tap()
        XCTAssertTrue(app.buttons["goal-detail-close"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["goal-history-archive"].exists)
        assertNoAIEntries(in: app)

        app.buttons["关联已有记录"].tap()
        XCTAssertTrue(app.navigationBars["关联到：Portfolio"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["整理作品集方向"].exists)
        XCTAssertFalse(app.buttons["确认关联"].isEnabled)
    }

    @MainActor
    func testNewUsersSeePublicAchievementsWithoutPersonalGeneration() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-preview-screen", "vault", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["成就册"].waitForExistence(timeout: 5))
        app.buttons["成就册"].tap()
        XCTAssertTrue(app.staticTexts["00"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["vault-personal-achievements"].exists)
        XCTAssertFalse(app.buttons["vault-public-achievements"].exists)
        assertNoAIEntries(in: app)
    }

    @MainActor
    func testArchivedCompanionshipKeepsSourcesAndReplayWithoutAIControls() {
        let app = launchArchivedJourney()
        assertNoAIEntries(in: app)
        openArchivedCompanionship(in: app)
        XCTAssertTrue(app.staticTexts["历史共同记录：7 天"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["你已在七个不同日期留下阅读记录。"].exists)
        assertNoAIEntries(in: app)
        XCTAssertFalse(app.buttons["发送"].exists)

        scrollIntoView(app.buttons["查看依据"], in: app)
        app.buttons["查看依据"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "· 阅读一章")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["companion-options"].tap()
        app.buttons["回顾成长演出"].tap()
        XCTAssertTrue(app.buttons["duet-skip"].waitForExistence(timeout: 5))
        app.buttons["duet-skip"].tap()
        XCTAssertTrue(app.staticTexts["历史共同记录：7 天"].waitForExistence(timeout: 5))

        app.buttons["companion-options"].tap()
        app.buttons["回顾成长演出"].tap()
        let replay = app.buttons["duet-replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 9))
        scrollIntoView(replay, in: app)
        replay.tap()
        XCTAssertFalse(app.buttons["duet-continue"].exists)
        let skip = app.buttons["duet-skip"]
        for _ in 0..<4 {
            if skip.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(skip.isHittable)
        skip.tap()
        XCTAssertTrue(app.staticTexts["历史共同记录：7 天"].waitForExistence(timeout: 5))
        assertNoAIEntries(in: app)
    }

    @MainActor
    func testArchivedMemoriesCanStillBeEditedAndDeletedLocally() {
        let app = launchArchivedJourney()
        openArchivedCompanionship(in: app)
        app.buttons["companion-options"].tap()
        app.buttons["历史回忆"].tap()
        XCTAssertTrue(app.navigationBars["历史回忆"].waitForExistence(timeout: 5))
        // SwiftUI's multiline field can be reported as either TextField or TextView.
        let memory = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "archived-memory-input-"))
            .firstMatch
        XCTAssertTrue(memory.waitForExistence(timeout: 5))
        XCTAssertEqual(memory.value as? String, "睡前读一章比较适合我。")
        assertNoAIEntries(in: app)
        memory.tap()
        memory.typeText(" 每周回看一次。")
        scrollIntoView(app.buttons["保存修改"], in: app)
        app.buttons["保存修改"].tap()
        app.navigationBars["历史回忆"].buttons["返回"].tap()

        XCTAssertTrue(app.buttons["companion-options"].waitForExistence(timeout: 5))
        app.buttons["companion-options"].tap()
        app.buttons["历史回忆"].tap()
        XCTAssertTrue(memory.waitForExistence(timeout: 5))
        XCTAssertTrue((memory.value as? String)?.contains("每周回看一次。") == true)
        scrollIntoView(app.buttons["删除"], in: app)
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["暂无历史回忆。"].waitForExistence(timeout: 5))
        XCTAssertFalse(memory.exists)
    }

    @MainActor
    func testSavedPersonalAchievementsRemainSeparateFromPublicCollection() {
        let app = launchArchivedJourney(screen: "vault")
        XCTAssertTrue(app.buttons["成就册"].waitForExistence(timeout: 5))
        app.buttons["成就册"].tap()
        XCTAssertTrue(app.buttons["vault-personal-achievements"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["vault-public-achievements"].isSelected)
        app.buttons["vault-personal-achievements"].tap()
        XCTAssertTrue(app.staticTexts["personal-achievements-heading"].waitForExistence(timeout: 5))
        let achievement = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "累计记录 7 天")).firstMatch
        XCTAssertTrue(achievement.waitForExistence(timeout: 5))
        XCTAssertTrue(achievement.label.contains("已获得"))
        assertNoAIEntries(in: app)
        achievement.tap()
        XCTAssertTrue(app.staticTexts["7 / 7 天"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["预览分享卡"].exists)
        scrollIntoView(app.buttons["解锁依据"], in: app)
        app.buttons["解锁依据"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "· 已记录完成")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchArchivedJourney(screen: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-inMemoryStore", "-preview-journey",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
        ]
        if let screen { app.launchArguments += ["-preview-screen", screen] }
        app.launch()
        return app
    }

    @MainActor
    private func openArchivedCompanionship(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["home-open-goals"].waitForExistence(timeout: 5))
        app.buttons["home-open-goals"].tap()
        XCTAssertTrue(app.buttons["详情"].waitForExistence(timeout: 5))
        app.buttons["详情"].tap()
        XCTAssertTrue(app.buttons["goal-history-archive"].waitForExistence(timeout: 5))
        app.buttons["goal-history-archive"].tap()
        XCTAssertTrue(app.buttons["companion-options"].waitForExistence(timeout: 5))
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

    @MainActor
    private func assertNoAIEntries(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for identifier in ["home-open-planner", "home-open-companion", "home-companion-response", "companion-enable", "companion-consent-confirm"] {
            XCTAssertFalse(app.buttons[identifier].exists, "Unexpected AI entry: \(identifier)", file: file, line: line)
        }
        for title in ["生成计划", "AI 帮我安排", "目标规划", "启用 AI 陪伴", "重新生成个人成就", "生成七日调整建议"] {
            XCTAssertFalse(app.buttons[title].exists, "Unexpected AI action: \(title)", file: file, line: line)
        }
        XCTAssertFalse(app.textFields["输入目标与期限…"].exists, file: file, line: line)
        XCTAssertFalse(app.descendants(matching: .any)["companion-input"].exists, file: file, line: line)
    }
}
