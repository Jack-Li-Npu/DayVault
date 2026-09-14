export const LIMITS = Object.freeze({ snapshotBytes: 1024 * 1024, proposalBytes: 128 * 1024, records: 1000, items: 20 });

// Messages contain only server-authored text. Never interpolate rejected user data.
export class ExchangeError extends Error {
  constructor(code, message) { super(message); this.name = "ExchangeError"; this.code = code; }
}
const fail = (code = "INVALID_FILE") => {
  const messages = {
    INVALID_FILE: "文件格式不正确，或包含未支持的字段。",
    UNSUPPORTED_VERSION: "暂不支持此文件版本。请重新导出目标。",
    TOO_LARGE: "文件、文字或事项数量超出限制。",
    INVALID_TEXT: "文字为空、含首尾空白或控制字符，或超过长度限制。",
    INVALID_DATE: "日期、时区或日期范围不正确。",
    DUPLICATE: "存在重复事项。请检查标题和日期。",
    EXPIRED: "草案已过期或生成时间不正确，请重新导出目标。",
    REST_DAY: "安排包含此目标的休息日。请调整日期。",
    DEADLINE: "安排超过此目标的截止日期。",
  };
  throw new ExchangeError(code, messages[code]);
};

export function strictKeys(value, required, optional = []) {
  if (!value || typeof value !== "object" || Array.isArray(value)) fail();
  const allowed = new Set([...required, ...optional]);
  if (required.some(key => !Object.hasOwn(value, key)) || Object.keys(value).some(key => !allowed.has(key)) ||
      Object.values(value).some(entry => entry === null)) fail();
}

export function textValue(value, limit) {
  if (typeof value !== "string" || !value || value !== value.trim() || [...value].length > limit ||
      /[\p{Cc}\p{Cf}\p{Cs}]/u.test(value)) fail("INVALID_TEXT");
  return value;
}

function titleDateKey(item) {
  // Swift String equality is canonically equivalent; preserve original text, normalize only comparison keys.
  return `${item.date}\n${item.title.toLowerCase().normalize("NFC")}`;
}

function uuid(value) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) fail();
  return value.toLowerCase();
}

export function validZone(value) {
  if (typeof value !== "string" || !value || /^[+-]/.test(value)) fail("INVALID_DATE");
  try { new Intl.DateTimeFormat("en", { timeZone: value }).format(0); } catch { fail("INVALID_DATE"); }
  return value;
}

export function dayInZone(instant, zone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: validZone(zone), year: "numeric", month: "2-digit", day: "2-digit", calendar: "gregory",
  }).formatToParts(instant);
  const get = type => parts.find(part => part.type === type).value;
  return `${get("year").padStart(4, "0")}-${get("month")}-${get("day")}`;
}

function utcDay(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail("INVALID_DATE");
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(12, 0, 0, 0);
  if (year < 1 || date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) fail("INVALID_DATE");
  return date;
}

export function validDay(value, zone = "UTC") {
  const noon = utcDay(value);
  validZone(zone);
  // Round trip an actual local day as well as Gregorian components (e.g. Samoa skipped 2011-12-30).
  for (let hours = -24; hours <= 24; hours += 6) {
    if (dayInZone(new Date(noon.valueOf() + hours * 3600000), zone) === value) return value;
  }
  fail("INVALID_DATE");
}

export function addDays(value, count) {
  const date = utcDay(value);
  date.setUTCDate(date.getUTCDate() + count);
  return date.toISOString().slice(0, 10);
}

export function timestamp(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?(Z|[+-]\d{2}:\d{2})$/.test(value)) fail("INVALID_DATE");
  utcDay(value.slice(0, 10));
  const [hours, minutes, seconds] = value.slice(11, 19).split(":").map(Number);
  if (hours > 23 || minutes > 59 || seconds > 59) fail("INVALID_DATE");
  if (!value.endsWith("Z")) {
    const [hoursOffset, minutesOffset] = value.slice(-5).split(":").map(Number);
    if (hoursOffset > 23 || minutesOffset > 59) fail("INVALID_DATE");
  }
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.valueOf())) fail("INVALID_DATE");
  return parsed;
}

export function decodeJSON(bytes, limit) {
  if (bytes.byteLength > limit) fail("TOO_LARGE");
  try { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
  catch { fail(); }
}

export function validateSnapshot(value) {
  strictKeys(value, ["schemaVersion", "kind", "id", "exportedAt", "goal", "window", "records"]);
  if (value.schemaVersion !== 1) fail("UNSUPPORTED_VERSION");
  if (value.kind !== "dayvault.snapshot") fail();
  if (Buffer.byteLength(JSON.stringify(value)) > LIMITS.snapshotBytes) fail("TOO_LARGE");
  uuid(value.id); timestamp(value.exportedAt);
  const goal = value.goal;
  strictKeys(goal, ["id", "title", "timeZoneID", "restWeekdays"], ["weeklyTargetDays", "deadlineDate"]);
  uuid(goal.id); textValue(goal.title, 500); validZone(goal.timeZoneID);
  if (!Array.isArray(goal.restWeekdays) || goal.restWeekdays.some(day => !Number.isInteger(day) || day < 1 || day > 7) ||
      new Set(goal.restWeekdays).size !== goal.restWeekdays.length) fail("INVALID_DATE");
  if (goal.weeklyTargetDays !== undefined && (!Number.isInteger(goal.weeklyTargetDays) || goal.weeklyTargetDays < 1 || goal.weeklyTargetDays > 7)) fail("INVALID_DATE");
  if (goal.deadlineDate !== undefined) validDay(goal.deadlineDate, goal.timeZoneID);
  strictKeys(value.window, ["startDate", "endDate"]);
  const start = validDay(value.window.startDate, goal.timeZoneID);
  const end = validDay(value.window.endDate, goal.timeZoneID);
  if (end < start || end > addDays(start, 44)) fail("INVALID_DATE");
  if (!Array.isArray(value.records)) fail();
  if (value.records.length > LIMITS.records) fail("TOO_LARGE");
  const ids = new Set();
  for (const record of value.records) {
    strictKeys(record, ["id", "itemID", "title", "date", "status", "timePrecision"]);
    textValue(record.id, 500); uuid(record.itemID); textValue(record.title, 120);
    validDay(record.date, goal.timeZoneID);
    if (record.date < start || record.date > end || !["planned", "active", "completed", "skipped", "removed"].includes(record.status) ||
        !["dateOnly", "timed", "inbox"].includes(record.timePrecision)) fail("INVALID_DATE");
    if (ids.has(record.id)) fail("DUPLICATE");
    ids.add(record.id);
  }
  return structuredClone(value);
}

export function validateProposal(value, now = new Date()) {
  strictKeys(value, ["schemaVersion", "kind", "id", "snapshotID", "goalID", "goalTitle", "timeZoneID", "createdAt", "summary", "items"]);
  if (value.schemaVersion !== 1) fail("UNSUPPORTED_VERSION");
  if (value.kind !== "dayvault.proposal") fail();
  if (Buffer.byteLength(JSON.stringify(value)) > LIMITS.proposalBytes) fail("TOO_LARGE");
  for (const field of ["id", "snapshotID", "goalID"]) uuid(value[field]);
  textValue(value.goalTitle, 500); textValue(value.summary, 500); validZone(value.timeZoneID);
  const created = timestamp(value.createdAt);
  if (!Number.isFinite(now.valueOf())) fail("INVALID_DATE");
  if (created - now > 300000 || now - created > 7 * 86400000) fail("EXPIRED");
  if (!Array.isArray(value.items) || value.items.length < 1 || value.items.length > LIMITS.items) fail("TOO_LARGE");
  const today = dayInZone(now, value.timeZoneID);
  const last = addDays(today, 14);
  const ids = new Set();
  const pairs = new Set();
  for (const item of value.items) {
    strictKeys(item, ["id", "title", "date"]);
    const id = uuid(item.id);
    textValue(item.title, 120); validDay(item.date, value.timeZoneID);
    if (item.date < today || item.date > last) fail("INVALID_DATE");
    const pair = titleDateKey(item);
    if (ids.has(id) || pairs.has(pair)) fail("DUPLICATE");
    ids.add(id); pairs.add(pair);
  }
  return structuredClone(value);
}

export function validateProposalInput(value, snapshot, now = new Date()) {
  strictKeys(value, ["summary", "items"]);
  textValue(value.summary, 500);
  if (!Array.isArray(value.items) || value.items.length < 1 || value.items.length > LIMITS.items) fail("TOO_LARGE");
  const today = dayInZone(now, snapshot.goal.timeZoneID);
  const last = addDays(today, 14);
  const pairs = new Set();
  const existing = new Set(snapshot.records.filter(record => record.status !== "removed" && record.timePrecision !== "inbox")
    .map(titleDateKey));
  for (const item of value.items) {
    strictKeys(item, ["title", "date"]);
    textValue(item.title, 120); validDay(item.date, snapshot.goal.timeZoneID);
    if (item.date < today || item.date > last) fail("INVALID_DATE");
    if (snapshot.goal.deadlineDate && item.date > snapshot.goal.deadlineDate) fail("DEADLINE");
    if (snapshot.goal.restWeekdays.includes(utcDay(item.date).getUTCDay() + 1)) fail("REST_DAY");
    const pair = titleDateKey(item);
    if (pairs.has(pair) || existing.has(pair)) fail("DUPLICATE");
    pairs.add(pair);
  }
  return structuredClone(value);
}
