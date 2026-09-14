import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import { addDays, dayInZone } from "../src/contract.mjs";

export const root = fileURLToPath(new URL("../", import.meta.url));
export const clock = new Date("2026-09-14T12:01:00Z");
export async function fixture(name = "snapshot") {
  return JSON.parse(await fs.readFile(path.join(root, "fixtures", `${name}.example.json`), "utf8"));
}
export async function workspace(t, snapshot) {
  const tempRoot = await fs.realpath(os.tmpdir());
  const dir = await fs.mkdtemp(path.join(tempRoot, "dayvault-mcp-test-"));
  t.after(() => fs.rm(dir, { recursive: true, force: true }));
  const snapshotPath = path.join(dir, "snapshot.json");
  const outboxPath = path.join(dir, "outbox");
  await fs.writeFile(snapshotPath, JSON.stringify(snapshot ?? await fixture()), { mode: 0o600 });
  return { dir, snapshotPath, outboxPath };
}
export async function currentSnapshot() {
  const snapshot = await fixture();
  const today = dayInZone(new Date(), snapshot.goal.timeZoneID);
  snapshot.exportedAt = new Date().toISOString();
  snapshot.goal.restWeekdays = [];
  snapshot.goal.deadlineDate = addDays(today, 14);
  snapshot.window = { startDate: addDays(today, -30), endDate: addDays(today, 14) };
  snapshot.records[0].date = today;
  return snapshot;
}
