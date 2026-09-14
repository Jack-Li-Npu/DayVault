# DayVault writing notes / 文案维护

## v1.4 中英文介绍（2026-09-14）

本次重新核对了 [blader/humanizer](https://github.com/blader/humanizer) 和 [op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh)。本地已有可读的英文 `humanizer` 和中文 `humanizer-zh` 技能，因此直接使用，没有重复安装或覆盖原副本。它们用于编辑 README、v1.4 说明、MCP 接入指南和隐私说明，不随 App 运行，也不需要把私人记录发送给写作服务。

最新介绍以当前行为为准：App 离线记录，MCP 交换所选目标文件，外部工具负责模型。删除“全能”“无缝”“彻底改变”等宣传语，保留费用、确认流程、旧截图、测试范围和未完成事项。没有编造用户评价或创作者经历；项目缘由只使用原有记录中明确提到的想法。

产品文案保持简洁正式。导航用名词，按钮写操作，错误说明原因与下一步；成就条件写可核实的次数、日期和范围。自然表达不意味着改成聊天口吻，也不意味着省略隐私限制。

This pass checked the upstream [English Humanizer](https://github.com/blader/humanizer) and [Chinese Humanizer](https://github.com/op7418/Humanizer-zh) projects and used the locally installed skills. They guide editing; they are not app dependencies or a runtime language service.

The v1.4 introductions describe what the software does, with specific limits. The edit removes inflated claims and repeated setup while preserving costs, user confirmation, historical screenshot labels and unfinished checks. No testimonials, author experiences or test results were invented. It makes no promise about AI detector scores or human authorship.

The sections below document earlier releases. Their runtime prompt-bundling notes describe the retired in-app AI implementation, not the v1.4 MCP server. Existing version tags and historical writing examples stay intact.

## v1.2 成就文案（2026-09-13）

公共成就改用与记录行为有关的短名称，描述对应当前判定条件。公开成就的次数、范围和限制直接说明；隐藏项目解锁前仍不公开名称和阈值。角色装备说明与个人安全线索同步调整，既有 ID、资格和装备对应关系不变。

本轮参考 Steam 官方成就列表，而非复制游戏台词或资产。中文编辑技能用于去掉空泛隐喻，界面文案规范用于保留准确动作。[参照来源、改写示例与已知实现缺口](PRODUCT-COMPARISON-2026-09.md)。

`dayvault-achievement-designer` 指令更新到 1.0.2，输出契约保持 1.0.0，重新打包后进入新的成就设计请求。冻结的个人定义不重写。48 项服务端测试验证契约与打包，不代表已验收真实模型文风；本轮没有付费模型调用。

## 当前界面命名规范（2026-09-13）

界面名称采用简洁、明确的产品术语。自然表达不等于聊天口吻：导航和分类使用名词，按钮使用操作名称，表单标题直接说明字段用途。此规范取代下方历史示例中的问句式界面标题。

| 用途 | 统一名称 |
| --- | --- |
| 默认事项分类 | 专注、学习、健康、休息、个人事务；无分类时显示“未分类” |
| 记录入口与表单 | 新增事项、事项名称、计划日期、高级选项 |
| 时间精度 | 仅日期、具体时间、待安排 |
| AI 规划 | 智能排程、目标规划、生成计划、实施阶段、近期安排 |
| 目标与陪伴 | 目标管理、目标对话、记忆管理、调整预览 |
| 成就分组 | 公共成就、个人成就 |
| 角色与分享 | 角色档案、成就装备、分享预览 |

角色台词、已解锁成就名称和隐藏线索可以保留表现力；不得将这类表达用作操作标签。错误提示仍需说明原因和可执行的下一步，隐私授权及 AI 来源提示不得省略。默认分类只改显示名称，保留原有本地化键、分类 ID 和统计分组，不改写历史记录或用户自定义名称。

UI labels use concise product terminology, not conversational questions. Keep expressive dialogue and achievement clues separate from navigation, form labels and actions. This naming pass changes display text only; it does not change stored category IDs, achievement rules or AI prompts.

本次检查：14 项 iOS 单元测试、6 项中文界面测试通过；中英文资源语法与差异检查通过。已在模拟器检查新增事项页面的实际显示效果。未调用远端模型。

2026-09-11：通过 Skills CLI 搜索，安装并阅读了下列上游写作技能。安装目录与原有技能分开，没有覆盖旧技能。

| 用途 | 来源 | 固定提交 |
| --- | --- | --- |
| 英文与文章结构 | [blader/humanizer](https://github.com/blader/humanizer) | `9862685f575c65a8247f90369951df1b3416e3d6` |
| 中文表达 | [op7418/Humanizer-zh](https://github.com/op7418/Humanizer-zh) | `91f3d394db8419c20d67ebe22a96cf8fee0a404b` |

本地安装名为 `humanizer-editor` 和 `humanizer-zh-editor`，不随 App 分发。采用的原则是删去空泛口号、重复铺垫和机械排比，保留事实与作者原意。没有采用“伪造经历”“刻意犯错”或隐藏 AI 来源的方法，也没有做检测器评分承诺。

App 的固定文案在本轮直接修改。模型使用的短版规则在 [AI/Editorial/voice.md](../AI/Editorial/voice.md)，由 `Scripts/bundle-ai-skill.mjs` 加入初次排程、陪伴、成就设计和改期四种运行时指令。它是针对 DayVault 编写的规则，不是把通用编辑技能整份塞进每次请求。输出结构、隐藏成就条件及写入权限不变。

修改文案时先确认页面用途，再读一遍改写后的句子。按钮说清操作，错误说明原因和下一步。AI 回应中出现日期、次数或过往经历，必须有相应来源。不要删除未完成验证、隐私、费用或模型来源的说明。

## Historical examples / 2026-09-11 历史示例

| 位置 | 原文 | 改后 |
| --- | --- | --- |
| 排程页标题 | 你想让什么发生？ | 最近想做什么？ |
| 排程页说明 | 一句话就够了，我来整理前进的路径。 | 写下目标和大概期限，先看看怎么安排。 |
| 等待提示 | 正在为真实生活留出空间… | 还在等待 AI 回复… |
| 成就册 | 每次坚持，都会留下痕迹。 | 看看已经完成了哪些成就。 |
| English planner | One sentence is enough. I’ll shape the path. | Describe your goal and roughly when you want to finish. |

The installed skills guide editing, not claims of human authorship. The shared runtime rules preserve evidence, consent, hidden achievement boundaries and response schemas. Automated checks confirm bundling and UI behavior; they do not establish how natural a model's replies will sound. This revision does not send private records to a writing service or rerun paid model tests.

The second release remains `v1.1.0`. Its GitHub description is updated; the original source tag stays fixed. Revised copy and instructions are in the current branch, with a commit-specific link in the release notes.

## 2026-09-11 检查 / Earlier checks

47 项服务端测试、13 项 iOS 单元测试、3 项中文 UI 测试通过。检查覆盖共享写作规则的实际打包、各操作响应结构不变、AI 来源标识，以及精简编辑器。中英文资源文件语法、README 图片与文件链接和私人配置模式扫描通过。这些检查不等于自然语言质量的用户评测，也没有运行 AI 检测器。
