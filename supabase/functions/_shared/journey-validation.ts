export type JourneyOperation =
  | "designAchievements"
  | "companionReply"
  | "suggestAdjustment";
interface Fact {
  id: string;
  text: string;
}
interface BusyWindow {
  start: string;
  end: string;
}
interface Occurrence {
  id: string;
  goalID: string;
  start: string;
  durationMinutes: number;
  isTimed: boolean;
  revision: string;
}
export interface JourneyRequest {
  requestID: string;
  operation: JourneyOperation;
  goalID: string;
  goalTitle: string;
  currentDate: string;
  timeZoneID: string;
  message: string;
  facts: Fact[];
  confirmedMemories: Fact[];
  allowedOccurrences: Occurrence[];
  busyWindows: BusyWindow[];
  restWindows: BusyWindow[];
  achievementConsent: boolean;
  cycleIsConfigured: boolean;
}
export const journeyOperations = new Set<JourneyOperation>([
  "designAchievements",
  "companionReply",
  "suggestAdjustment",
]);
const badgeStyles = new Set(["crest", "orbit", "steps", "spark", "ribbon"]);
const rules = new Set(["completionCount", "activeDays", "completedCycles"]);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function fail(): never {
  throw new Error("invalid_journey_payload");
}
function record(value: unknown, keys: string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    fail();
  }
  const result = value as Record<string, unknown>;
  if (
    Object.keys(result).length !== keys.length ||
    keys.some((key) => !Object.hasOwn(result, key))
  ) fail();
  return result;
}
function string(value: unknown, max: number, allowEmpty = false): string {
  if (
    typeof value !== "string" || (!allowEmpty && !value.trim()) ||
    [...value].length > max
  ) fail();
  return value;
}
function array(value: unknown, max: number): unknown[] {
  if (!Array.isArray(value) || value.length > max) fail();
  return value;
}
function bool(value: unknown): boolean {
  if (typeof value !== "boolean") fail();
  return value;
}
function timestamp(value: unknown): string {
  const result = string(value, 40);
  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/
      .test(result) || !Number.isFinite(Date.parse(result))
  ) fail();
  return result;
}
function uuid(value: unknown): string {
  const result = string(value, 36);
  if (!uuidPattern.test(result)) fail();
  return result.toLowerCase();
}
function integer(value: unknown, max: number): number {
  if (
    typeof value !== "number" || !Number.isInteger(value) || value < 1 ||
    value > max
  ) fail();
  return value;
}
function unique(values: string[]): void {
  if (new Set(values).size !== values.length) fail();
}

export function validateJourneyRequest(value: unknown): JourneyRequest {
  const data = record(value, [
    "requestID",
    "operation",
    "goalID",
    "goalTitle",
    "currentDate",
    "timeZoneID",
    "message",
    "facts",
    "confirmedMemories",
    "allowedOccurrences",
    "busyWindows",
    "restWindows",
    "achievementConsent",
    "cycleIsConfigured",
  ]);
  const operation = string(data.operation, 30) as JourneyOperation;
  if (!journeyOperations.has(operation)) fail();
  const goalID = uuid(data.goalID);
  const timeZoneID = string(data.timeZoneID, 100);
  try {
    new Intl.DateTimeFormat("en", { timeZone: timeZoneID }).format();
  } catch {
    fail();
  }
  function facts(input: unknown, maximum: number): Fact[] {
    return array(input, maximum).map((value) => {
      const fact = record(value, ["id", "text"]);
      const id = string(fact.id, 200);
      if (id === "goal" || id === "message") fail();
      return { id, text: string(fact.text, 1000) };
    });
  }
  function windows(input: unknown): BusyWindow[] {
    return array(input, 200).map((value) => {
      const window = record(value, ["start", "end"]);
      const start = timestamp(window.start), end = timestamp(window.end);
      if (Date.parse(start) >= Date.parse(end)) fail();
      return { start, end };
    });
  }
  const result: JourneyRequest = {
    requestID: uuid(data.requestID),
    operation,
    goalID,
    timeZoneID,
    goalTitle: string(data.goalTitle, 500),
    currentDate: timestamp(data.currentDate),
    message: string(data.message, 2000, true),
    facts: facts(data.facts, 40),
    confirmedMemories: facts(data.confirmedMemories, 10),
    allowedOccurrences: array(data.allowedOccurrences, 100).map((value) => {
      const occurrence = record(value, [
        "id",
        "goalID",
        "start",
        "durationMinutes",
        "isTimed",
        "revision",
      ]);
      if (uuid(occurrence.goalID) !== goalID) fail();
      return {
        id: string(occurrence.id, 200),
        goalID,
        start: timestamp(occurrence.start),
        durationMinutes: integer(occurrence.durationMinutes, 720),
        isTimed: bool(occurrence.isTimed),
        revision: string(occurrence.revision, 200),
      };
    }),
    busyWindows: windows(data.busyWindows),
    restWindows: windows(data.restWindows),
    achievementConsent: bool(data.achievementConsent),
    cycleIsConfigured: bool(data.cycleIsConfigured),
  };
  unique([...result.facts, ...result.confirmedMemories].map((fact) => fact.id));
  unique(result.allowedOccurrences.map((occurrence) => occurrence.id));
  if (
    result.busyWindows.length + result.restWindows.length > 200 ||
    (operation === "designAchievements" && !result.achievementConsent)
  ) fail();
  return result;
}

function validateSources(value: unknown, request: JourneyRequest): void {
  const ids = array(value, 20).map((id) => string(id, 200));
  const allowed = new Set([
    "goal",
    ...(request.message.trim() ? ["message"] : []),
    ...request.facts.map((fact) => fact.id),
    ...request.confirmedMemories.map((memory) => memory.id),
  ]);
  if (!ids.length || ids.some((id) => !allowed.has(id))) fail();
  unique(ids);
}

export function validateJourneyResponse(
  value: unknown,
  request: JourneyRequest,
): Record<string, unknown> {
  const fields = request.operation === "designAchievements"
    ? ["achievements"]
    : request.operation === "companionReply"
    ? ["text", "sourceIDs", "memoryCandidate"]
    : ["summary", "changes", "sourceIDs"];
  const result = record(value, ["skillVersion", "goalID", ...fields]);
  if (
    result.skillVersion !== "1.0.0" ||
    uuid(result.goalID) !== request.goalID.toLowerCase()
  ) fail();
  if (request.operation === "designAchievements") {
    const achievements = array(result.achievements, 3);
    if (!achievements.length) fail();
    let visible = 0, hidden = 0;
    const ids: string[] = [];
    for (const value of achievements) {
      const item = record(value, [
        "id",
        "name",
        "detail",
        "ruleType",
        "target",
        "isHidden",
        "clue",
        "badgeStyleKey",
        "sourceIDs",
      ]);
      ids.push(string(item.id, 64));
      string(item.name, 40);
      string(item.detail, 300);
      integer(item.target, 1000);
      const rule = string(item.ruleType, 30);
      if (
        !rules.has(rule) ||
        (rule === "completedCycles" && !request.cycleIsConfigured) ||
        !badgeStyles.has(string(item.badgeStyleKey, 30))
      ) fail();
      const isHidden = bool(item.isHidden);
      string(item.clue, 120, !isHidden);
      if (isHidden) hidden++;
      else visible++;
      validateSources(item.sourceIDs, request);
    }
    unique(ids);
    if (visible > 2 || hidden > 1) fail();
  } else if (request.operation === "companionReply") {
    string(result.text, 600);
    if (result.memoryCandidate !== null) {
      if (!request.message.trim()) fail();
      string(result.memoryCandidate, 200);
    }
    validateSources(result.sourceIDs, request);
  } else {
    string(result.summary, 600);
    validateSources(result.sourceIDs, request);
    const changes = array(result.changes, 100).map((value) => {
      const change = record(value, ["occurrenceID", "newStart"]);
      return {
        occurrenceID: string(change.occurrenceID, 200),
        newStart: timestamp(change.newStart),
      };
    });
    unique(changes.map((change) => change.occurrenceID));
    const now = Date.parse(request.currentDate),
      horizon = sevenDayHorizon(now, request.timeZoneID);
    const byID = new Map(
      request.allowedOccurrences.map((item) => [item.id, item]),
    );
    const moved = new Map(
      changes.map((
        change,
      ) => [change.occurrenceID, Date.parse(change.newStart)]),
    );
    for (const change of changes) {
      const item = byID.get(change.occurrenceID),
        start = Date.parse(change.newStart);
      if (!item) fail();
      if (!item.isTimed) {
        const today = startOfDay(now, request.timeZoneID),
          dayHorizon = sevenDayHorizon(today, request.timeZoneID);
        if (
          Date.parse(item.start) < today ||
          Date.parse(item.start) >= dayHorizon || start < today ||
          start >= dayHorizon
        ) fail();
        const targetDay = startOfDay(start, request.timeZoneID),
          targetDayEnd = addCalendarDays(targetDay, request.timeZoneID, 1);
        if (
          request.restWindows.some((window) =>
            Date.parse(window.start) < targetDayEnd &&
            Date.parse(window.end) > targetDay
          )
        ) fail();
        const original = localParts(Date.parse(item.start), request.timeZoneID),
          target = localParts(start, request.timeZoneID);
        if (
          original.hour !== target.hour || original.minute !== target.minute ||
          original.second !== target.second
        ) fail();
        continue;
      }
      if (
        Date.parse(item.start) < now || Date.parse(item.start) >= horizon ||
        start < now || start >= horizon
      ) fail();
      const end = start + item.durationMinutes * 60_000;
      if (
        end > horizon ||
        [...request.busyWindows, ...request.restWindows].some((window) =>
          Date.parse(window.start) < end && Date.parse(window.end) > start
        )
      ) fail();
      if (
        request.allowedOccurrences.some((other) => {
          if (other.id === item.id || !other.isTimed) return false;
          const otherStart = moved.get(other.id) ?? Date.parse(other.start);
          return otherStart < end &&
            otherStart + other.durationMinutes * 60_000 > start;
        })
      ) fail();
    }
  }
  return result;
}

function localParts(
  timestamp: number,
  timeZone: string,
): Record<string, number> {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(timestamp);
  return Object.fromEntries(
    parts.filter((part) => part.type !== "literal").map((
      part,
    ) => [part.type, Number(part.value)]),
  );
}
function wallTimestamp(parts: Record<string, number>): number {
  return Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
}
export function sevenDayHorizon(now: number, timeZone: string): number {
  return addCalendarDays(now, timeZone, 7);
}
function addCalendarDays(now: number, timeZone: string, days: number): number {
  const targetWall = wallTimestamp(localParts(now, timeZone)) +
    days * 86_400_000;
  let target = now + days * 86_400_000;
  for (let attempt = 0; attempt < 3; attempt++) {
    target += targetWall - wallTimestamp(localParts(target, timeZone));
  }
  return target;
}
function startOfDay(now: number, timeZone: string): number {
  const parts = localParts(now, timeZone);
  const targetWall = Date.UTC(parts.year, parts.month - 1, parts.day);
  let target = now;
  for (let attempt = 0; attempt < 3; attempt++) {
    target += targetWall - wallTimestamp(localParts(target, timeZone));
  }
  return target - (target % 1000);
}
