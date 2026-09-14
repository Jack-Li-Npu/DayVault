# DayVault MCP

本地 stdio 服务，读取用户导出的目标快照，为外部 AI 工具提供记录查询和新增事项草案。只生成文件，不直接修改 iPhone 数据，也不调用模型。

A local stdio server for reading exported goal snapshots and preparing new-item proposals. It writes files, not the iPhone database, and makes no model calls.

[中文接入指南](../docs/MCP.zh-CN.md) · [English setup](../docs/MCP.en.md) · [Schema and permissions](../docs/MCP-CONTRACT.md)

## Setup / 安装

macOS / Linux, Node.js 22+. File protection uses POSIX permissions; Windows is unverified. / 文件保护使用 POSIX 权限，Windows 尚未验证。

From this directory / 在本目录运行：

```sh
npm ci --ignore-scripts
npm test
```

Configure the MCP client to run / 在 MCP 客户端中配置启动命令：

```sh
node /absolute/DayVault/MCP/src/server.mjs \
  --snapshot /absolute/dayvault-private/snapshot.json \
  --outbox /absolute/dayvault-private/outbox
```

替换所有绝对路径，使用 App 当前导出的快照。`fixtures` 是固定日期的合成测试数据。快照和草案包含私人内容，不要提交到 Git。客户端可能把工具读取的内容发送给模型提供商，模型费用由所选客户端的账号承担。

Replace every absolute path and use a current app export. `fixtures` contains synthetic, fixed-date test data. Keep personal snapshots and proposals out of Git. The host client may send tool results to its model provider; model charges belong to the account used by that client.

This package is provided as repository source, not a separately published npm package. / 本目录提供仓库源码，没有单独发布为 npm 包。
