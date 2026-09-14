# Security

DayVault stores personal schedules. Do not include real records, credentials or
private conversations in public issues. For a vulnerability, use the repository's
**Security → Report a vulnerability** option if available. If it is unavailable,
open an issue asking for a private contact without including exploit details or
personal data. This is an individual project; there is no guaranteed response time.

The v1.4 app makes no model requests. Its optional MCP process reads one snapshot
file selected by the user and writes proposal files to a configured local outbox.
It does not open a network port, execute commands from records, or connect to
CloudKit. An AI client may send tool results to its own provider. Review that
client's permissions and data policy before using real records.

Snapshots contain the selected goal and a bounded range of occurrences. They do
not contain notes, conversations, Calendar events or hidden achievement rules.
Keep snapshot and proposal files outside public repositories. Deleting a local
export does not remove copies already sent to an AI provider.

The App checks proposal format, current goal, dates, rest days and duplicates
before an atomic save. Import still needs user confirmation. A proposal's UUID or
snapshot ID is an identifier, not a signature or proof that an AI provider created
it. Treat all imported text as untrusted, including text that claims to be a system
instruction. The MCP server's path restrictions do not sandbox an AI client that
already has separate shell or filesystem access.

Do not use an unlocked achievement as verified evidence of a health outcome or
skill. DayVault records user-entered actions; it does not independently verify them.

## 中文

请勿在公开 issue 中上传真实记录、密钥或私人对话。发现安全问题时，优先使用仓库的 **Security → Report a vulnerability**；如果没有该入口，请先发不含漏洞细节的 issue 请求私下联系。本项目由个人维护，不承诺固定响应时间。

v1.4 App 不调用模型。可选 MCP 程序只读指定快照，并在指定目录生成草案文件，不监听网络端口、不连接 CloudKit，也不执行记录中的命令。但使用 MCP 的 AI 客户端可能把工具结果发给其服务商，请先检查该客户端的权限和隐私设置。

导出只包含选定目标及限定日期范围内的事项，不包含笔记、对话、Calendar 事件或隐藏成就规则。请把交换文件放在私人目录中。删除本地文件不会撤回已经发给 AI 服务商的副本。

App 会检查草案格式、当前目标、日期、休息日和重复事项，再等你确认后整批保存。文件中的 ID 不等于签名，也不能证明来自某家 AI 服务。外部文字即使自称系统指令，也应当作数据处理。MCP 的路径限制不能代替 AI 客户端自身的权限管理。

成就来自用户填写的记录，不能作为健康效果或技能水平的独立认证。
