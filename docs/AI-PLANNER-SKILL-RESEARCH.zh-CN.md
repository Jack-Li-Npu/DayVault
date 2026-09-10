# “AI 帮我排”：技能调研与 DayVault 专用指令

> Release privacy note / 发布脱敏说明：`api.example.com`, `example-model` and legacy model labels are placeholders, not actual provider settings. 私人接口与模型仅保存在忽略的本地配置中；历史测试结论保留。

调研日期：2026-09-10。目标不是安装一组万能助手，而是让现有 `example-model / medium` 在 DayVault 的有限接口内，把一句模糊目标变成有用的中文日程草案。

交付入口：

- [完整中文 Prompt](../AI/Skills/dayvault-goal-planner/PROMPT.zh-CN.md)：由源文件生成，与初次排程服务端加载的 `plannerInstructions` 完全一致；修改源文件后重新打包，不直接编辑此副本。
- [Skill 入口](../AI/Skills/dayvault-goal-planner/SKILL.md)：版本 `1.1.0`，含用途与权限边界。
- [18 个行为验收场景](../AI/Skills/dayvault-goal-planner/evals/planner-v1.1-cases.jsonl)：用于之后的模型评测，不能把它们的存在当作模型已经通过。

## 1. 找到了什么，取什么，不取什么

先通过 skills.sh 与网络搜索发现项目，再读取 GitHub 原始文件及仓库许可信息。Skills CLI 的发现请求因当前网络限制失败，后续采用公开网页与 GitHub 只读接口；没有全局安装任何第三方 skill、执行其脚本或上传项目代码。

下表是方法适配判断，不是排行榜；星数、安装量和“安全审核通过”不能证明排程质量。

| 技能 / 项目 | 有用的部分 | DayVault 的取舍 | 原始许可与处理 |
| --- | --- | --- | --- |
| [AI Daily Planner](https://github.com/frankjdwu/ai-daily-planner/blob/55fbc191c83efe4790a2506c2e723b630309c18e/daily-planner/SKILL.md) | 将目标拆成跨日成果，重要步骤先占合适时段，检查已有日历并预览后执行 | 借鉴依赖、缓冲和确认；不采用“人人早晨最清醒”、整天时间块或外部日历写入工具 | MIT；核对原始 LICENSE，保留通知 |
| [Oya](https://github.com/foogunlana/skills/blob/82ac5b7ce159fb92bd832aa7015f21bffaea164c/.claude/skills/oya/SKILL.md) | 让每天的事情与周目标相连，区分任务文本和可执行指令 | 作为对照；不采用多步 onboarding、强制复盘、默认跨日搬运未完成任务 | 未找到明确仓库许可；不复制其文本、模板或代码 |
| [PM Career Ladder](https://github.com/borghei/Claude-Skills/blob/ddca910e95580c63a236303fc1534054f0f14d4c/project-management/career/pm-career-ladder/SKILL.md) | 用可观察的工作证据讨论成长，而非自称达到职级 | 作为职业领域参考；DayVault 的职业模块自行编写，只做有限准备活动，不照搬 PM 等级、晋升判定或半年考核表 | 文件声明 MIT + Commons Clause；本轮不复用其提示词或模板 |
| [Tutor](https://github.com/bevibing/tutor-skills/blob/397110c9fefbc6bd5444277686600aec28063c05/skills/tutor/SKILL.md) | 用实际答题发现概念误区，区分完成活动与真正理解 | 借鉴“用小尝试看起点”；不要求安装 Obsidian、每轮强制四道题、建立虚假掌握率 | MIT；核对原始 LICENSE，保留通知 |
| [Study System](https://github.com/SkillMedev/personal-operating-system/blob/6d7714093ee7c4a98d4b5a25defe2b2889d2d417/skills/study-system/SKILL.md) | 可检验的小单元、主动回忆、复习与错误整理 | 改写成日程中的具体练习，不给用户再造闪卡软件，也不声称存在人人通用的遗忘时刻 | MIT；核对原始 LICENSE，保留通知 |
| [Spaced Practice Scheduler](https://github.com/GarethManning/education-agent-skills/blob/6bbbce418f82e11044009c9f3b7373a354de5bd0/skills/memory-learning-science/spaced-practice-scheduler/SKILL.md) | 把复习安排在教学容量中，考虑先修关系及考试时间 | 作为对照；不复制其 prompt、量化记忆断言、教材课表和固定“最优间隔”。运行规则依据上方 MIT 来源与本项目约束重写 | CC BY-SA 4.0；未将其内容混入当前闭源指令包 |
| [Guided Learning / Spiral Learning Method](https://github.com/WSE-research/guided-learning-skill/blob/39108c8bdf3fb7481ad9559e78c3356bc8727c95/PEDAGOGY.md) | 从理解大意到实际使用，复看旧内容，用产出而非“懂了吗”检查理解 | 借鉴分层练习与复看；不引入整套 Obsidian、HTML 交互课件或固定记忆打分体系 | MIT；核对原始 LICENSE，保留通知 |

这里没有声称这些社区项目的方法经过本项目独立科学验证。特别是固定遗忘比例、统一高效时段、单次答题即认定掌握等说法，没有纳入运行指令。

四个 MIT 来源的版权与许可见 [THIRD_PARTY_NOTICES.md](../AI/Skills/dayvault-goal-planner/THIRD_PARTY_NOTICES.md)。通知仅对应参考与适配部分，不改变 DayVault 整个仓库的许可状态。

## 2. 提炼后的可用指令

以下是针对本 App 自行改写的规则，不是原作者的逐字引文；完整运行版以上方 Prompt 为准。

| 要解决的问题 | 提炼为实际指令 |
| --- | --- |
| 用户只有一句想法 | “先提取用户已有信息；只有会改变计划的关键条件缺失时才问，每轮一个问题。普通偏好以可修改假设进入草案。” |
| 看似全面、实际做不了 | “先检查预算、固定事项与休息，再排目标；有空档不代表用户愿意把它全部投入。不能为凑出完整计划偷偷减范围或改期限。” |
| 每天都是‘学习/推进’ | “事项必须包含动作与对象，备注说明做到哪里结束；第一步可以立即开始，先修步骤排在依赖它的动作前面。” |
| 学了不等于会了 | “把复述、独立练习、检查错误和之后的回忆安排在原有预算里；没有真实测评不能编造能力状态。” |
| 职业计划空泛 | “安排可以交付的材料、样例和表达练习；不保证岗位、录用或晋升，不编造招聘信息，也不替用户投递。” |
| 一次漏做就全盘崩掉 | “不自动制造补课债务或降低约定目标；只有受限调整模式可提出改期，仍需用户预览确认。” |
| 用成就感诱导无意义打卡 | “阶段留下能回看的真实产出，但不为刷奖励拆碎任务；里程碑不等于授予成就。” |

专门为 Responses API 保留了明确的操作范围、简短输出约定和前置依赖检查；不要求模型打印长推理，也不增加不存在的工具。[OpenAI 官方 Responses API 指南](https://developers.openai.com/api/docs/guides/latest-model)

字段结构继续由 API 的 `text.format` 提供，语义限制由 App / 服务端核对。Prompt 可以改善选择，不能替代输出校验。[Structured Outputs 官方说明](https://developers.openai.com/api/docs/guides/structured-outputs)

## 3. 用户实际会感觉到的变化

输入：**“六周后想用英语介绍自己的项目，每天半小时。”**

预期草案应围绕该项目安排首次表达、回听修正、隔日脱稿复述和后期问答，而不是先要求用户填程度问卷，再给六周通用语法课程。每个事项只显示短标题，验收点藏在备注，方法分类对用户不可见。这里描述的是验收目标，不是假装已经收到的模型回复。

输入：**“月底准备三个实习申请，只能周末做。”**

预期步骤包括用户选岗位、整理真实经历、小案例和材料核对；不编造三家正在招聘的公司，也不把“拿到 offer”作为可保证的计划交付物。

输入：**“我想让自己变好。”**

只澄清最想推进的方向，不立刻接管健身、饮食、学习、工作与情绪。

## 4. 如何真的被模型读取

```text
SKILL.md
  + scheduling-policy.md
  + domain-playbooks.md
  + planner-contract.md
        ↓ Scripts/bundle-ai-skill.mjs
dayvault-goal-planner.bundle.ts → generate-plan → Responses instructions
        └ AI/Skills/dayvault-goal-planner/PROMPT.zh-CN.md（完全相同的可读副本）
```

- 新增的参考文件显式进入构建清单；不是只把 Markdown 放到目录中。
- 调整模式仍只拼接共用入口和它自己的 `adjustment-policy.md`，不加载初次排程的默认每天 30 分钟等策略。
- Prompt 版本为 `1.1.0`；调整响应的 `skillVersion` 继续服从已冻结的 `1.0.0` schema。不得为了匹配新提示版本而放宽解码或绕过校验。
- 研究清单、原始第三方 skills、许可文本与测试场景不会加入运行时 Prompt。
- 构建不会调用模型。正在运行的旧代理不会自动热加载新包；之后重新启动本地代理才会加载这些指令。没有部署远端服务。

## 5. 必须说明的接口限制

本轮只改提示词、打包及其测试，不迁移 Swift 数据结构，不增添输入表单。

1. AI 新计划目前要求具体时刻和至少 15 分钟；普通记录器支持日期事项，不代表 AI 输出也支持。遇到用户明确反对时，Prompt 必须说明限制，不能偷偷放到零点或拉长时间。
2. 重复模式没有独立开始日期，当前保存路径可能与初始事项重叠。所以新 Prompt 暂不返回重复模式；长期阶段与里程碑保留，前 14 天具体排入草案。这不删除 App 本身的重复日程功能。
3. 初始结构要求 2–5 个阶段。简单事项只用两个轻阶段，不因此制造更多实际任务；若以后希望单阶段，需要单独协调 schema 与 Swift 校验器。
4. 目标初次排程没有知识状态或长期记忆输入，本轮没有新增“AI 已经了解你”的虚构人格/能力档案。
5. 本调研完成时未进行真实联调。随后在用户授权下，初次排程的结构与传输修复已通过合成请求验证；仍存在中转波动，调整接口未重新验收。参见 [独立的真实链路记录](AI-PLANNER-LIVE-VALIDATION.zh-CN.md)，不要把提示词改动本身当作联调成功。

## 6. 怎样验证，不自欺欺人

本轮执行离线校验：源文件到运行 bundle 的完整性、初始 schema 不变、调整策略隔离、响应版本保持、18 个场景数据格式，以及原有服务端契约测试。**这些测试不能证明模型的计划质量。**

结果：36 项服务端与打包测试通过，TypeScript 类型检查、脚本语法检查、格式检查通过。改动文件中的 88 个本地 Markdown 链接均有效，未发现密钥形态文本。标准技能验证脚本因缺少 PyYAML 无法执行，改用已有 Ruby Psych 检查 YAML 元数据；没有安装全局依赖。

之后在明确允许发送指令到第三方中转的前提下，用 18 个合成场景比较旧版和 `1.1.0`：相同模型、相同 `medium`、同一输入，每例至少三次，保留全部结果而非只挑好样例。

人工与程序分别检查：

- 硬门槛：输出可解析、时间与预算不越界、无冲突、没有伪造来源/能力/写入，无隐藏条件泄露。任何一项失败都不算通过。
- 实用性：第一步能否开始、动作能否验收、领域方法是否合适、是否真的少问问题、没有暗中改目标。
- 体验：标题是否简短、解释是否足够而不过多，复杂选项是否仍留在幕后。

本轮没有使用密钥、调用收费模型或把真实记录发送出去，没有声称通过了线上行为评测，也没有推送 GitHub。
