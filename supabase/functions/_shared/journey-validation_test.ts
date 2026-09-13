import {
  type JourneyRequest,
  sevenDayHorizon,
  validateJourneyRequest,
  validateJourneyResponse,
} from "./journey-validation.ts";
import { journeyBundles } from "./dayvault-journey.bundle.ts";

const goalID = "00000000-0000-4000-8000-000000000001";
const otherGoalID = "00000000-0000-4000-8000-000000000002";
function request(
  operation: JourneyRequest["operation"] = "companionReply",
): JourneyRequest {
  return {
    requestID: "00000000-0000-4000-8000-000000000003",
    operation,
    goalID,
    goalTitle: "把每周锻炼坚持下来",
    currentDate: "2026-09-10T08:00:00Z",
    timeZoneID: "Asia/Shanghai",
    message: "明天有事，能否挪一下？",
    facts: [{ id: "completed:1", text: "本目标已完成一次" }],
    confirmedMemories: [],
    allowedOccurrences: [],
    busyWindows: [],
    restWindows: [],
    achievementConsent: true,
    cycleIsConfigured: false,
  };
}
function rejected(block: () => unknown): void {
  let didThrow = false;
  try {
    block();
  } catch {
    didThrow = true;
  }
  if (!didThrow) throw new Error("Expected untrusted payload to be rejected");
}
const achievement = {
  id: "three_sessions",
  name: "走出三步",
  detail: "完成本目标的三次行动。",
  ruleType: "completionCount",
  target: 3,
  isHidden: false,
  clue: "",
  badgeStyleKey: "steps",
  sourceIDs: ["goal"],
};
function design(achievements: unknown[] = [achievement]) {
  return { skillVersion: "1.0.0", goalID, achievements };
}
function reply() {
  return {
    skillVersion: "1.0.0",
    goalID,
    text: "已记下这一次。明天的安排可以先看看再决定。",
    sourceIDs: ["completed:1", "message"],
    memoryCandidate: null,
  };
}
function timedRequest(): JourneyRequest {
  return {
    ...request("suggestAdjustment"),
    allowedOccurrences: [{
      id: "occurrence-1",
      goalID,
      start: "2026-09-11T08:00:00Z",
      durationMinutes: 30,
      isTimed: true,
      revision: "r1",
    }],
  };
}
function adjustment(newStart = "2026-09-12T08:00:00Z") {
  return {
    skillVersion: "1.0.0",
    goalID,
    summary: "将这一次挪到后天，确认后才会保存。",
    changes: [{ occurrenceID: "occurrence-1", newStart }],
    sourceIDs: ["message"],
  };
}

Deno.test("journey rejects unsupported operations, hidden rules and unconfirmed memory fields", () => {
  rejected(() =>
    validateJourneyRequest({ ...request(), operation: "unlockAchievement" })
  );
  rejected(() =>
    validateJourneyRequest({ ...request(), hiddenRules: [{ target: 3 }] })
  );
  rejected(() =>
    validateJourneyRequest({ ...request(), inferredMemories: ["用户有抑郁症"] })
  );
  rejected(() =>
    validateJourneyRequest({
      ...request("designAchievements"),
      achievementConsent: false,
    })
  );
});

Deno.test("journey rejects wrong-goal candidate occurrences and duplicate source IDs", () => {
  const value = timedRequest();
  rejected(() =>
    validateJourneyRequest({
      ...value,
      allowedOccurrences: [{
        ...value.allowedOccurrences[0],
        goalID: otherGoalID,
      }],
    })
  );
  rejected(() =>
    validateJourneyRequest({ ...request(), confirmedMemories: request().facts })
  );
});

Deno.test("designer accepts known count rules but not extra fields, owned assets or fake unlocks", () => {
  validateJourneyResponse(design(), request("designAchievements"));
  for (
    const extra of [{ unlockedAt: "2026-09-01" }, { progress: 1 }, {
      imageURL: "https://example.com/borrowed.png",
    }]
  ) {
    rejected(() =>
      validateJourneyResponse(
        design([{ ...achievement, ...extra }]),
        request("designAchievements"),
      )
    );
  }
  rejected(() =>
    validateJourneyResponse(
      design([{ ...achievement, badgeStyleKey: "steam_legendary" }]),
      request("designAchievements"),
    )
  );
  rejected(() =>
    validateJourneyResponse(
      design([{ ...achievement, ruleType: "workUntilMidnight" }]),
      request("designAchievements"),
    )
  );
});

Deno.test("designer enforces two visible, one hidden and explicit cycle configuration", () => {
  rejected(() =>
    validateJourneyResponse(
      design([achievement, { ...achievement, id: "b" }, {
        ...achievement,
        id: "c",
      }]),
      request("designAchievements"),
    )
  );
  rejected(() =>
    validateJourneyResponse(
      design([{ ...achievement, isHidden: true, clue: "换个步调" }, {
        ...achievement,
        id: "b",
        isHidden: true,
        clue: "再出发",
      }]),
      request("designAchievements"),
    )
  );
  rejected(() =>
    validateJourneyResponse(
      design([{ ...achievement, ruleType: "completedCycles" }]),
      request("designAchievements"),
    )
  );
  validateJourneyResponse(
    design([{ ...achievement, ruleType: "completedCycles" }]),
    { ...request("designAchievements"), cycleIsConfigured: true },
  );
});

Deno.test("companion source IDs are evidence-bound and empty message is not a source", () => {
  validateJourneyResponse(reply(), request());
  rejected(() =>
    validateJourneyResponse(
      { ...reply(), sourceIDs: ["other-user-progress"] },
      request(),
    )
  );
  rejected(() =>
    validateJourneyResponse(reply(), { ...request(), message: "" })
  );
  rejected(() =>
    validateJourneyResponse(
      { ...reply(), sourceIDs: ["goal", "goal"] },
      request(),
    )
  );
  rejected(() =>
    validateJourneyResponse({ ...reply(), goalID: otherGoalID }, request())
  );
  rejected(() =>
    validateJourneyResponse({ ...reply(), hiddenRule: "完成3次" }, request())
  );
});

Deno.test("adjustments only move known occurrences and never alter duration or goal", () => {
  validateJourneyResponse(adjustment(), timedRequest());
  rejected(() =>
    validateJourneyResponse({
      ...adjustment(),
      changes: [{ occurrenceID: "unknown", newStart: "2026-09-12T08:00:00Z" }],
    }, timedRequest())
  );
  rejected(() =>
    validateJourneyResponse({
      ...adjustment(),
      changes: [{ ...adjustment().changes[0], durationMinutes: 5 }],
    }, timedRequest())
  );
  rejected(() =>
    validateJourneyResponse(
      { ...adjustment(), goalID: otherGoalID },
      timedRequest(),
    )
  );
  rejected(() =>
    validateJourneyResponse({
      ...adjustment(),
      changes: [adjustment().changes[0], adjustment().changes[0]],
    }, timedRequest())
  );
});

Deno.test("adjustments enforce original and proposed seven-day bounds plus busy/rest windows", () => {
  rejected(() =>
    validateJourneyResponse(adjustment("2026-09-17T08:00:00Z"), timedRequest())
  );
  rejected(() =>
    validateJourneyResponse(adjustment("2026-09-10T07:59:00Z"), timedRequest())
  );
  rejected(() =>
    validateJourneyResponse(adjustment(), {
      ...timedRequest(),
      allowedOccurrences: [{
        ...timedRequest().allowedOccurrences[0],
        start: "2026-09-01T08:00:00Z",
      }],
    })
  );
  const blocked = [{
    start: "2026-09-12T07:55:00Z",
    end: "2026-09-12T08:10:00Z",
  }];
  rejected(() =>
    validateJourneyResponse(adjustment(), {
      ...timedRequest(),
      busyWindows: blocked,
    })
  );
  rejected(() =>
    validateJourneyResponse(adjustment(), {
      ...timedRequest(),
      restWindows: blocked,
    })
  );
});

Deno.test("adjustments check collisions against moved and retained occurrences", () => {
  const value = timedRequest();
  value.allowedOccurrences.push({
    ...value.allowedOccurrences[0],
    id: "occurrence-2",
    start: "2026-09-12T08:15:00Z",
  });
  rejected(() => validateJourneyResponse(adjustment(), value));
  validateJourneyResponse({
    ...adjustment(),
    changes: [...adjustment().changes, {
      occurrenceID: "occurrence-2",
      newStart: "2026-09-13T08:00:00Z",
    }],
  }, value);
});

Deno.test("day-only today remains date-only, and rest on the target day blocks it", () => {
  const value = {
    ...timedRequest(),
    allowedOccurrences: [{
      ...timedRequest().allowedOccurrences[0],
      isTimed: false,
      start: "2026-09-09T16:00:00Z",
    }],
  };
  validateJourneyResponse(adjustment("2026-09-09T16:00:00Z"), value);
  validateJourneyResponse(adjustment("2026-09-10T16:00:00Z"), value);
  rejected(() =>
    validateJourneyResponse(adjustment("2026-09-10T17:00:00Z"), value)
  );
  rejected(() =>
    validateJourneyResponse(adjustment("2026-09-10T16:00:00Z"), {
      ...value,
      restWindows: [{
        start: "2026-09-11T08:00:00Z",
        end: "2026-09-11T09:00:00Z",
      }],
    })
  );
});

Deno.test("seven calendar days preserves local time across a daylight-saving transition", () => {
  const before = Date.parse("2026-03-06T17:00:00Z");
  const after = sevenDayHorizon(before, "America/New_York");
  if (new Date(after).toISOString() !== "2026-03-13T16:00:00.000Z") {
    throw new Error("Expected noon in New York after DST");
  }
});

Deno.test("bundled journey skills include actual rules and strict schemas for all operations", () => {
  const expectedPromptVersions = {
    designAchievements: "1.0.2",
    companionReply: "1.0.1",
    suggestAdjustment: "1.1.1",
  };
  for (
    const operation of [
      "designAchievements",
      "companionReply",
      "suggestAdjustment",
    ] as const
  ) {
    const bundle = journeyBundles[operation];
    if (
      bundle.version !== expectedPromptVersions[operation] ||
      bundle.instructions.length < 500 ||
      bundle.schema.additionalProperties !== false
    ) throw new Error(`Missing executable skill bundle: ${operation}`);
  }
});
