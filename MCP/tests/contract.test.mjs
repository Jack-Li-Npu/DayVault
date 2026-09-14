import test from "node:test";
import assert from "node:assert/strict";
import { LIMITS, ExchangeError, decodeJSON, validateSnapshot, validateProposal, validateProposalInput, validDay, dayInZone, timestamp, textValue } from "../src/contract.mjs";
import { clock, fixture } from "./helpers.mjs";

const rejectsCode = (fn, code) => assert.throws(fn, error => error instanceof ExchangeError && error.code === code);

test("shared synthetic snapshot/proposal fixtures validate at the fixed clock", async () => {
  assert.equal(validateSnapshot(await fixture()).records.length, 1);
  assert.equal(validateProposal(await fixture("proposal"), clock).items.length, 1);
});

for (const kind of ["snapshot", "proposal"]) {
  test(`${kind}: rejects unsupported versions, malformed UUID, wrong kind`, async () => {
    const validate = value => kind === "snapshot" ? validateSnapshot(value) : validateProposal(value, clock);
    for (const [key, value, code] of [["schemaVersion", 2, "UNSUPPORTED_VERSION"], ["id", "not-a-uuid", "INVALID_FILE"], ["kind", "other", "INVALID_FILE"]]) {
      const input = await fixture(kind); input[key] = value;
      rejectsCode(() => validate(input), code);
    }
  });
}

test("unknown snapshot fields at every layer are refused without private-text echo", async () => {
  for (const position of ["root", "goal", "window", "record"]) {
    const value = await fixture();
    const target = position === "root" ? value : position === "record" ? value.records[0] : value[position];
    target.privateDiary = "DO-NOT-ECHO-secret-diary";
    assert.throws(() => validateSnapshot(value), error => error.code === "INVALID_FILE" && !error.message.includes("DO-NOT-ECHO"));
  }
});

test("unknown proposal/tool fields cannot inject IDs, execution, paths, unlocks or precise times", async () => {
  for (const field of ["id", "path", "code", "unlockedAt", "time", "recurrence"]) {
    const snapshot = await fixture();
    const input = { summary: "阅读", items: [{ title: "阅读下一章", date: "2026-09-15", [field]: "payload" }] };
    rejectsCode(() => validateProposalInput(input, snapshot, clock), "INVALID_FILE");
  }
  const proposal = await fixture("proposal"); proposal.token = "hidden-token";
  rejectsCode(() => validateProposal(proposal, clock), "INVALID_FILE");
});

test("invalid dates, zones, leap days and a skipped local day are rejected", () => {
  for (const value of ["2026-02-29", "2024-02-30", "2026-13-01", "2026-9-14", "0000-01-01", "2026-09-31"]) rejectsCode(() => validDay(value), "INVALID_DATE");
  assert.equal(validDay("2024-02-29"), "2024-02-29");
  rejectsCode(() => validDay("2026-09-14", "Mars/Olympus"), "INVALID_DATE");
  rejectsCode(() => validDay("2011-12-30", "Pacific/Apia"), "INVALID_DATE");
  assert.equal(validDay("2026-03-08", "America/New_York"), "2026-03-08");
  assert.equal(validDay("2026-11-01", "America/New_York"), "2026-11-01");
});

test("date range uses goal timezone, including 14th day and DST", async () => {
  const value = await fixture("proposal");
  value.timeZoneID = "America/Los_Angeles";
  const now = new Date("2026-03-08T01:00:00Z");
  value.createdAt = now.toISOString();
  assert.equal(dayInZone(now, value.timeZoneID), "2026-03-07");
  for (const date of ["2026-03-07", "2026-03-21"]) { value.items[0].date = date; validateProposal(value, now); }
  for (const date of ["2026-03-06", "2026-03-22"]) { value.items[0].date = date; rejectsCode(() => validateProposal(value, now), "INVALID_DATE"); }
});

test("timestamps enforce real components and expiry/future bounds", async () => {
  for (const value of ["2026-02-30T12:00:00Z", "2026-09-14T24:00:00Z", "2026-09-14T12:60:00Z", "2026-09-14", "2026-09-14T12:00:00+24:00"]) rejectsCode(() => timestamp(value), "INVALID_DATE");
  const value = await fixture("proposal");
  for (const offset of [-7 * 86400000, 300000]) { value.createdAt = new Date(+clock + offset).toISOString(); validateProposal(value, clock); }
  for (const offset of [-7 * 86400000 - 1, 300001]) { value.createdAt = new Date(+clock + offset).toISOString(); rejectsCode(() => validateProposal(value, clock), "EXPIRED"); }
});

test("text limits count Unicode scalars and reject controls/blank/trimmed variants", () => {
  assert.equal(textValue("🙂".repeat(120), 120).length, 240);
  for (const value of ["", " title", "title ", "a\nb", "a\u200bb", "🙂".repeat(121), "\ud800"]) rejectsCode(() => textValue(value, 120), "INVALID_TEXT");
});

test("proposal duplicates use case-insensitive title/date and canonical UUID", async () => {
  const value = await fixture("proposal");
  value.items[0].title = "Read";
  value.items.push({ ...value.items[0], id: "66666666-6666-4666-8666-666666666666", title: "read" });
  rejectsCode(() => validateProposal(value, clock), "DUPLICATE");
  value.items[1].title = "Another"; value.items[1].id = value.items[0].id.toUpperCase();
  rejectsCode(() => validateProposal(value, clock), "DUPLICATE");
  value.items[0].title = "Café";
  value.items[1] = { ...value.items[1], id: "66666666-6666-4666-8666-666666666666", title: "Cafe\u0301" };
  rejectsCode(() => validateProposal(value, clock), "DUPLICATE");
  value.items.pop();
  value.items[0].title = "Cafe\u0301";
  assert.equal(validateProposal(value, clock).items[0].title, "Cafe\u0301");
  assert.equal([...value.items[0].title].length, 5);
});

test("snapshot duplicate IDs and out-of-window records are rejected", async () => {
  const value = await fixture(); value.records.push({ ...value.records[0] });
  rejectsCode(() => validateSnapshot(value), "DUPLICATE");
  value.records.pop(); value.records[0].date = "2026-09-29";
  rejectsCode(() => validateSnapshot(value), "INVALID_DATE");
  value.records = []; value.window.endDate = "2026-09-29";
  rejectsCode(() => validateSnapshot(value), "INVALID_DATE");
});

test("limits refuse overlarge bytes, counts, malformed JSON and invalid UTF8", async () => {
  rejectsCode(() => decodeJSON(Buffer.alloc(LIMITS.snapshotBytes + 1), LIMITS.snapshotBytes), "TOO_LARGE");
  rejectsCode(() => decodeJSON(Buffer.alloc(LIMITS.proposalBytes + 1), LIMITS.proposalBytes), "TOO_LARGE");
  for (const bytes of [Buffer.from("no json"), Buffer.from([0xff])]) rejectsCode(() => decodeJSON(bytes, 100), "INVALID_FILE");
  const value = await fixture(); value.records = Array.from({ length: 1001 }, (_, index) => ({ ...value.records[0], id: `record-${index}` }));
  rejectsCode(() => validateSnapshot(value), "TOO_LARGE");
  const proposal = await fixture("proposal");
  for (const count of [0, 21]) { proposal.items = Array(count).fill({}); rejectsCode(() => validateProposal(proposal, clock), "TOO_LARGE"); }
});

test("rest days, deadline and existing snapshot records constrain proposals", async () => {
  const snapshot = await fixture();
  const input = { summary: "阅读安排", items: [{ title: "下一章", date: "2026-09-19" }] };
  rejectsCode(() => validateProposalInput(input, snapshot, clock), "REST_DAY");
  snapshot.goal.deadlineDate = "2026-09-15"; input.items[0].date = "2026-09-16";
  rejectsCode(() => validateProposalInput(input, snapshot, clock), "DEADLINE");
  input.items[0] = { title: "阅读一章", date: "2026-09-14" };
  rejectsCode(() => validateProposalInput(input, snapshot, clock), "DUPLICATE");
  snapshot.records[0].title = "Café";
  input.items[0] = { title: "Cafe\u0301", date: "2026-09-14" };
  rejectsCode(() => validateProposalInput(input, snapshot, clock), "DUPLICATE");
  input.items = [{ title: "Café", date: "2026-09-15" }, { title: "Cafe\u0301", date: "2026-09-15" }];
  rejectsCode(() => validateProposalInput(input, snapshot, clock), "DUPLICATE");
  input.items.pop();
  input.items[0].title = "Cafe\u0301";
  assert.equal(validateProposalInput(input, snapshot, clock).items[0].title, "Cafe\u0301");
});

test("omitted optional goal fields are accepted, nulls and invalid frequencies refused", async () => {
  const value = await fixture(); delete value.goal.deadlineDate; delete value.goal.weeklyTargetDays;
  validateSnapshot(value);
  value.goal.weeklyTargetDays = null; rejectsCode(() => validateSnapshot(value), "INVALID_FILE");
  value.goal.weeklyTargetDays = 8; rejectsCode(() => validateSnapshot(value), "INVALID_DATE");
  value.goal.weeklyTargetDays = 5; value.goal.restWeekdays = [1, 1]; rejectsCode(() => validateSnapshot(value), "INVALID_DATE");
});

test("maximum1000 records and20 distinct items validate without silent truncation", async () => {
  const snapshot = await fixture();
  snapshot.records = Array.from({ length: 1000 }, (_, index) => ({ ...snapshot.records[0], id: `record-${index}`, title: `阅读记录${index}` }));
  assert.equal(validateSnapshot(snapshot).records.length, 1000);
  const proposal = await fixture("proposal");
  proposal.items = Array.from({ length: 20 }, (_, index) => ({
    id: `55555555-5555-4555-8555-${String(index).padStart(12, "0")}`, title: `阅读第${index + 1}节`, date: "2026-09-15",
  }));
  assert.equal(validateProposal(proposal, clock).items.length, 20);
});
