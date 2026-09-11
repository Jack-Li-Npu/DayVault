# 初次排程接口约定

本文件解释字段语义，不替代宿主通过 Structured Outputs 传入的 JSON Schema（源文件 `references/output-schema.json`）。只使用现有字段；禁止因为某种方法需要数据就自行发明输入或输出字段。

## 可使用的输入

- `goalText`：本次目标；`clarificationAnswer`：本轮追加/更正。
- `currentDate`、`timeZoneID`：时间依据。
- `busyWindows`：仅开始/结束的忙闲区间；`existingDailyLoads`：已安排分钟数。它们不代表已授权读取所有 Calendar 内容。
- `activeChallengeIDs`：可推荐 ID 白名单，不包含热门排名。
- 宿主附加的 `skillVersion`：新计划的指令版本，填入 `plan.skillVersion`。本版本为 `1.1.1`。
- `locale` 可用于理解输入，但首版的标题、备注、问题和说明都用简体中文。

这里没有长期记忆、考试评分、具体日期精度字段、日程写入工具，也没有网络搜索工具。不要虚构这些上下文或执行结果。

## 返回两种结果之一

澄清：`kind: "clarification"`、一个简短 `question`、`plan: null`。通常只问一个真实缺口；无可行时段、过去的期限或接口无法承载用户要求时，也用这个分支说明限制并询问必要选择。不为满足结构而编造空闲时间。

计划：`kind: "plan"`、`question: null`，完整填入 `plan`。保持所有 schema 必填字段，空数组/`null` 按定义使用，不能省略或加入解释段。

- `id` 与子项 ID 使用合法 UUID，整份新计划内互不重复。
- `title` 简短；`clarifiedGoal` 保留用户真正的成果与期限；`deadline` 必须是未来的真实截止点。
- `phases` 2–5 个，开始/结束有序且都在目标时间范围；`milestones` 写实际验收标准，不能声称已经完成。
- `initialBlocks` 按开始时间升序，最多 100 项，单项 15–180 分钟。每个时间都依据本地时区换算；生成后检查相互冲突、休息、忙闲、预算与截止日期。
- 新计划的 `recurringPatterns` 为空数组：现有结构没有单独的模式起始日期，无法可靠表达“从第十五天开始重复”。远期节奏写进阶段说明和假设，不能制造重复任务。
- `assumptions` 只列真正采用的假设，通常 1–3 条，最多 6 条。`warnings` 只列实际限制，最多 6 条；没有问题就留空，不加泛泛免责声明。
- `recommendedChallengeID` 默认 `null`；有明确匹配依据时也只能用输入白名单。

## 输出前最后核对

成果是否仍是用户要的？先后依赖是否正确？今天是否还能开始？每项是否说得清做到哪里结束？是否计算已有负担与复习时间？是否占用了明说的休息？有没有重复事项或伪造来源？最后，只返回符合本次结构的 JSON。

本指令的版本不等于所有操作的响应版本。`suggestAdjustment` 使用独立的 `1.0.0` 响应契约，不返回上述 `kind/question/plan`。
