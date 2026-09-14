# Contributing

[简体中文](#中文) · [English](#english)

## 中文

DayVault 这一轮实验到 v1.4 收尾。欢迎修复数据、可访问性和兼容性问题；暂不规划社交平台、远端 AI 服务或新的付费系统。较大的改动请先开 issue 说明使用场景，不必先写完整方案。

修改前请阅读 [开发指南](docs/DEVELOPMENT.zh-CN.md)。提交时说明问题、改动和验证方法。行为变化需要测试，界面变化附中文截图；截图和 MCP 测试文件只使用虚构数据。不要上传 API 密钥、个人记录、签名文件或 Xcode 用户配置。

App 工程由 `project.yml` 生成。修改目标、版本或文件分组后运行 `xcodegen generate`，并一并提交工程变更。不要通过清空 SwiftData 数据库解决迁移问题。

MCP 的读写范围见 [文件协议](docs/MCP-CONTRACT.md)。修改协议时同时更新 Swift 与 Node 校验、样例和测试。外部 AI 只能提出草案，不能直接写入完成记录或成就。

## English

Version 1.4 closes this round of the DayVault experiment. Fixes for data handling,
accessibility and compatibility are welcome. There are no plans for a social
platform, hosted AI service or new payment system. For a larger change, open an
issue with the use case before spending time on an implementation.

Read the [development guide](docs/DEVELOPMENT.en.md) first. Describe the problem,
your change and how you tested it. Include tests for behavior changes and Chinese
screenshots for UI changes. Use fictional data in screenshots and MCP fixtures.
Never commit keys, personal records, signing files or Xcode user settings.

The Xcode project is generated from `project.yml`. After changing targets,
versions or file groups, run `xcodegen generate` and commit the generated changes.
Do not reset a SwiftData store to make a migration pass.

The [file contract](docs/MCP-CONTRACT.md) defines the MCP boundary. Protocol
changes need matching Swift and Node validation, examples and tests. External AI
can propose a schedule; it cannot write completion history or grant achievements.

## Checks

```bash
swift test --package-path Packages/DayVaultCore
npm --prefix MCP ci --ignore-scripts
npm --prefix MCP test
git diff --check
```

Run the DayVault scheme's App and UI tests in Xcode on an iPhone simulator as well.
These checks do not replace testing on a device, purchase sandbox testing or
CloudKit production validation.
