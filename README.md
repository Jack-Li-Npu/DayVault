# DayVault

记录每天做了什么，回头看看自己坚持了多久。

**简体中文** · [English](README.en.md)

[使用说明](#第一次使用) · [本地运行](#本地运行) · [开发文档](docs/DEVELOPMENT.zh-CN.md)

![DayVault 品牌插画](Design/Previews/dayvault-readme-banner.svg)

DayVault 是一个中文 iPhone 日常记录器。首页是一张清单，可以记下训练、阅读，或今天想做的一件小事。完成记录会累积成就，也能解锁角色的穿搭。

做这个项目的起因，是坚持一件事很久之后想把成果拿出来看看，也想有人知道这段时间做过什么。成就册和可以回看的角色演出，记录的是你实际完成过的事项。

当前开发版已停止提供 AI 排程、聊天、新个人成就生成和自动改期建议，不发起模型请求。记录、已有成就判定和角色动画可离线使用；iCloud、Calendar 和购买相关功能仍按各自设置工作。旧版本中保存的目标、记录和个人成就保留。

项目尚未上架 App Store。本次范围调整尚未发布新标签，下面的版本链接保留原有发布内容。

## 版本记录

- [v1.3.0](docs/releases/v1.3.0.md)（最新已发布版本） · 个人成就文案修订 · [发布页](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.3.0)
- [v1.2.0](docs/releases/v1.2.0.md) · 界面命名与成就文案 · [发布页](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.2.0)
- [v1.1.0](docs/releases/v1.1.0.md) · 排程指令、连接修复与私人配置 · [发布页](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.1.0)
- [v1.0.0](https://github.com/Jack-Li-Npu/DayVault/blob/v1.0.0/README.md) · 原版存档 · [发布页](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.0.0)

[查看全部发布版本](https://github.com/Jack-Li-Npu/DayVault/releases)

## 看看界面

<table>
  <tr>
    <td align="center"><strong>今日清单</strong><br/>按顺序看安排，不被小时刻度淹没</td>
    <td align="center"><strong>轻量新增</strong><br/>标题和日期先行，复杂选项收起来</td>
    <td align="center"><strong>双人片段</strong><br/>把积累变成可以回看的小演出</td>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/journey-today.png" width="260" alt="今日页面的四件演示事项、用户角色、折纸搭档与新增入口" /></td>
    <td align="center"><img src="Design/Previews/journey-editor.png" width="260" alt="新增页面默认只有标题、日期、折叠的更多设置与保存按钮" /></td>
    <td align="center"><img src="Design/Previews/journey-duet.png" width="260" alt="真实模拟器中的双人演出回看界面，提供继续今天和再看一次按钮" /></td>
  </tr>
</table>

这些是之前版本的真实模拟器截图，使用隔离的示例数据，保留作设计参考。旧图中的 AI 或聊天入口不代表当前功能；本次调整后的界面截图尚未更新。页首横幅是品牌插画，折纸搭档是本地动画角色。

## 先把今天记下来

只填标题就能保存，日期默认是今天。时刻、重复、提醒和模板放在“高级选项”里；日历、统计、外观及设置保留在二级入口。没有问卷或强制聊天。

事项可以只指定日期，也可以指定时刻，或先放进“待安排”。没有时刻的事项不会变成凌晨零点的预约，也不计入计划分钟或准时率。完成时可以直接勾选，需要实际用时再点“开始”。计划与实际时间分别保存。

重复安排、单次改期、日终回顾、Apple Calendar 叠加、提醒和小组件都在。拒绝 Calendar 和通知权限不会妨碍基本记录。

## 成就与角色

公共目录有 24 项成就，其中 8 项隐藏。明确成就显示进度，隐藏项解锁前只给信号与线索。六件角色装备与公共成就对应。“公共”指共用目录，你的记录不会因此公开。

旧版本已经生成并保存的个人成就仍按原规则在本地计算：完成次数、不同完成日期，或已确认节奏下的达标周期。规则和已获资格保留，个人成就不影响公共装备资格。本次不再生成新的个人成就。

旧记录需要你确认关联目标才会计入。已获得的成就保留；后来更正记录时，详情会说明依据的变化。

个人成就的主标题沿用 v1.3 的规则里程碑，例如“首次完成”“累计记录 7 天”。卡片、详情和分享卡使用相同名称，条件区分次数、天数与达标周期。历史生成文案仍属于原记录，不代表当前在调用 AI；隐藏成就解锁前不显示相关内容。

<table>
  <tr>
    <td align="center"><strong>角色与成就入口</strong></td>
    <td align="center"><strong>已获装备与试穿</strong></td>
    <td align="center"><strong>二级日历页面</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/readme-vault.png" width="260" alt="旧版 DayVault 深色 Vault 角色展示与成就入口" /></td>
    <td align="center"><img src="Design/Previews/avatar-wardrobe.png" width="260" alt="原创角色衣橱，区分已解锁装备与未解锁试穿，隐藏装备保持问号" /></td>
    <td align="center"><img src="Design/Previews/readme-calendar.png" width="260" alt="旧版日历页的月视图与顺序事项，使用内存示例数据" /></td>
  </tr>
</table>

这些也来自保留功能的旧版截图；衣橱来自更早的角色预览，全部使用示例数据。

折纸搭档与用户角色一起出场，动作由本地记录驱动，不需要模型回复。既有角色、穿搭和演出保留；演出约六秒，可以跳过或回看，回看不加进度。普通完成只给短反馈，多项解锁合并提示，并支持“减弱动态效果”。

成就可以做成分享卡，包含角色、记录跨度和你选择的一段已确认回忆。先预览，再选发到哪里。私人留言默认不包含，图片在设备上生成，不自动上传，也没有虚构的全球排名。

## 本次收紧的范围

本次去掉远端 AI 的使用入口和请求路径，减少个人开发者需要承担的持续服务成本。不会用固定模板冒充 AI 回复，也不会让已有记录依赖服务端继续运行。

已经接受的日程、目标、个人成就和历史内容不因停用 AI 而清空。Pro、iCloud、Calendar 与小组件不在本次移除范围内；它们的上线验收仍需分别完成。本次没有更改售价或发布付费承诺。

目标仍可手动创建，关联已有事项，并设置执行频率与休息日。有旧对话或回忆的目标，可以从详情中的历史陪伴记录入口查看和管理；首页不再展示或生成聊天回应。

仓库保留 AI 指令包、代理代码和[历史联调记录](docs/AI-PLANNER-LIVE-VALIDATION.zh-CN.md)，方便查阅旧版本。开发指南中与模型配置有关的章节也是历史资料，不是当前 App 的使用步骤。上架前的剩余工作见[收尾计划](docs/APP-STORE-LAUNCH-PLAN.zh-CN.md)。

## 第一次使用

1. 点“新增事项”，填标题并保存。无需先建目标或配置服务。
2. 做完后勾选，点左上角人物可以看成就和衣橱。
3. 长期重复的事项可在高级选项中设置重复，也可以手动创建目标来整理相关记录。

## 本地运行

需要 Mac、Xcode 26 或更新版本及 iPhone 模拟器，最低支持 iOS 18。仓库可公开浏览；项目尚未授予开源再分发许可证。

```bash
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

选择 DayVault Scheme 和模拟器，按 ⌘R。不需要启动 AI 代理、填写 API 密钥或重新生成工程。真机需要设置开发团队、Bundle ID、App Group 和 CloudKit 容器；工程配置变更后用 `xcodegen generate` 重新生成。本地 StoreKit 配置只用于测试购买。

[中文开发指南](docs/DEVELOPMENT.zh-CN.md) / [English guide](docs/DEVELOPMENT.en.md)。其中保留的 AI 配置与服务端测试说明仅适用于历史实现。

## 技术与验证

App 使用 SwiftUI、SwiftData / CloudKit、EventKit、WidgetKit、StoreKit 2 和 Swift Charts，iOS 运行时没有第三方包。`DayVaultCore` 保存重复规则、成就和版本化模型；历史 Deno / Supabase 代理不属于当前 App 的运行依赖。

2026-09-10 的完整本地回归记录为 Core 57 项、App 40 项、UI 15 项、服务端 30 项。之后的连接修复通过服务端 46 项、iOS 单元 13 项及 UI 2 项。它们是不同批次，不能相加当作新总数，也不是线上可靠性证明。

2026-09-14 停用 AI 后的最终回归：Core 57/57、App 单元与集成测试 60/60、UI 19/19 通过，无跳过；Release 配置的 iOS 模拟器构建成功。这些结果与上面的历史批次分开记录。UI 首轮遇到多行输入框识别问题，改用稳定标识后已完整复跑通过，未削减保存与删除断言。

Release 模拟器构建不等于签名归档或 App Store 审核通过。上架前仍须验证真机权限、两台设备 CloudKit 同步、购买沙盒，以及真实旧版本升级和断网使用。本次没有把这些项目标为已通过。

## 隐私与参与开发

记录保存在设备和可用的私人 iCloud 数据库中。当前 App 不向模型服务发送记录、目标或聊天请求。停用 AI 不会撤回历史版本曾发送给服务商的数据；历史副本仍受当时服务商的数据政策约束。[隐私说明](PRIVACY.md)

没有广告 SDK、第三方分析、社交动态或排行榜。Pro 入口保留在二级页面，没有新增启动付费墙。近期只验证记录、回看和保存成果的体验，不扩展挑战商城、MCP 或复杂养成系统。

界面使用纸感底色、粗线框和代码绘制角色。设计参考与归属见 [ATTRIBUTIONS.md](ATTRIBUTIONS.md)。行为改动请补测试，截图只用示例数据。仓库尚未授予项目级开源许可证，访问权限不等于重新分发许可。
