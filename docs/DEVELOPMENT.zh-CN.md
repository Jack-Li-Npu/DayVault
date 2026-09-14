# DayVault 开发指南

> 当前范围（2026-09-14）：App 已停用远端 AI，不需要代理或 API 密钥。下文 AI 配置、接口与联调说明保留作历史实现参考，不能仅靠环境变量重新启用；恢复功能需要修改代码并重新验收。已有目标、记录和个人成就保留，iCloud、Calendar 与 StoreKit 不受本次范围调整影响。

> Release privacy note / 发布脱敏说明：`api.example.com`, `example-model` and legacy model labels are placeholders, not actual provider settings. 私人接口与模型仅保存在忽略的本地配置中；历史测试结论保留。

[English](DEVELOPMENT.en.md) · [项目介绍](../README.md) · [隐私说明](../PRIVACY.md)

本文说明如何运行项目、配置服务、理解数据边界并验证改动。DayVault 当前是原生 iPhone 原型，不是已部署完毕的商业 AI 服务。首版 App 使用简体中文；英文资源仍在仓库中，但未打包进首版 App 和小组件。提供英文文档不代表 App 已发布英文版本。

## 1. 不接 AI，先运行 App

### 环境要求

- Mac、Xcode 26 或更新版本、Swift 6 工具链，以及已安装的 iPhone 模拟器。上次验证环境为 Xcode 26.2、iOS 26.2 Simulator；项目最低支持 iOS 18。
- Git 和仓库访问权限。私有仓库需要获授权的 GitHub 账号；遇到 `404` 时，也应检查账号权限。
- 直接打开仓库中的 Xcode 工程不需要 XcodeGen；修改工程结构或构建设置后重新生成工程时才需要。
- 日常记录、本地成就、角色预览及常规 iOS 构建**不需要** Node.js、Deno 或 AI 代理。这些工具仅用于可选的 AI 开发及服务端契约测试。

```sh
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

选择 **DayVault** scheme 和一个已安装的 iPhone 模拟器，按 **⌘R**。首页是今日清单；点击 **记一件事**，只填标题即可保存，日期默认为今天。不需要 AI 账号、聊天或前置问卷。

模拟器默认使用本地 SwiftData 数据库，也可以执行不签名的命令行构建：

```sh
xcodebuild \
  -project DayVault.xcodeproj \
  -scheme DayVault \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/DayVault-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

该命令只构建 App，运行仍可通过 Xcode 完成。它不验证 CloudKit 或真机签名。

### 何时重新生成工程

[project.yml](../project.yml) 是已提交 Xcode 工程的生成来源。新增文件、修改 target、Bundle ID、能力或构建设置后，需要重新生成。只在 Xcode 内修改的设置可能被重新生成覆盖。

```sh
brew install xcodegen
xcodegen generate
```

已安装 XcodeGen 时无需执行第一行；这些操作不会给 App 添加第三方运行时依赖。

### 隔离界面预览

在 **Product → Scheme → Edit Scheme → Run → Arguments** 中，为 Debug 构建加入以下启动参数。使用样例数据时务必同时添加 `-inMemoryStore`；仅使用样例数据参数本身不会隔离数据库。

| 预览内容 | 启动参数 |
| --- | --- |
| 空白今日清单 | `-inMemoryStore` |
| 有样例事项的今日清单 | `-inMemoryStore -preview-sample-data` |
| 精简新增页面 | `-inMemoryStore -preview-editor` |
| 角色工作室 | `-inMemoryStore -preview-screen vault` |
| 有样例历史的角色工作室 | `-inMemoryStore -preview-screen vault -preview-sample-data` |
| 大字体 / 角色减弱动态效果 | 在隔离预览参数后追加 `-preview-accessibility` |

内存模式不会读写用户正常的日程数据库或已保存穿搭。无障碍预览使用 Accessibility 3 字号及角色减弱动态效果路径，不修改系统偏好，也不能代替完整无障碍验收。移除预览参数即可恢复正常持久化记录。

点击首页上方的小人物进入 Vault。**我的衣橱**可以试穿，**看看解锁演出**是明确标注的非修改性预览。完成一项真实事项可获得**启程护腕**。旁边的折纸搭档打开当前目标的可选 AI 区域。双人演出的回看和跳过不会增加共同记录天数或成就进度。UI 测试截图保存在 `.xcresult` 附件中；整理过的预览位于 [Design/Previews](../Design/Previews)。

## 2. 真机签名、Apple 服务与本地购买

运行到真实 iPhone 时，在 **DayVault** 和 **DayVaultWidgets** 两个 target 的 Signing & Capabilities 中选择你的 Apple Developer 团队。以下标识需要归属你的团队，或在相应位置一致替换：

| 项目 | 当前标识 | 需要修改的位置 |
| --- | --- | --- |
| App Bundle ID | `com.dayvault.app` | [project.yml](../project.yml) |
| Widget Bundle ID | `com.dayvault.app.widgets` | [project.yml](../project.yml) |
| App Group | `group.com.dayvault.shared` | 两个 target 的 entitlement 文件，以及 [WidgetSnapshot.swift](../Packages/DayVaultCore/Sources/DayVaultCore/WidgetSnapshot.swift) |
| 私有 CloudKit container | `iCloud.com.dayvault.app` | [App entitlements](../DayVault/DayVault.entitlements) 和 [PersistenceController.swift](../DayVault/PersistenceController.swift) |
| Pro 永久购买产品 | `com.dayvault.app.pro.lifetime` | [EntitlementStore.swift](../DayVault/Services/EntitlementStore.swift)、[DayVault.storekit](../Config/DayVault.storekit) 及 App Store Connect |

在开发者账号中创建匹配的 App Group 和 iCloud container。本地记录不要求 CloudKit 可用。无签名模拟器没有所需 entitlement，因此默认禁用 CloudKit；只有专门进行已签名 CloudKit 联调时，才加入 `-enableCloudKitInSimulator`。真机会尝试私有 CloudKit，在创建容器失败时回退到本地数据库；这并不代表所有后续同步故障都已验证。

DayVault scheme 已选择 [Config/DayVault.storekit](../Config/DayVault.storekit)，其中包含一个支持家庭共享的非消耗型产品，本地测试价格为 `14.99`。代码使用 StoreKit 2 处理交易验证、恢复购买、交易监听和离线权益缓存。该文件不会自动创建 App Store Connect 产品，也不会设定线上价格。发布前还需配置真实产品、本地化价格、Family Sharing、审核截图和描述，并完成购买沙盒测试。

Calendar 和提醒均为主动开启。所选 Calendar 事件作为只读忙碌区域显示；导出通过系统编辑器创建独立副本，不承诺双向同步。小组件仅使用 App Group 中的精简 JSON 快照；其完成操作记录待处理的 occurrence ID 并打开 App，再通过同一条持久化与成就路径执行修改。

## 3. 配置可选 AI

### 区分本地演示与真实 AI

原目标排程页面在未配置远端服务时，提供**明确标注的确定性本地预览**，可体验计划预览流程，不需要密钥。它不是模型生成的建议。

个人成就设计、搭档轻对话和未来七天调整提案需要可用的远端接口。未配置或调用失败时会显示不可用 / 错误状态，不用固定回复冒充 AI。断网时，本地记录、已有成就判定和动画仍然可用。

### 服务边界

iOS App 调用服务端代理，不能持有上游模型密钥。现有 [generate-plan 函数](../supabase/functions/generate-plan/index.ts) 同时接收原排程请求和三种类型明确的 Journey 操作：

| 操作 | 版本化指令包 | 允许返回的内容 |
| --- | --- | --- |
| 初次排程 | `dayvault-goal-planner` | 澄清问题或可预览的日程计划 |
| `designAchievements` | `dayvault-achievement-designer` | 最多两项明确成就及一项隐藏成就，仅使用允许的次数 / 日期 / 周期规则和徽章组件 |
| `companionReply` | `dayvault-companion` | 简短中文回应、可校验的来源 ID，以及可选的未确认记忆提案 |
| `suggestAdjustment` | `dayvault-goal-planner` 受限调整模式 | 已知 occurrence ID 与授权时间范围内的新开始值 |

原始指令、规则、输出结构和中文测试样例位于 [AI/Skills](../AI/Skills)。它们通过生成的 TypeScript 包实际导入服务端函数，不是放在仓库里但没有加载的 Markdown。修改指令或结构后执行：

```sh
node Scripts/bundle-ai-skill.mjs
```

脚本重新生成 `supabase/functions/_shared` 下的 `dayvault-goal-planner.bundle.ts` 和 `dayvault-journey.bundle.ts`。请保持源文件和生成包一致。模型输出始终是不可信提案：服务端与 App 都会拒绝未知引用、不支持的规则、多余字段和越界范围。模型不能直接写入进度、解锁日期、装备资格或可执行代码。

“AI 帮我排”当前指令为 `1.1.1`，陪伴与成就设计为 `1.0.1`。构建包含排程规则、领域方法和接口约定，并将 [DayVault 文案规则](../AI/Editorial/voice.md) 加入全部四种操作。可直接查看 [完整中文 Prompt](../AI/Skills/dayvault-goal-planner/PROMPT.zh-CN.md)。输出结构没有因文案改写而改变。技能来源与改写范围见 [文案维护](WRITING.md)，领域方法与待评测场景见 [排程调研](AI-PLANNER-SKILL-RESEARCH.zh-CN.md)。之前版本的真实调用及失败记录见 [链路验收](AI-PLANNER-LIVE-VALIDATION.zh-CN.md)；本次文案修订没有重新调用付费模型。

### 本地 macOS 中转测试

现有本地测试脚本明确配置为：

先在项目根目录创建 `.env.local`（已被 Git 忽略），填写下列变量的实际值；密钥继续通过钥匙串配置。下面的接口与模型是占位符，不能直接用于调用。

- 上游 Base URL：`https://api.example.com`
- 模型：`example-model`
- 思考强度：`medium`
- iOS 开发接口：`http://127.0.0.1:8000`（旧的本地 8000 端口地址会自动归一到 IPv4，避免 `::1` 拒绝连接）

若提示“模型中转服务超时”，说明本地代理已经响应，无需重启本地代理；这与“未能连接本地排程代理”不同。等待代理响应超时则不能判断模型是否已完成。错误详情只包含固定类型和状态码，不包含请求正文或密钥。

**本轮兼容性结果，2026-09-10（Asia/Shanghai）：**用户授权继续联调后，初次排程修复了结构兼容性与等待链路问题。“6周后上台演讲”经真实代理返回 HTTP 200，响应指令版本为 `1.1.0`，该次耗时约 81 秒。此前基础连接、搭档与个人成就也曾通过合成测试；七天调整的 `502 / invalid_structured_output` 尚未重新验收。详见 [完整测试范围与限制](AI-PLANNER-LIVE-VALIDATION.zh-CN.md)。

这些测试只使用虚构目标，未发送真实个人记录，也未向 App 保存结果；不等于生产上线或稳定性验收。`example-model` 的 Responses API 与 `medium` 参数可参考 [OpenAI 官方模型文档](https://developers.openai.com/api/docs/models)，实际第三方中转兼容性以联调结果为准。本轮通过 45 项服务端测试、8 项 iOS 单元测试及 2 项 iOS UI 测试；下文 142 项是此前完整回归的历史记录。

本地测试需安装 Deno，并确保 `deno`、`rg` 和 Xcode 的 `xcrun` 可从 `PATH` 调用。重新打包指令还需要 Node.js。可以先检查工具，不要打印含密钥的整个环境：

```sh
command -v deno
command -v node
command -v rg
xcrun --find simctl
```

启动一个 iPhone 模拟器，然后在仓库根目录运行：

```sh
./Scripts/configure-local-ai.sh
./Scripts/run-local-ai-test.sh
```

第一条命令安全提示输入模型密钥，保存到 macOS 钥匙串的 service `com.dayvault.local-ai`、account `dayvault-local`；已经配置过就不必再运行。不要把密钥写入命令示例、`.xcconfig`、截图或提交记录。第二条命令重新打包指令，将密钥读入宿主进程环境，把 Deno 代理绑定到 `127.0.0.1:8000`，并在模拟器保存不含密钥的连接地址。保持终端开启，再从 Xcode 重新启动 App。**代理启动成功不代表模型可用；实际操作远端 AI 可能发送数据并产生调用费用。**

按 **Control-C** 停止。脚本清理临时环境变量，但保留 App 的连接地址；此时再次请求 AI 会显示连接错误，不会变成演示。要主动恢复本地演示，停止代理后移除两个非秘密配置项，再重启 App：

```sh
xcrun simctl spawn booted launchctl unsetenv DAYVAULT_AI_ENDPOINT
xcrun simctl spawn booted defaults delete com.dayvault.app aiPlannerEndpoint
```

若 App 仍连接旧地址，还应检查 Xcode Run 的环境变量覆盖。Debug Journey 客户端允许回环 HTTP，正常远端配置要求 HTTPS。未认证预览模式仅用于此类回环开发，不应把它作为公网生产服务运行。

### 部署服务端接口

部署现有 Supabase Edge Function，并按 [supabase/.env.example](../supabase/.env.example) 设置服务端 secrets。示例只有占位符，不含可用密钥。当前代码默认值、示例与本地脚本均选择第三方中转 `https://api.example.com` 和 `example-model`；服务端环境变量可覆盖默认值，已有部署需单独更新其 secrets。不要为了掩盖兼容性错误而静默切换模型或服务商。本轮只更新本地配置，未部署远端服务。

开发时，在 Xcode scheme 环境变量中配置：

```text
DAYVAULT_AI_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-plan
DAYVAULT_SUPABASE_KEY=YOUR_PUBLISHABLE_KEY
DAYVAULT_SUPABASE_ACCESS_TOKEN=THE_SIGNED_IN_USER_ACCESS_TOKEN
```

`OPENAI_API_KEY`、`OPENAI_BASE_URL`、`DAYVAULT_OPENAI_MODEL` 和 `DAYVAULT_OPENAI_REASONING_EFFORT` 只放在服务端。需要认证的部署应保持 `DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW=false`。函数会使用服务端的 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`，通过 Supabase Auth 验证 bearer token。[supabase/config.toml](../supabase/config.toml) 关闭的是网关内置 JWT 校验，认证由函数自行执行；不能把这个设置误认为生产环境允许绕过登录。

仓库**尚未提供**完整的生产登录界面、token 自动刷新集成、已部署服务、按用户限额或防滥用系统。在开放收费模型调用前，需要补齐并验证这些环节。挑战数据库迁移只提供计划模板和热度视图，并不证明存在真实参与人数或排行榜；缺少数据时不能填造热门比例。

## 4. 数据与架构

```text
DayVault/
  Features/                 SwiftUI 今日、编辑器、Vault、角色、搭档、设置
  Services/                 Calendar、通知、StoreKit、排程及 Journey 适配器
  AppModel.swift            记录、单次事项修改、公共成就
  AppModelJourney.swift     目标、个人成就、有来源的陪伴
  AppModelAdjustments.swift 调整预览、安全执行与撤销
  PersistenceController.swift
DayVaultWidgets/            WidgetKit 和 App Intent 界面
Packages/DayVaultCore/      模型、迁移、重复规则、成就规则、校验、快照
AI/Skills/                 版本化指令、结构定义和行为样例
supabase/                  可选模型代理、校验器及挑战种子迁移
Scripts/                   指令打包、本地代理、可复现 App 图标
Design/                    设计参考、预览及验收方案
DayVaultTests/              App 与 Journey 集成测试
DayVaultUITests/            模拟器交互与无障碍路径测试
```

核心包不依赖 UI。iOS targets 使用 SwiftUI、SwiftData、CloudKit、EventKit、UserNotifications、WidgetKit / App Intents、StoreKit 2 和 Swift Charts，没有第三方 iOS 运行时包。角色图层、折纸搭档、成就徽章和界面动画由代码实现；App 图标可以通过 [generate-editorial-app-icons.swift](../Scripts/generate-editorial-app-icons.swift) 重新生成。

### 修改时必须保留的约束

- **迁移而不是重置。** [FrozenSchemaV1.swift](../Packages/DayVaultCore/Sources/DayVaultCore/FrozenSchemaV1.swift) 冻结真实旧版本结构；[DayVaultSchema.swift](../Packages/DayVaultCore/Sources/DayVaultCore/DayVaultSchema.swift) 定义 V2 和迁移。保留旧 ID、重复规则、实际时间、成就和穿搭资格，不通过删除数据库来“修复”升级。
- **只保存需要的单次记录。** 保存重复事项定义，仅在某次发生变化时建立日志。稳定 occurrence 身份保留原始时间点和时区标识。使用 UUID 外键而非必选关系；CloudKit 重复记录在应用层去重，不依赖唯一约束。
- **时间精度有实际含义。** 仅日期、具体时刻和待安排是不同状态。仅日期事项不会变成隐含的零点预约，不计入准时率、定时冲突和计划分钟统计。
- **目标身份不会在排程后丢失。** `PersonalGoal` 保存已接受计划及节奏。事项和完成日志关联稳定 goal ID；历史关联由用户确认。已完成记录保留当时归属，不通过标题相同来猜测目标。
- **个人规则启用后冻结。** `PersonalAchievementDefinition` 使用独立命名空间及版本化的累计次数、不同完成日期或达标周期规则。有明确节奏时，周期是固定七天，不是会清零过去周期的连续打卡。一批最多两项明确成就、一项隐藏成就。本地计算去重并排除未来记录；已获得资格在修改记录后仍保留。解锁依据保留规则和来源版本，依据变化会如实展示，不重写历史。
- **公共与个人分开统计。** 保留 24 项公共成就及其六件装备关联。个人成就不授予公共装备，也不改变公共收集数量。公共解锁合并保留最早有效日期；同步到达的历史解锁不重播完整演出，但不承诺两台同时离线设备绝不会各播一次。
- **共同记录不等于导入多年历史。** 搭档按开启陪伴后实际共同记录的不同日期，在初始、7 天、30 天进入不同阶段。用户确认的旧记录可以支撑个人成就，不能写成搭档一起经历的时间。休息或缺席不降级。
- **记忆必须有依据。** [AppModelJourney.swift](../DayVault/AppModelJourney.swift) 区分事实、用户消息、记忆提案及确认记忆。接受延迟返回的回复及来源变化时检查版本，撤下失效的派生文本和记忆。关闭后重新开启 AI 不能让旧授权会话的回复重新合法。隐藏规则不进入普通轻对话上下文。
- **调整始终是提案。** [AppModelAdjustments.swift](../DayVault/AppModelAdjustments.swift) 仅允许移动当前目标未来七天内未开始的单次事项。执行前重新读取已授权 Calendar 忙碌区间，校验休息、时长、节奏、版本和冲突；确认后批量保存成功，才更新提醒与小组件。重复事项采用单次覆盖。过期提案被拒绝；撤销也检查版本和冲突，不盲目覆盖后来开始或修改的事项。

外观偏好保存在本机。装备资格来自永久成就状态，不来自外观商店或养成经济。分享卡在设备端生成，只包含所选内容；私人回忆默认不加入，也不会自动发布。

## 5. 隐私与安全检查

开启远端 AI 或修改发送内容前，请阅读 [PRIVACY.md](../PRIVACY.md)。日程、目标、成就、依据、消息和记忆使用设备数据库，并在配置可用时进入用户私有 iCloud；这与可选模型服务是两条不同的数据边界。

初次排程可发送目标、澄清内容及安排约束。Journey 请求可发送当前目标选定事项的标题 / 完成日期、近期由用户发送的消息及已确认记忆。调整请求额外携带允许修改事项的时间 / 版本，以及忙闲和休息区间。不会发送 Calendar 标题、参与人、地点和备注，也不会导入所有目标或用户的 Codex 聊天记录。

模型服务商在设计隐藏成就时会看到规则，但后续搭档对话不包含这些隐藏内容。上游 Responses 请求设置 `store: false`，这不等于第三方中转承诺不记录、不保留或不训练。删除本地记录也不代表删除服务商已经处理过的副本。

不要提交密钥、认证 token、本地 `.env`、签名材料、数据库、日志、构建产物或 `.xcresult`。仓库的 [ignore 规则](../.gitignore) 排除了常见敏感及运行时文件，但它不是密钥扫描器。发布前仍需检查 diff 和截图内容。iOS App 没有广告 SDK、第三方分析或跨 App 跟踪包。

## 6. 验证

在仓库根目录运行 macOS 核心测试：

```sh
swift test --package-path Packages/DayVaultCore
```

对已安装的模拟器执行 App 和 UI 测试。如果没有 `iPhone 17 Pro`，将名称替换为本机已有设备：

```sh
xcodebuild \
  -project DayVault.xcodeproj \
  -scheme DayVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

重新生成指令包并执行确定性的后端校验，不会调用模型：

```sh
node Scripts/bundle-ai-skill.mjs
deno check supabase/functions/generate-plan/index.ts
deno test --allow-read=AI/Skills supabase/functions/_shared/*_test.ts
```

以下是**2026-09-10 已记录的一轮结果**，不是此次文档更新重新运行所得：

| 测试套件 | 已记录结果 | 部分覆盖内容 |
| --- | --- | --- |
| Core | 57 项通过 | 真实 V1 磁盘库迁移、重复 / DST / 闰日、稀疏覆盖、50 项重叠、规则阈值、历史关联和时区 / 周期锚点 |
| App | 40 项通过 | 含 25 项 Journey 集成：完整批次同步、永久解锁、授权变更、删除来源、安全调整、保存失败回滚与重试 |
| UI | 15 项通过 | iPhone 17 Pro / iOS 26.2 上的只填标题、无隐含零点、可选搭档、演出回看 / 跳过、同册分组、大字体和减弱动态效果 |
| Server | 30 项通过 | 含 14 项中文样例，以及不可信输出、伪造引用、配置校验 |

该轮合计 **142 项自动测试通过**。9 项 Swift Journey 校验测试已包含在 Core 中，不能再额外累加。这些结果不是实时 AI 成功、在线 CI 状态或生产就绪证明；Release 构建不包含注入保存失败的测试开关。

## 7. 尚未完成的发布验收

- 通过实际中转重新验证指定模型，再将陪伴生成标为上线。本地契约测试不能证明模型质量或服务商兼容性。
- 签名真机验证 Calendar 授权变更 / 撤销、通知、小组件和锁屏隐私。
- 验证两台真机分别离线创建 / 编辑后通过 CloudKit 汇合，部署并确认生产 schema；不能由本地迁移测试推断同步已通过。
- 使用真实 App Store Connect 产品验证购买沙盒、取消、pending / 未验证交易、恢复、家庭共享及离线启动。
- 实测 VoiceOver 朗读顺序、中文截断、Dynamic Type、Reduce Motion、对比度、音效 / 触觉关闭，以及真机性能与能耗。
- 制作最终 App Store 截图、预览视频、商店文案与审核材料。仓库中的预览不等于已获审核的商店素材。
- 执行 [Design/Journey-Validation.md](../Design/Journey-Validation.md) 的陪伴价值对比：同样的动画，仅统计与“统计加真实来源回应”之间是否有差异。这是待执行的用户研究，不是已证实的留存或情感收益。

AI、iCloud、Calendar 权限、通知或购买不可用时，日常记录都应继续可用。本轮刻意不新增排行榜、社交动态、挑战商城、心理咨询、MCP 接入或复杂角色经济。
