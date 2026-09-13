# DayVault

记录每天做了什么，回头看看自己坚持了多久。

**简体中文** · [English](README.en.md)

[使用说明](#第一次使用) · [本地运行](#本地运行) · [开发文档](docs/DEVELOPMENT.zh-CN.md)

![DayVault 品牌插画](Design/Previews/dayvault-readme-banner.svg)

DayVault 是一个中文 iPhone 日常记录器。首页是一张清单，可以记下训练、阅读，或今天想做的一件小事。完成记录会累积成就，也能解锁角色的穿搭。

做这个项目的起因，是坚持一件事很久之后想把成果拿出来看看，也想有人知道这段时间做过什么。DayVault 因此有了成就册、可以回看的双人动画，以及一个可选的 AI 搭档。搭档只根据你授权的记录回应；它说起某次经历时，应该能找到对应的记录。

目前是公开仓库中的开发原型，尚未上架 App Store。记录、已有成就和动画可离线使用。真实 AI 排程曾成功返回计划，但最近仍有上游 HTTP 504。[测试记录](docs/AI-PLANNER-LIVE-VALIDATION.zh-CN.md)列出了具体范围。

## 版本记录

- [v1.3.0](docs/releases/v1.3.0.md)（当前版本） · 个人成就文案修订 · [发布页](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.3.0)
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

这些是之前版本的真实模拟器截图，使用隔离的示例数据。本次保留界面，调整部分文字；截图不代表新 AI 联调结果。页首横幅是品牌插画。

## 先把今天记下来

只填标题就能保存，日期默认是今天。时刻、重复、提醒和模板放在“高级选项”里；日历、统计、外观及设置保留在二级入口。没有问卷或强制聊天。

事项可以只指定日期，也可以指定时刻，或先放进“待安排”。没有时刻的事项不会变成凌晨零点的预约，也不计入计划分钟或准时率。完成时可以直接勾选，需要实际用时再点“开始”。计划与实际时间分别保存。

重复安排、单次改期、日终回顾、Apple Calendar 叠加、提醒和小组件都在。拒绝 Calendar 和通知权限不会妨碍基本记录。

## 成就与角色

公共目录有 24 项成就，其中 8 项隐藏。明确成就显示进度，隐藏项解锁前只给信号与线索。六件角色装备与公共成就对应。“公共”指共用目录，你的记录不会因此公开。

开启某个目标的 AI 后，它还能设计最多两项明确成就和一项隐藏成就。程序按完成次数、不同完成日期或已确认节奏下的达标周期计算进度。规则接受后冻结，AI 不能在聊天中降低门槛或直接授奖，个人成就也不影响公共装备资格。

旧记录需要你确认关联目标才会计入。已获得的成就保留；后来更正记录时，详情会说明依据的变化。

v1.3 将个人成就的主标题统一为规则对应的里程碑，例如“首次完成”“累计记录 7 天”。卡片、详情和分享卡使用相同名称，条件区分次数、天数与达标周期。以前生成的成就也会更新显示，无需重新生成；AI 原始文案保留在详情的折叠项中，隐藏成就解锁前不显示。

<table>
  <tr>
    <td align="center"><strong>角色与成就入口</strong></td>
    <td align="center"><strong>已获装备与试穿</strong></td>
    <td align="center"><strong>二级日历页面</strong></td>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/readme-vault.png" width="260" alt="当前 DayVault 深色 Vault 角色展示与成就入口" /></td>
    <td align="center"><img src="Design/Previews/avatar-wardrobe.png" width="260" alt="原创角色衣橱，区分已解锁装备与未解锁试穿，隐藏装备保持问号" /></td>
    <td align="center"><img src="Design/Previews/readme-calendar.png" width="260" alt="当前日历页的月视图与顺序事项，使用内存示例数据" /></td>
  </tr>
</table>

这些也来自保留功能的旧版截图；衣橱来自更早的角色预览，全部使用示例数据。

折纸搭档与用户角色一起出场。开启陪伴后，共同记录达到 7 天、30 天时，双人演出的配合会变化。休息不会降级，导入历史不会冒充共同经历。演出约六秒，可以跳过或回看；回看不加进度。普通完成只给短反馈，多项解锁合并提示，并支持“减弱动态效果”。

成就可以做成分享卡，包含角色、记录跨度和你选择的一段已确认回忆。先预览，再选发到哪里。私人留言默认不包含，图片在设备上生成，不自动上传，也没有虚构的全球排名。

## AI 能帮什么

“智能排程”接受一句目标，比如“两周后做一次英文演讲”。缺少关键条件时先问一个问题，再给实施阶段和近期安排。你看过草稿、确认后才加入日程。内置挑战是计划模板，没有真实赛事报名或参与人数。

点折纸搭档可以聊当前目标。自动回应每天最多一次，重大个人成就可额外回应；主动聊天不受此展示次数限制。AI 提出的长期记忆要经你确认，可以查看依据、修改或删除。来源失效后，相关旧回复与回忆会撤下。

改期建议只涉及当前目标未来七天内尚未开始的事项。先展示前后差异，确认时再检查冲突与当前状态。它不能删任务、缩短时长、延长期限或改整条重复规则，撤销时也会检查后续修改。

文字规则会随构建加入实际请求：任务写清做什么和完成标准，认可要有依据，少用口号。各操作的输出结构及权限检查保留。[文案规则与技能来源](docs/WRITING.md)

## 第一次使用

1. 点“新增事项”，填标题并保存。无需先建目标或开启 AI。
2. 做完后勾选，点左上角人物可以看成就和衣橱。
3. 想长期记录某件事时，再创建目标。需要排程或陪伴时，查看发送范围后开启 AI。

## 本地运行

需要 Mac、Xcode 26 或更新版本及 iPhone 模拟器，最低支持 iOS 18。仓库可公开浏览；项目尚未授予开源再分发许可证。

```bash
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

选择 DayVault Scheme 和模拟器，按 ⌘R。首次运行不必配置 AI 或重新生成工程。真机需要设置开发团队、Bundle ID、App Group 和 CloudKit 容器；工程配置变更后用 `xcodegen generate` 重新生成。本地 StoreKit 配置只用于测试购买。

AI 密钥保存在服务端或本地钥匙串，私人接口与模型设置放在被 Git 忽略的 `.env.local`。文档中的示例地址不能直接调用。[中文开发指南](docs/DEVELOPMENT.zh-CN.md) / [English guide](docs/DEVELOPMENT.en.md)

## 技术与验证

App 使用 SwiftUI、SwiftData / CloudKit、EventKit、WidgetKit、StoreKit 2 和 Swift Charts，iOS 运行时没有第三方包。`DayVaultCore` 保存重复规则、成就和版本化模型；可选 Deno / Supabase 代理调用模型，不能直接修改手机上的记录。

2026-09-10 的完整本地回归记录为 Core 57 项、App 40 项、UI 15 项、服务端 30 项。之后的连接修复通过服务端 46 项、iOS 单元 13 项及 UI 2 项。它们是不同批次，不能相加当作新总数，也不是线上可靠性证明。

最近的真实请求仍有中转 HTTP 504，七天调整未完成真实联调验收。真机权限、两台设备 CloudKit 同步、购买沙盒和[陪伴价值测试](Design/Journey-Validation.md)还需要继续做。本次文案改写没有重新调用付费模型。

## 隐私与参与开发

记录保存在设备和可用的私人 iCloud 数据库中。AI 按目标授权，不默认发送其他目标、全部日记或 Calendar 标题。删除本地内容不等于删除服务商已处理的数据。[隐私说明](PRIVACY.md)

没有广告 SDK、第三方分析、社交动态或排行榜。Pro 入口保留在二级页面，没有新增启动付费墙。近期先验证记录和陪伴的使用体验，不扩展挑战商城、MCP 或复杂养成系统。

界面使用纸感底色、粗线框和代码绘制角色。设计参考与归属见 [ATTRIBUTIONS.md](ATTRIBUTIONS.md)。行为改动请补测试，截图只用示例数据。仓库尚未授予项目级开源许可证，访问权限不等于重新分发许可。
