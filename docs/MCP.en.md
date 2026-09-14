# MCP file exchange

[简体中文](MCP.zh-CN.md) · [Project introduction](../README.en.md) · [Data contract](MCP-CONTRACT.md)

DayVault's MCP server lets an external AI read a goal snapshot you export and prepare a schedule proposal for the app. It runs on your computer, needs no DayVault API key and does not call a model. The host tool, such as Codex, Claude Code or Gemini CLI, supplies the model.

It does not read the tool's chat history, access iCloud directly or keep the phone in sync. In-app AI scheduling and chat remain disabled. Your external tool may send the data it reads to its model provider; that tool's charges and data policies apply.

## 1. Export from the iPhone

Open Settings → “MCP 文件交换” (MCP file exchange). Under “导出目标快照” (Export goal snapshot), select a goal and tap “预览导出范围” (Preview export range). Check the title, date range, record count and time zone, then tap “导出 JSON”. If no goal exists, create one through goal management and associate the relevant items first.

The snapshot contains the selected goal, its configured frequency and rest days, and related items from 30 days ago through 14 days ahead. Records include limited fields such as title, date, status and time precision. Notes, conversations, memories, Calendar data and achievement rules are excluded, as are unscheduled and removed items. This is not a full backup.

Transfer the JSON file to a private folder on your computer using Files, AirDrop or a method you trust. The examples below use `/absolute/dayvault-private/snapshot.json`; replace it with your actual absolute path. Do not put personal snapshots in the Git repository.

## 2. Install the local server

The server targets macOS / Linux with Node.js 22 or newer. File protection relies on POSIX permissions; Windows is unverified, so these privacy guarantees should not be assumed there. From a cloned DayVault repository, run:

```sh
cd MCP
npm ci --ignore-scripts
npm test
```

Installation downloads pinned dependencies from npm. During normal operation, the DayVault server itself makes no network requests: it reads the configured snapshot and creates proposal files in the configured private outbox. There is no separately published global npm package to install.

The launch command has this form. The client normally starts the process, so you do not need to keep a separate server terminal open:

```sh
node /absolute/DayVault/MCP/src/server.mjs \
  --snapshot /absolute/dayvault-private/snapshot.json \
  --outbox /absolute/dayvault-private/outbox
```

Replace every path. New outbox directories are private to their owner; existing ones must also be owned by the current user and have private permissions. The server rejects symlinks, and model tool arguments cannot select other filesystem paths. If the client cannot find `node`, run `command -v node` and use that absolute path in its configuration.

The server reads the snapshot once at startup. After replacing the file or changing `--snapshot`, restart the DayVault MCP server in your client so the new session reads the updated records. Files do not refresh automatically.

## 3. Configure your client

Choose the tool you use. These examples add a server named `dayvault`, without a DayVault credential. Keep the client's tool approvals enabled rather than approving every tool automatically.

### Codex

Merge this section into the Codex `config.toml`; leave other settings intact:

```toml
[mcp_servers.dayvault]
command = "node"
args = ["/absolute/DayVault/MCP/src/server.mjs", "--snapshot", "/absolute/dayvault-private/snapshot.json", "--outbox", "/absolute/dayvault-private/outbox"]
```

Reload the relevant session and check the MCP server list. See the [official Codex MCP documentation](https://developers.openai.com/codex/mcp/) for the configuration fields and local process setup.

### Claude Code

From the project where you want to use the server, run this command with your paths:

```sh
claude mcp add --transport stdio dayvault -- node \
  /absolute/DayVault/MCP/src/server.mjs \
  --snapshot /absolute/dayvault-private/snapshot.json \
  --outbox /absolute/dayvault-private/outbox
```

Use `/mcp` in Claude Code to inspect the status and approve the server when prompted. Arguments after `--` belong to the server command. [Official Claude Code MCP documentation](https://code.claude.com/docs/en/mcp)

### Gemini CLI

Merge this entry into `mcpServers` in Gemini CLI's `settings.json`. Check for an existing entry with the same name, and do not replace the entire settings file with this example:

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

Restart Gemini CLI and check `/mcp`. `trust: false` retains tool-call confirmation. [Official Gemini CLI MCP documentation](https://geminicli.com/docs/tools/mcp-server/)

These configurations follow the clients' documented stdio support. They are not a claim that this project has completed end-to-end tests with every client, account or model. See the [v1.4 release notes](releases/v1.4.0.md) for the actual verification scope.

## 4. Prepare and import a proposal

For example, ask the external AI:

> Read this DayVault reading goal. I want two reading sessions next week, each with one specific action. Respect its deadline and rest days. Explain the proposed dates first; after I agree, create the importable proposal file.

The server's `dayvault_plan` prompt describes the context, discussion and proposal steps. The available tools are:

| Tool | What it does |
| --- | --- |
| `dayvault_get_context` | Reads the configured snapshot's goal, window and constraints |
| `dayvault_list_records` | Lists its records, with an optional status filter |
| `dayvault_propose_schedule` | Validates proposed new items and writes a JSON file to the outbox |

A proposal contains 1–20 new, date-only, non-recurring items. Dates must fall between today and 14 days ahead in the goal's time zone, within its deadline and outside its rest days. There is no tool to edit or delete existing items, mark them complete, grant an achievement or purchase anything.

Creating the file does not save anything in the app. Transfer it to the iPhone and choose “选择 JSON 文件” (Select JSON file) under the import section. The “检查计划草案” (Review proposal) sheet shows the goal, time zone and each item with its date. Tap “确认新增 N 项” (Confirm N new items) only when satisfied. Closing the preview writes nothing.

At confirmation, the app checks the current goal again instead of trusting an old snapshot. Reimporting a batch cannot duplicate its items; an existing item with the same goal, title and date is also rejected. A proposal more than seven days old, a renamed goal, changed rest days or dates that have passed may require a fresh export. An old proposal cannot overwrite later changes.

## File handling and troubleshooting

Snapshots and proposals are ordinary local files without additional file encryption. Use a private directory and consider disk encryption. Keep them out of Git, public issues and screenshots. Stopping the server or deleting local files does not withdraw copies already received by an external tool.

- A manually started server appears quiet: stdio waits for MCP client messages. Its standard output is reserved for the protocol, not an interactive chat.
- Missing file or permission error: check absolute paths, file ownership and private outbox permissions. Do not switch to a public directory to bypass the check.
- Rejected proposal: read the reported reason. Export again after changing a goal, then request dates that respect the current deadline and rest days. Do not change UUIDs to bypass duplicate checks.
- Too many records: a snapshot is limited to 1,000 records. The app reports oversized exports instead of silently truncating them. This exchange feature is not a bulk backup tool.
- Need to move an existing item: edit it in the app. v1.4 does not grant that permission to MCP.
- A date shifts after travel: proposals are validated and stored in the goal's time zone, but Today currently selects its range using the device time zone. After travel or a device-zone change, a date-only item may appear on the adjacent day. This existing limitation is not fixed; check the goal time zone and dates in the import preview.

The [fixture files](../MCP/fixtures) contain synthetic records and fixed dates for contract tests. They are not permanently importable live plans and are not evidence of a real user's achievements. See the [data contract](MCP-CONTRACT.md) for field and size limits.
