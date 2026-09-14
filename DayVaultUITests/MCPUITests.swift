import XCTest

final class MCPUITests: XCTestCase {
    @MainActor
    func testProposalCancelConfirmAndReimportUseTheSameValidatedBatch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-preview-journey", "-preview-mcp-proposal",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 5))
        app.buttons["home-more"].tap()
        app.buttons["设置"].tap()
        app.buttons["settings-mcp"].tap()
        let preview = app.buttons["mcp-preview-export"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        preview.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "7 项记录")).firstMatch.exists)

        let importButton = app.buttons["mcp-import"]
        scrollIntoView(importButton, app: app)
        importButton.tap()
        XCTAssertTrue(app.buttons["mcp-confirm-import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["MCP 导入测试事项 1"].exists)
        XCTAssertTrue(app.staticTexts["MCP 导入测试事项 2"].exists)
        app.buttons["取消"].tap()
        scrollIntoView(preview, app: app, upwards: false)
        preview.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "7 项记录")).firstMatch.exists)

        scrollIntoView(importButton, app: app)
        importButton.tap()
        XCTAssertTrue(app.buttons["mcp-confirm-import"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "mcp-proposal-v14"
        attachment.lifetime = .keepAlways
        add(attachment)
        scrollIntoView(app.buttons["mcp-confirm-import"], app: app)
        app.buttons["mcp-confirm-import"].tap()
        XCTAssertTrue(app.staticTexts["mcp-result"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["mcp-result"].label, "已新增 2 项安排。")

        scrollIntoView(preview, app: app, upwards: false)
        preview.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "9 项记录")).firstMatch.exists)
        scrollIntoView(importButton, app: app)
        importButton.tap()
        let alert = app.alerts["无法完成操作"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["部分事项已经存在，没有导入。请移除重复事项后重试。"].exists)
        XCTAssertFalse(app.buttons["mcp-confirm-import"].exists)
        alert.buttons["返回"].tap()
        scrollIntoView(preview, app: app, upwards: false)
        preview.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "9 项记录")).firstMatch.exists)
    }

    @MainActor
    func testMCPStaysInSettingsAndNeedsAGoalBeforeExport() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings-mcp"].exists)
        app.buttons["home-more"].tap()
        app.buttons["设置"].tap()
        let entry = app.buttons["settings-mcp"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        XCTAssertTrue(app.buttons["mcp-import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["暂无目标。请先在“目标管理”中创建目标，并关联需要导出的事项。"].exists)
        XCTAssertFalse(app.buttons["mcp-confirm-export"].exists)
        XCTAssertFalse(app.buttons["mcp-confirm-import"].exists)
    }

    @MainActor
    func testExportRequiresScopePreviewAndDoesNotRevealArchivedMessages() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-inMemoryStore", "-preview-journey", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home-more"].waitForExistence(timeout: 5))
        app.buttons["home-more"].tap()
        app.buttons["设置"].tap()
        app.buttons["settings-mcp"].tap()
        let preview = app.buttons["mcp-preview-export"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mcp-confirm-export"].exists)
        preview.tap()
        XCTAssertTrue(app.buttons["mcp-confirm-export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "7 项记录")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["睡前读一章比较适合我。"].exists)
        XCTAssertFalse(app.buttons["mcp-confirm-import"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "mcp-exchange-v14"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func scrollIntoView(_ element: XCUIElement, app: XCUIApplication, upwards: Bool = true) {
        for _ in 0..<5 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 40 { return }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
    }
}
