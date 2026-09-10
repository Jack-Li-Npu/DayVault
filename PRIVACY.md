# DayVault privacy summary

DayVault stores schedule, completion, template, category, review, achievement and goal data on the user's device and, when available, in the user's private iCloud database. Personal achievement definitions/evidence, companion messages, memory proposals/confirmed memories and before/after adjustment records use the same persistence boundary. Ordinary recording does not require a DayVault account or a custom backend. Optional AI features use a separately configured server and model service.

Calendar access is off by default and is requested only when the user enables Calendar integration. Selected calendars are read to display blocking overlays. Export creates an independent event through Apple’s system editor.

Notification permission is requested only when the user first saves an item with a reminder. Pending notification content is managed locally by iOS.

DayVault includes no advertising SDK, third-party analytics, cross-app tracking, data brokerage, or social sharing service. StoreKit transactions are handled by Apple and only the verified Pro entitlement is cached locally.

## Optional AI and transmitted context

The first screen is the daily list, not a compulsory AI conversation. The user can open the initial planner voluntarily and can separately enable AI companionship and personal achievement design for a specific goal. Once enabled, qualifying recorded actions or milestones may trigger a limited background companion reply. Turning off that goal's AI stops new companion requests; existing schedule records and earned achievements remain usable.

The configured endpoint receives only the context needed for the requested operation:

| Operation | Data that may be sent |
| --- | --- |
| Initial goal planning | Goal text and clarification, current time/timezone/locale, daily workload totals, free/busy intervals and allowed challenge IDs. |
| Personal achievement design | Current goal ID/title, request ID, explicit goal-level authorization, selected completion facts including task titles and dates, completion count, confirmed cadence and up to ten confirmed memories. |
| Companion reply | Current goal and message, selected completion facts, up to three recent user-authored messages from that goal, and up to ten confirmed memories. The entire conversation history is not sent. |
| Adjustment proposal | Current goal and relevant facts/memories, a bounded set of eligible occurrence IDs with their timing, duration, time precision and revision, plus busy/rest intervals. Other tasks' and external calendar events' descriptive content is not supplied as adjustment context. |

Completion facts distinguish imported history from records made after companionship was enabled. They are the user's own records, not independently verified claims. The app does not send another goal's conversational history or memories. It does not read conversations from Codex or other AI tools.

Hidden personal achievement rules are created by the achievement-design request and returned to the app, so the chosen model service sees that design exchange. **Those rules, thresholds, names and clues are not subsequently included in ordinary companion/chat requests.** The app evaluates progress and unlocks locally; AI responses cannot directly grant progress, ownership or achievements. Supplied source IDs are checked, and unknown sources or unsupported fields are rejected.

Calendar titles, attendees, locations and notes are not sent to AI. Titles of the user's own DayVault tasks can be sent as selected completion facts, so users should avoid putting information they do not want shared with the configured provider into AI-enabled goals, task titles, messages or memories.

## Control over conversation and changes

An AI-proposed memory is not included in subsequent requests until the user confirms it. Users can review, edit and delete memories in **我们试过的方法**, and clear the current goal's visible conversation. Clearing a conversation is distinct from deleting unrelated confirmed memories. Minimal event-deduplication markers can remain locally to prevent the same automatic reply from being requested repeatedly. Editing or removing evidence invalidates dependent AI text and derived memories.

Schedule adjustments are suggestions only. The user must preview and confirm a batch; the app rechecks the current goal, occurrence state, revisions, seven-day window, rest and conflicts before saving. Adjustment records retain the proposed/applied before-and-after values for review and guarded reversal. An adjustment cannot change another goal, completed work, durations or achievement rules. Date-only items do not silently become timed appointments.

Character share cards are rendered on the device. The app does not upload a share card or post it publicly; the user chooses a destination in the system share sheet.

## Provider and credential boundary

The local test configuration uses a host-side Deno proxy and the user-selected third-party relay `https://api.3366.ai`, requesting `gpt-5.6-luna` with `medium` reasoning. The provider API key is held in macOS Keychain and passed to the proxy in memory; it is not embedded in the app or committed in this repository. Production AI requests should use an authenticated server. Local unauthenticated preview mode is for loopback development only.

Responses requests set `store: false`. This flag does not establish the third-party relay's retention, logging or training policy, and deleting local app data does not promise deletion of copies previously processed by that service. Review the selected provider's terms and retention controls before sending sensitive content or releasing the app.

Compatibility was rechecked on **2026-09-10 (Asia/Shanghai)** with one synthetic `ok` request and no real personal records. The relay returned **HTTP 400 / model_not_supported** for the exact requested model. No second structured request or substitute model was used. Recording remains functional while remote AI is unavailable; the app must not represent deterministic local previews as successful model responses.
