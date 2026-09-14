# DayVault file exchange, schema 1

This is the implementation contract for the optional v1.4 local stdio MCP server.
The iPhone app never hosts an MCP port or calls a model. Files are transferred by
the user. A snapshot is a selected-goal export, not a backup or live database.

## Snapshot

```json
{
  "schemaVersion": 1,
  "kind": "dayvault.snapshot",
  "id": "11111111-1111-4111-8111-111111111111",
  "exportedAt": "2026-09-14T12:00:00Z",
  "goal": {
    "id": "22222222-2222-4222-8222-222222222222",
    "title": "阅读",
    "timeZoneID": "Asia/Shanghai",
    "restWeekdays": [1, 7],
    "weeklyTargetDays": 5
  },
  "window": { "startDate": "2026-08-15", "endDate": "2026-09-28" },
  "records": [
    { "id": "opaque-occurrence-key", "itemID": "33333333-3333-4333-8333-333333333333",
      "title": "阅读一章", "date": "2026-09-14", "status": "completed",
      "timePrecision": "dateOnly" }
  ]
}
```

Optional goal fields: `weeklyTargetDays` (1–7), `deadlineDate` (YYYY-MM-DD).
Records are resolved occurrences in the selected goal, from 30 calendar days ago
through 14 calendar days ahead. Only the fields shown are exported; no notes,
Calendar data, memories, chats, achievement definitions or hidden rules. Status
is `planned`, `active`, `completed`, `skipped` or `removed`; precision is
`dateOnly`, `timed` or `inbox`. Inbox and removed entries are excluded by the app.
Dates use the goal time zone, not the computer time zone. Up to 1,000 records;
oversized exports fail explicitly, never silently omit entries.

## Proposal

```json
{
  "schemaVersion": 1,
  "kind": "dayvault.proposal",
  "id": "44444444-4444-4444-8444-444444444444",
  "snapshotID": "11111111-1111-4111-8111-111111111111",
  "goalID": "22222222-2222-4222-8222-222222222222",
  "goalTitle": "阅读",
  "timeZoneID": "Asia/Shanghai",
  "createdAt": "2026-09-14T12:01:00Z",
  "summary": "下周安排两次阅读。",
  "items": [
    { "id": "55555555-5555-4555-8555-555555555555", "title": "阅读下一章", "date": "2026-09-15" }
  ]
}
```

Only new date-only, non-recurring items can be proposed. No completion, editing,
deletion, reminder, actual-time, ranking or achievement-unlock tool exists.
Dates must be today through 14 days ahead, inclusive, in the goal zone and respect
the current goal deadline and rest days. An old snapshot does not grant write
authority. The app checks current goal ID, title, time zone, dates, deadline,
rest days, existing IDs and same-goal/title/date duplicates again on confirmation.
Batch save is atomic; IDs are preserved so reimport cannot duplicate that batch.
The app must require preview and explicit confirmation. It does not import goals.

## Limits and errors

Both sides reject unsupported versions, unknown proposal keys, invalid UUIDs,
invalid calendar dates, invalid zones, empty text, controls, duplicate IDs and
duplicate title/date pairs. Text limits are Unicode scalar counts: title 120,
goalTitle 500, summary 500. Proposal: 1–20 items, at most 128 KiB. Snapshot: at
most 1 MiB. `createdAt` may not be over 5 minutes in the future or over 7 days old
when accepted. No user text is evaluated as code or as server instructions.

## Local server

Run `node MCP/src/server.mjs --snapshot /absolute/snapshot.json --outbox /absolute/outbox`.
It reads only the configured regular snapshot file and writes new proposal files
to the configured private outbox. Model tool arguments cannot choose paths.
Reject symlinks, use exclusive file creation and private permissions, keep stdout
for JSON-RPC and report errors without dumping personal data.

Tools: `dayvault_get_context`, `dayvault_list_records` (optional status filter),
`dayvault_propose_schedule` (`summary`, `items` of `title` and `date`). The server
generates all IDs and provenance from the loaded snapshot. It never calls a model
or reaches a network. The host AI may send returned data to its provider.
Prompt: `dayvault_plan` (optional `request`) explains the context/proposal workflow,
respects the user's goal and asks only for missing facts. This is not the retired
in-app planner or an automatic adjustment service.
