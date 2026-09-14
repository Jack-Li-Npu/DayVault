import fs from "node:fs/promises";
import { constants } from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { ExchangeError, LIMITS, addDays, dayInZone, decodeJSON, validateSnapshot, validateProposal, validateProposalInput } from "./contract.mjs";

const fileError = () => new ExchangeError("FILE_ACCESS", "无法安全访问配置的文件目录。请检查绝对路径、文件类型与权限；不支持符号链接。");
const sameFile = (a, b) => a.dev === b.dev && a.ino === b.ino;

function compareText(a, b) {
  if (a < b) return -1;
  if (a > b) return 1;
  return 0;
}

export function absolutePath(value) {
  if (typeof value !== "string" || !path.isAbsolute(value) || value.includes("\0") || value.split(path.sep).includes("..") ||
      value.split(path.sep).includes(".") || path.parse(value).root === value) throw fileError();
  return path.normalize(value);
}

async function inspectPath(value) {
  const absolute = absolutePath(value);
  const parts = absolute.slice(path.parse(absolute).root.length).split(path.sep);
  let cursor = path.parse(absolute).root;
  let info;
  for (let index = 0; index < parts.length; index++) {
    cursor = path.join(cursor, parts[index]);
    info = await fs.lstat(cursor);
    if (info.isSymbolicLink() || (index < parts.length - 1 && !info.isDirectory())) throw fileError();
  }
  return info;
}

async function boundedRead(file, limit) {
  const before = await inspectPath(file);
  if (!before.isFile() || before.size > limit) {
    if (before.size > limit) throw new ExchangeError("TOO_LARGE", "文件超出大小限制。");
    throw fileError();
  }
  const handle = await fs.open(file, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const opened = await handle.stat();
    if (!sameFile(before, opened) || !opened.isFile() || opened.size > limit) throw fileError();
    // Read at most limit+1 even if another process grows the file after stat.
    const buffer = Buffer.alloc(limit + 1);
    let length = 0;
    while (length < buffer.length) {
      const { bytesRead } = await handle.read(buffer, length, buffer.length - length, length);
      if (!bytesRead) break;
      length += bytesRead;
    }
    if (length > limit) throw new ExchangeError("TOO_LARGE", "文件超出大小限制。");
    const after = await inspectPath(file);
    if (!sameFile(opened, after) || after.size !== opened.size || after.mtimeMs !== opened.mtimeMs) throw fileError();
    return buffer.subarray(0, length);
  } finally { await handle.close(); }
}

function stableUUID(seed) {
  const bytes = createHash("sha256").update(seed).digest().subarray(0, 16);
  // UUIDv8 reserves this application-defined, deterministic hash layout.
  bytes[6] = (bytes[6] & 0x0f) | 0x80;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

export function safeError(error) {
  return error instanceof ExchangeError ? `${error.code}: ${error.message}` : "FILE_ACCESS: 无法安全完成文件操作。请检查配置的文件与权限。";
}

export class ExchangeStore {
  static async open({ snapshotPath, outboxPath, now = () => new Date() }) {
    try {
      snapshotPath = absolutePath(snapshotPath);
      outboxPath = absolutePath(outboxPath);
      const snapshot = validateSnapshot(decodeJSON(await boundedRead(snapshotPath, LIMITS.snapshotBytes), LIMITS.snapshotBytes));
      await inspectPath(path.dirname(outboxPath));
      try { await fs.mkdir(outboxPath, { mode: 0o700 }); }
      catch (error) { if (error.code !== "EEXIST") throw error; }
      const identity = await inspectPath(outboxPath);
      if (!identity.isDirectory() || (identity.mode & 0o077) !== 0 ||
          (typeof process.getuid === "function" && identity.uid !== process.getuid())) throw fileError();
      return new ExchangeStore(snapshot, outboxPath, identity, now);
    } catch (error) { throw error instanceof ExchangeError ? error : fileError(); }
  }

  constructor(snapshot, outboxPath, identity, now) {
    this.snapshot = snapshot;
    this.outboxPath = outboxPath;
    this.identity = identity;
    this.now = now;
    this.pending = new Map();
  }

  context() {
    const { schemaVersion, kind, id, exportedAt, goal, window } = this.snapshot;
    const today = dayInZone(this.now(), goal.timeZoneID);
    return structuredClone({ schemaVersion, kind, id, exportedAt, goal, window,
      recordCount: this.records().length,
      proposalWindow: { startDate: today, endDate: addDays(today, 14) },
      permission: "仅供本次规划参考；不是实时数据。新事项须在 DayVault 内预览确认。",
      privacy: "仅包含此目标导出的字段，不包含备注、对话、回忆、系统日历或隐藏成就。宿主 AI 可能将返回内容发送给其服务商。",
    });
  }

  records(status) {
    return structuredClone(this.snapshot.records.filter(record => record.status !== "removed" && record.timePrecision !== "inbox" &&
      (status === undefined || record.status === status)));
  }

  async checkOutbox() {
    const current = await inspectPath(this.outboxPath);
    if (!sameFile(this.identity, current) || !current.isDirectory() || (current.mode & 0o077) !== 0) throw fileError();
  }

  async propose(input) {
    const accepted = validateProposalInput(input, this.snapshot, this.now());
    // Canonical order makes re-ordered retries refer to the same proposal.
    accepted.items.sort((a, b) => compareText(a.date, b.date) || compareText(a.title, b.title));
    const id = stableUUID(JSON.stringify({ snapshotID: this.snapshot.id.toLowerCase(), ...accepted }));
    if (this.pending.has(id)) return this.pending.get(id);
    const work = this.writeProposal(id, accepted);
    this.pending.set(id, work);
    try { return await work; } finally { this.pending.delete(id); }
  }

  async writeProposal(id, accepted) {
    const proposal = {
      schemaVersion: 1, kind: "dayvault.proposal", id, snapshotID: this.snapshot.id,
      goalID: this.snapshot.goal.id, goalTitle: this.snapshot.goal.title, timeZoneID: this.snapshot.goal.timeZoneID,
      createdAt: this.now().toISOString(), summary: accepted.summary,
      items: accepted.items.map((item, index) => ({ id: stableUUID(`${id}:${index}`), ...item })),
    };
    validateProposal(proposal, this.now());
    const filename = `dayvault-proposal-${id}.json`;
    const file = path.join(this.outboxPath, filename);
    await this.checkOutbox();
    let handle;
    try { handle = await fs.open(file, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600); }
    catch (error) {
      if (error.code !== "EEXIST") throw fileError();
      // Do not overwrite. A retry may return only a matching, valid private regular file.
      const info = await inspectPath(file);
      if ((info.mode & 0o077) !== 0) throw fileError();
      const previous = validateProposal(decodeJSON(await boundedRead(file, LIMITS.proposalBytes), LIMITS.proposalBytes), this.now());
      const { createdAt: ignoredOldTime, ...previousBody } = previous;
      const { createdAt: ignoredNewTime, ...newBody } = proposal;
      if (JSON.stringify(previousBody) !== JSON.stringify(newBody)) throw new ExchangeError("FILE_CONFLICT", "已有草案文件内容不同。未覆盖任何文件，请使用新的导出快照。");
      await this.checkOutbox();
      return { proposal: previous, filename, reused: true, requiresAppConfirmation: true };
    }
    try {
      await this.checkOutbox();
      await handle.writeFile(JSON.stringify(proposal, null, 2) + "\n", "utf8");
      await handle.sync();
      await this.checkOutbox();
    } finally { await handle.close(); }
    return { proposal, filename, reused: false, requiresAppConfirmation: true };
  }
}
