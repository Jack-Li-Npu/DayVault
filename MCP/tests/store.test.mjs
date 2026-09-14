import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { ExchangeStore, absolutePath, safeError } from "../src/store.mjs";
import { LIMITS } from "../src/contract.mjs";
import { clock, fixture, workspace } from "./helpers.mjs";

const input = () => ({ summary: "安排阅读", items: [{ title: "阅读下一章", date: "2026-09-15" }] });
const open = options => ExchangeStore.open({ ...options, now: () => clock });

test("reads only configured snapshot, omits removed/inbox records and strips paths from context", async t => {
  const snapshot = await fixture();
  snapshot.records.push({ ...snapshot.records[0], id: "removed", status: "removed" }, { ...snapshot.records[0], id: "inbox", timePrecision: "inbox" });
  const options = await workspace(t, snapshot);
  const store = await open(options);
  assert.equal(store.records().length, 1);
  assert.equal(store.records("planned").length, 0);
  assert.equal(store.context().recordCount, 1);
  assert.ok(!JSON.stringify(store.context()).includes(options.dir));
  // The running server uses the one validated snapshot, not an unvalidated replacement.
  await fs.writeFile(options.snapshotPath, "private contents replaced externally");
  assert.equal(store.records()[0].title, "阅读一章");
});

test("creates private outbox/proposal, preserving generated IDs and provenance", async t => {
  const options = await workspace(t);
  const store = await open(options);
  const result = await store.propose(input());
  assert.equal((await fs.stat(options.outboxPath)).mode & 0o777, 0o700);
  assert.equal((await fs.stat(path.join(options.outboxPath, result.filename))).mode & 0o777, 0o600);
  assert.equal(result.proposal.goalID, store.snapshot.goal.id);
  assert.equal(result.proposal.snapshotID, store.snapshot.id);
  assert.equal(result.requiresAppConfirmation, true);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(options.outboxPath, result.filename), "utf8")), result.proposal);
  assert.equal((await fs.readdir(options.dir)).length, 2);
});

test("identical, parallel and restarted requests reuse one file/IDs without overwrite", async t => {
  const options = await workspace(t);
  const store = await open(options);
  const [first, parallel] = await Promise.all([store.propose(input()), store.propose(input())]);
  assert.deepEqual(first.proposal, parallel.proposal);
  const again = await (await open(options)).propose(input());
  assert.deepEqual(first.proposal, again.proposal);
  assert.equal(again.reused, true);
  assert.equal((await fs.readdir(options.outboxPath)).length, 1);
});

test("reordered identical items reuse one canonical proposal", async t => {
  const store = await open(await workspace(t));
  const args = input(); args.items.push({ title: "写一条读书笔记", date: "2026-09-16" });
  const first = await store.propose(args);
  args.items.reverse();
  assert.equal((await store.propose(args)).proposal.id, first.proposal.id);
});

test("existing modified proposal is never overwritten", async t => {
  const options = await workspace(t);
  const store = await open(options);
  const first = await store.propose(input());
  const file = path.join(options.outboxPath, first.filename);
  const changed = { ...first.proposal, summary: "用户改过的内容" };
  await fs.writeFile(file, JSON.stringify(changed));
  await assert.rejects(() => store.propose(input()), error => error.code === "FILE_CONFLICT");
  assert.equal(JSON.parse(await fs.readFile(file, "utf8")).summary, changed.summary);
});

test("past-dated or expired retry cannot regenerate or overwrite its file", async t => {
  const options = await workspace(t);
  const store = await open(options);
  const first = await store.propose(input());
  const before = await fs.readFile(path.join(options.outboxPath, first.filename), "utf8");
  const later = await ExchangeStore.open({ ...options, now: () => new Date(+clock + 8 * 86400000) });
  await assert.rejects(() => later.propose(input()));
  assert.equal(await fs.readFile(path.join(options.outboxPath, first.filename), "utf8"), before);
});

test("model text cannot select a filesystem path or execute commands", async t => {
  const options = await workspace(t);
  const store = await open(options);
  await assert.rejects(() => store.propose({ ...input(), path: path.join(options.dir, "escape.json") }));
  const result = await store.propose({ summary: "文本测试", items: [{ title: "../../escape $(touch hacked) <script>", date: "2026-09-15" }] });
  assert.match(result.filename, /^dayvault-proposal-[a-f0-9-]+\.json$/);
  assert.deepEqual((await fs.readdir(options.dir)).sort(), ["outbox", "snapshot.json"]);
});

test("relative and traversal configuration paths are refused", () => {
  for (const value of ["snapshot.json", "/private/tmp/../snapshot.json", "/", "/private/tmp/./snapshot.json", "/private/tmp/a\0b"]) assert.throws(() => absolutePath(value));
});

test("snapshot symlink, symlinked parent, directory and oversize file are refused", async t => {
  const options = await workspace(t);
  const link = path.join(options.dir, "link.json");
  await fs.symlink(options.snapshotPath, link);
  await assert.rejects(() => open({ ...options, snapshotPath: link }));
  const directoryLink = path.join(options.dir, "linked-parent");
  await fs.symlink(options.dir, directoryLink);
  await assert.rejects(() => open({ ...options, snapshotPath: path.join(directoryLink, "snapshot.json") }));
  await assert.rejects(() => open({ ...options, snapshotPath: options.dir }));
  await fs.writeFile(options.snapshotPath, Buffer.alloc(LIMITS.snapshotBytes + 1));
  await assert.rejects(() => open(options), error => error.code === "TOO_LARGE");
});

test("public or symlinked outbox is refused without chmod of existing directories", async t => {
  const options = await workspace(t);
  await fs.mkdir(options.outboxPath, { mode: 0o755 });
  await fs.chmod(options.outboxPath, 0o755);
  await assert.rejects(() => open(options));
  assert.equal((await fs.stat(options.outboxPath)).mode & 0o777, 0o755);
  const link = path.join(options.dir, "outbox-link");
  await fs.symlink(options.outboxPath, link);
  await assert.rejects(() => open({ ...options, outboxPath: link }));
});

test("a replaced outbox and a symlinked output are refused", async t => {
  const options = await workspace(t);
  const store = await open(options);
  const first = await store.propose(input());
  const file = path.join(options.outboxPath, first.filename);
  const moved = path.join(options.dir, "preserved-proposal.json");
  await fs.rename(file, moved); await fs.symlink(moved, file);
  await assert.rejects(() => store.propose(input()));
  await fs.rename(options.outboxPath, path.join(options.dir, "old-outbox"));
  await fs.mkdir(options.outboxPath, { mode: 0o700 });
  await assert.rejects(() => store.propose(input()));
  assert.equal((await fs.readdir(options.outboxPath)).length, 0);
});

test("all unexpected errors are redacted", () => {
  assert.ok(!safeError(new Error("secret-path/secret-user-notes")).includes("secret"));
});
