# MCP 文件交换

[English](MCP.en.md) · [项目介绍](../README.md) · [数据契约](MCP-CONTRACT.md)

DayVault 的 MCP 服务让外部 AI 读取一份由你导出的目标快照，并生成可导回 App 的计划草案。服务运行在电脑上，不需要 DayVault 的 API 密钥，也不调用模型。模型由 Codex、Claude Code、Gemini CLI 等宿主工具提供。

它不会读取 AI 工具里的聊天历史、直接访问 iCloud 或实时同步手机。App 内的 AI 排程和聊天仍然停用。外部工具可能把读取到的内容发送给模型提供商，相关费用和数据处理规则由你选用的工具决定。

## 1. 从 iPhone 导出

打开“设置 → MCP 文件交换”。在“导出目标快照”中选择目标，点“预览导出范围”，核对名称、日期范围、记录数和时区，再点“导出 JSON”。没有目标时，先在目标管理中创建目标并关联事项。

快照只包含所选目标、已设置的节奏和休息日，以及过去 30 天至未来 14 天内的相关事项。每条事项只提供标题、日期、状态及时间精度等有限字段，不导出笔记、聊天、回忆、Calendar 内容或成就规则。待安排和已移除的事项不在快照内。这不是完整备份。

通过“文件”、AirDrop 或其他你认可的方式把 JSON 传到电脑，放在私人目录中。以下示例使用 `/absolute/dayvault-private/snapshot.json`；请替换成真实绝对路径，不要把个人快照放进 Git 仓库。

## 2. 安装本地服务

电脑端面向 macOS / Linux，需要 Node.js 22 或更新版本。文件保护使用 POSIX 权限；Windows 尚未验证，不能直接套用这些隐私保证。已克隆 DayVault 后，在仓库根目录运行：

```sh
cd MCP
npm ci --ignore-scripts
npm test
```

依赖安装从 npm 获取固定版本的包。正常运行时，DayVault MCP 服务本身不联网；它读取指定快照，并在指定的私有输出目录创建草案文件。仓库没有发布需要另行安装的全局 npm 包。

启动命令的形式如下。客户端通常会自行启动服务，无须另开终端长期运行：

```sh
node /absolute/DayVault/MCP/src/server.mjs \
  --snapshot /absolute/dayvault-private/snapshot.json \
  --outbox /absolute/dayvault-private/outbox
```

所有路径都要替换。`outbox` 新建时使用仅当前用户可访问的权限；已有目录也必须是当前用户拥有的私人目录。服务拒绝符号链接，模型无法通过工具参数指定其他读写路径。若客户端找不到 `node`，用 `command -v node` 查找安装位置，在配置中填写该绝对路径。

快照在服务启动时读取一次。替换快照文件或更改 `--snapshot` 路径后，重新启动客户端中的 DayVault MCP 服务，让新会话读取更新的记录；它不会自动刷新文件。

## 3. 配置客户端

只配置自己实际使用的工具。以下操作会增加一个名为 `dayvault` 的 MCP 服务，不会要求提供 DayVault 密钥。保留客户端的工具审批，不开启自动批准所有工具。

### Codex

在 Codex 的 `config.toml` 中合并以下段落，不要覆盖其他设置：

```toml
[mcp_servers.dayvault]
command = "node"
args = ["/absolute/DayVault/MCP/src/server.mjs", "--snapshot", "/absolute/dayvault-private/snapshot.json", "--outbox", "/absolute/dayvault-private/outbox"]
```

重新载入相关会话，在 MCP 列表中检查服务是否可用。配置字段与本地进程方式参见 [Codex 官方 MCP 文档](https://developers.openai.com/codex/mcp/)。

### Claude Code

在希望使用服务的项目目录运行，替换以下绝对路径：

```sh
claude mcp add --transport stdio dayvault -- node \
  /absolute/DayVault/MCP/src/server.mjs \
  --snapshot /absolute/dayvault-private/snapshot.json \
  --outbox /absolute/dayvault-private/outbox
```

在 Claude Code 中使用 `/mcp` 检查状态，并按提示批准服务。`--` 后面是服务的启动命令，不是 Claude Code 自身的选项。[Claude Code 官方 MCP 文档](https://code.claude.com/docs/en/mcp)

### Gemini CLI

在 Gemini CLI 的 `settings.json` 中合并 `mcpServers` 项。已有同名配置时先检查，不要把整个文件替换为示例：

```json
{
  "mcpServers": {
    "dayvault": {
      "command": "node",
      "args": [
        "/absolute/DayVault/MCP/src/server.mjs",
        "--snapshot", "/absolute/dayvault-private/snapshot.json",
        "--outbox", "/absolute/dayvault-private/outbox"
      ],
      "trust": false
    }
  }
}
```

重新启动 Gemini CLI，再检查 `/mcp`。`trust: false` 保留工具调用确认。[Gemini CLI 官方 MCP 文档](https://geminicli.com/docs/tools/mcp-server/)

这些是三家工具官方文档支持的 stdio 配置方式，不代表本项目已在每一种客户端、账号和模型上完成端到端验证。实际验证范围见 [v1.4 发布说明](releases/v1.4.0.md)。

## 4. 提出草案并带回手机

可以直接向外部 AI 提出这样的请求：

> 读取 DayVault 中这个阅读目标的记录。我想在下周安排两次阅读，每次只列出具体要做的一件事。遵守目标期限和休息日，先解释安排；经我同意后，生成可导入的草案文件。

服务提供的 `dayvault_plan` 提示词说明了读取、讨论和提出草案的顺序。工具权限如下：

| 工具 | 作用 |
| --- | --- |
| `dayvault_get_context` | 读取已配置快照中的目标、范围和限制 |
| `dayvault_list_records` | 列出该快照中的事项，可按状态筛选 |
| `dayvault_propose_schedule` | 校验新增事项建议，在输出目录生成 JSON 草案 |

草案只允许 1–20 条有日期、无具体时刻、不重复的新事项。日期限于目标时区的今天至未来 14 天，并遵守目标期限与休息日。服务不能改写或删除原事项，不能标记完成、解锁成就或发起购买。

生成文件不等于保存到 App。把草案 JSON 传回 iPhone，在“导入计划草案”中点“选择 JSON 文件”。“检查计划草案”会显示目标、时区和逐项日期；读完后点“确认新增 N 项”。不满意可以关闭预览，不会写入。

确认时 App 会依据当前目标重新校验，而不是盲信旧快照。重复导入不能重复创建同一批事项；同目标、同标题、同日期的已有事项也会被拦截。草案超过七天、目标已更名、休息日变化或日期已过，可能需要重新导出后再生成。不会用过期草案覆盖后来改动的记录。

## 数据处理与常见问题

快照和草案是普通本地文件，没有额外文件加密。将它们放在私人目录，并考虑磁盘加密；不要提交到 Git、公开问题或聊天截图。关闭服务或删除本地文件不会撤回外部工具已经收到的副本。

- 服务启动后在终端没有输出：stdio 服务等待 MCP 客户端消息是正常现象。标准输出专用于协议，不是聊天界面。
- 找不到文件或权限不符：检查绝对路径、文件拥有者和输出目录权限。不要把输出目录改成公共共享目录来绕过错误。
- 草案被拒绝：先看具体原因。更新目标后重新导出快照，再请模型生成符合日期、期限和休息日的草案；不要通过手改 UUID 绕过重复检查。
- 记录过多：单次快照最多 1,000 条，超出会报错，不会静默截断。当前交换功能不能替代大规模备份。
- 想直接修改原计划：v1.4 不提供该权限。请在 App 中手动编辑。
- 跨时区后看到日期偏移：草案按目标时区验证和保存，但当前今日清单按设备时区取日期范围。旅行或切换设备时区后，仅日期事项可能出现在相邻日期；该既有限制尚未修复，请在导入预览中核对目标时区和日期。

[固定示例文件](../MCP/fixtures)使用合成内容和固定日期，只用于契约测试。它们不是可永久导入的活动计划，也不能证明任何真实用户的成就。完整字段和大小限制见[数据契约](MCP-CONTRACT.md)。
