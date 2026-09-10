import XCTest

final class DayVaultUITests: XCTestCase {
    @MainActor
    func testFirstLaunchStartsWithDailyRecordsWithoutForcedChat() {
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
        XCTAssertTrue(app.buttons["home-open-planner"].exists)
        XCTAssertFalse(app.textFields["描述一个目标…"].exists)
        XCTAssertFalse(app.buttons["制定计划"].exists)
        XCTAssertEqual(app.tabBars.count, 0)
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "daily-first-launch"
        home.lifetime = .keepAlways
        add(home)
    }

    @MainActor
    func testVagueGoalGetsOneSimpleQuestion() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui-testing",
            "-inMemoryStore",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
        ]
        app.launch()

        let planner = app.buttons["home-open-planner"]
        XCTAssertTrue(planner.waitForExistence(timeout: 5))
        planner.tap()

        let goal = app.textFields["描述一个目标…"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        goal.typeText("I want to learn pottery")
        app.buttons["制定计划"].tap()

        XCTAssertTrue(app.staticTexts["你希望什么时候看到成果？"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["本地演示 · 非 AI 生成"].exists)
    }

    @MainActor
    func testLocalPlanIsClearlyLabeledAfterGeneration() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-open-planner"].waitForExistence(timeout: 5))
        app.buttons["home-open-planner"].tap()
        let goal = app.textFields["描述一个目标…"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        goal.typeText("Give a speech in 6 weeks")
        app.buttons["制定计划"].tap()
        XCTAssertTrue(app.staticTexts["本地演示 · 非 AI 生成"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["AI 草案"].exists)
        XCTAssertFalse(app.staticTexts["AI 生成 · 待你确认"].exists)
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

        XCTAssertTrue(app.staticTexts["加一件事"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["要做什么"].exists)
        XCTAssertTrue(app.staticTexts["什么时候"].exists)
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
        let title = app.textFields["写下这件事"].exists ? app.textFields["写下这件事"] : app.textViews["写下这件事"]
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
    func testCompanionIsOptionalAndDuetReplayDoesNotAddProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-open-goals"].waitForExistence(timeout: 5))
        app.buttons["home-open-goals"].tap()
        let title = app.textFields["goal-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Daily writing")
        app.buttons["建立"].tap()
        XCTAssertTrue(app.buttons["goal-detail-close"].waitForExistence(timeout: 5))
        app.buttons["goal-detail-close"].tap()
        app.buttons["goals-close"].tap()
        app.buttons["home-open-companion"].tap()

        XCTAssertTrue(app.buttons["companion-enable"].waitForExistence(timeout: 5))
        app.buttons["companion-enable"].tap()
        XCTAssertTrue(app.buttons["暂不开启"].waitForExistence(timeout: 5))
        app.buttons["暂不开启"].tap()
        XCTAssertTrue(app.buttons["companion-enable"].waitForExistence(timeout: 5))

        app.buttons["companion-options"].tap()
        app.buttons["看看我们的配合"].tap()
        XCTAssertTrue(app.buttons["duet-skip"].waitForExistence(timeout: 5))
        app.buttons["duet-skip"].tap()
        XCTAssertTrue(app.staticTexts["一起记录了 0 天"].waitForExistence(timeout: 5))

        app.buttons["companion-options"].tap()
        app.buttons["看看我们的配合"].tap()
        let replay = app.buttons["duet-replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 9))
        let duet = XCTAttachment(screenshot: app.screenshot())
        duet.name = "duet-ready"
        duet.lifetime = .keepAlways
        add(duet)
        for _ in 0..<4 {
            if replay.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(replay.isHittable)
        replay.tap()
        XCTAssertFalse(app.buttons["duet-continue"].exists)
        let skip = app.buttons["duet-skip"]
        for _ in 0..<4 {
            if skip.isHittable { break }
            app.swipeDown()
        }
        skip.tap()
        XCTAssertTrue(app.staticTexts["一起记录了 0 天"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["companion-enable"].exists)
        app.buttons["companion-close"].tap()
        XCTAssertTrue(app.buttons["home-add-item"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPublicAndPersonalAchievementsStayInOneCollection() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-preview-screen", "vault", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["成就册"].waitForExistence(timeout: 5))
        app.buttons["成就册"].tap()
        XCTAssertTrue(app.staticTexts["00"].waitForExistence(timeout: 5))
        app.buttons["vault-personal-achievements"].tap()
        XCTAssertTrue(app.staticTexts["只属于这段旅程。"].waitForExistence(timeout: 5))
        app.buttons["vault-public-achievements"].tap()
        XCTAssertTrue(app.staticTexts["00"].waitForExistence(timeout: 5))
    }
}
