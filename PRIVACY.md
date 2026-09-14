# DayVault 隐私说明 / Privacy summary

更新：2026-09-14。本说明对应 v1.4 源码发布：App 内远端 AI 已停用，可选 MCP 使用用户主动传递的文件。它尚不是已经提交 App Store 的最终隐私政策。正式发布前仍需补齐可访问的政策与支持页面、有效联系方式，并核对提交构建的隐私申报。

Updated September 14, 2026. This summary covers the v1.4 source release: remote AI is disabled in the app, and optional MCP access uses files transferred by the user. It does not mean the app has been submitted to the App Store. Accessible policy and support pages, contact details and final privacy declarations still need release preparation.

## 记录与同步 / Records and sync

日程、完成记录、模板、分类、回顾、目标及成就保存在设备上，并在可用时使用用户的私人 iCloud 数据库。基本记录不需要 DayVault 账号或自建服务端。已有目标、个人成就定义与依据、历史陪伴消息、记忆及改期记录不会因停用 AI 而清空，继续采用相同的存储方式。

Schedule items, completion records, templates, categories, reviews, goals and achievements are stored on the device and, when available, in the user's private iCloud database. Basic recording does not require a DayVault account or custom backend. Existing personal achievement definitions and evidence, historical companion messages, memories and adjustment records remain within the same storage boundary. Disabling AI does not erase them.

## 不再发送模型请求 / No new model requests

当前 App 不提供 AI 排程、聊天、个人成就生成或 AI 改期建议，也不在完成事项、解锁成就或重新启动时请求模型回复。原有目标级 AI 授权不再触发远端请求。已有个人成就由程序按保存的规则在本地计算；角色与折纸搭档是本地动画，不代表模型正在回应。

The current app does not offer AI scheduling, chat, personal achievement generation or AI adjustment proposals. Completing an item, unlocking an achievement or relaunching does not request a model reply. Previous goal-level AI consent no longer activates remote requests. Existing personal achievements are evaluated locally using their saved rules. Character and origami animations are local visuals, not model responses.

旧版已保存的对话和回忆可以在相应目标的历史陪伴记录中查看和管理。记录来源被纠正或移除时，相关历史文字与回忆仍需遵守原有的依据校验。本次不会创建新的 AI 回忆。

Previously saved conversations and memories can be reviewed and managed through the goal's historical companion records. Existing evidence checks still apply when a source record is corrected or removed. No new AI memories are created.

停用 AI 不会撤回或自动删除旧版本曾发送给服务商的数据。历史副本的保留、删除及其他处理取决于当时服务商的政策。仓库中的模型指令包、代理及联调文档作为历史实现保留，不是当前 App 的运行依赖；本说明不承诺这些服务商已经删除历史数据。

Disabling AI does not withdraw or automatically delete data that earlier versions sent to a provider. Retention, deletion and other handling of historical copies depend on that provider's applicable policy. Instruction packages, proxy code and integration notes remain as historical implementation material, not runtime dependencies of the current app. This summary does not claim that providers have deleted previously received data.

## 可选 MCP 文件交换 / Optional MCP file exchange

用户在设置中选择单个目标、预览导出范围，再主动导出 JSON。快照包含目标名称、身份、时区、已设置的频率与休息日，以及过去 30 天到未来 14 天内相关事项的有限字段。它不包含笔记、聊天、记忆、Calendar 数据、成就定义或隐藏条件；待安排和已移除的事项不导出。目标名称和事项标题仍可能包含私人信息，请在分享前检查。

The user selects one goal in Settings, previews the export range and explicitly exports JSON. The snapshot contains the goal's title, identity, time zone, configured frequency and rest days, plus limited fields for related items from 30 days ago through 14 days ahead. It excludes notes, chat, memories, Calendar data, achievement definitions and hidden conditions, as well as unscheduled and removed items. Goal and item titles can still contain private information; review them before sharing.

电脑上的 MCP 服务只读取配置的快照文件，并在指定的私人目录中保存计划草案。运行时服务本身不发起网络请求、不接触 iCloud，也不直接修改手机数据库。导回的草案需要在 App 中预览并确认，只能新增有日期的事项。模型没有完成记录、改写成就或购买的权限。

The computer's MCP server reads the configured snapshot and writes proposal files to a designated private directory. During operation, the server makes no network requests, accesses no iCloud database and cannot directly change the phone's store. Imported proposals require app preview and confirmation and can only add date-only items. The model cannot mark records complete, rewrite achievements or make purchases.

外部 MCP 客户端可能把读取的快照、工具结果和用户主动输入的内容发送给其模型提供商。其保留、训练使用、删除和收费规则由用户选择的客户端、账号与服务商决定。DayVault 没有因为提供本地 MCP 就保证外部模型也在本地。连接服务前，请检查外部工具的权限和数据设置。

An external MCP client may send the snapshot, tool results and the user's own messages to its model provider. Retention, training use, deletion and charges depend on the selected client, account and provider. A local DayVault MCP server does not guarantee a local model. Review the external tool's permissions and data settings before connecting.

导出的快照和草案是普通文件，没有额外文件加密；文件传输与备份由用户选择的工具处理。请使用私人目录，不要提交到 Git 或公开问题。删除 App 内来源记录不会自动删除已经导出的文件，关闭 MCP 或删除本地副本也不能撤回外部工具收到的数据。快照不是完整备份，没有实时同步或自动撤回功能。

Snapshots and proposals are ordinary files without additional file encryption. Transfer and backup follow the tools the user selects. Keep them in a private directory, out of Git and public issues. Deleting a source record in the app does not delete exported files; stopping MCP or deleting local copies does not withdraw data already received by another tool. Snapshots are not complete backups and provide no live sync or automatic recall.

## Apple 系统功能 / Apple services

- Calendar 默认关闭，用户启用后才请求访问权限。所选日历用于只读叠加显示；导出通过 Apple 系统编辑器创建独立事件。
- 保存带提醒的事项时才请求通知权限。待发送的本地通知由 iOS 管理。
- 小组件使用 App Group 中的最小日程快照；发布前仍需验收锁屏内容的隐私表现。
- 购买及恢复购买由 Apple StoreKit 处理，已验证的 Pro 权益缓存在本地。本次未移除 Pro 或更改售价。

Calendar access is off by default and requested only when the user enables it. Selected calendars provide read-only overlays; export creates an independent event through Apple's system editor. Notification permission is requested when saving an item with a reminder, and iOS manages pending local notifications. Widgets use a minimal App Group schedule snapshot; lock-screen privacy still needs release validation. Apple StoreKit handles purchases and restores, with verified Pro entitlement cached locally. This change does not remove Pro or change its pricing.

“不调用模型”不等于“整个 App 不联网”。iCloud 同步、Calendar 所连接的日历账号及 StoreKit 可涉及 Apple 或相应账号服务，依用户的系统与应用设置运行。

No model requests does not mean the entire app is network-free. iCloud sync, connected Calendar accounts and StoreKit may involve Apple or the relevant account service, according to the user's system and app settings.

## 分享与统计 / Sharing and analytics

成果卡在设备上生成，先由用户预览，再通过系统分享面板选择发送位置。App 不自动上传或公开发布成果卡；分享后的处理取决于用户选择的目的地。私人留言默认不包含在卡片中。

Share cards are rendered on the device and previewed before the user chooses a destination in the system share sheet. DayVault does not automatically upload or publicly post them. Handling after sharing depends on the chosen destination. Private messages are excluded by default.

DayVault 没有广告 SDK、第三方分析、跨应用追踪、数据交易或社交信息流。

DayVault includes no advertising SDK, third-party analytics, cross-app tracking, data brokerage or social feed.
