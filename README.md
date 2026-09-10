# DayVault

DayVault is a native iPhone daily-routine recorder. The app opens directly on today's concise list; AI planning and a small origami companion are optional. Users can record an item with a title and date, build a plan from an imprecise goal, and collect lasting achievements and character equipment from their own records. Offline-first scheduling, private iCloud persistence, reminders and widgets remain useful without AI. The first release ships in Simplified Chinese; English copy remains in the repository for a later bilingual release. The deployment target is iOS 18 and the codebase uses Swift 6 with no third-party runtime dependencies.

## What is implemented

- Today-list first launch, with no mandatory conversation or onboarding questionnaire. **记一件事** records a task; **AI 帮我排** opens the optional goal-to-plan flow.
- The original deterministic local planner remains an explicitly labeled preview without credentials. Personal achievement design, companion conversation and AI adjustments require a working remote endpoint; they report unavailability rather than inventing an AI response.
- Calendar, Vault, Insights and settings remain secondary controls. The user's existing character is joined by an original, nonhuman origami companion for the selected goal.
- Editorial daybook with a compact date rail, chronological task rows, conflict signals, an unscheduled inbox, and no hourly ruler. Rescheduling and duration changes live in the task action sheet.
- Title-and-date creation defaults to a date-only task, without inventing a midnight appointment or estimated duration. Explicit times, inbox mode, duration, six recurrence modes, reminders, priority, notes and templates are available in advanced settings.
- One-tap start, complete, skip, remove, and tomorrow rescheduling; persistent actual start/end data and end-of-day review.
- Opt-in EventKit integration with user-selectable read-only overlays, system event editing, and an explicit independent-copy export warning.
- Actionable local notifications with Complete and Snooze actions. Item completion, skip, removal, resize, and rescheduling update pending requests.
- A versioned SwiftData/CloudKit model with a frozen V1 schema and V2 migration, storing recurring definitions plus sparse per-occurrence logs rather than infinite generated rows. Existing IDs, timestamps and achievement ownership are preserved; old tasks are not silently assigned to goals.
- All 16 visible and 8 concealed public achievements remain. Per-goal AI authorization can add at most two explicit personal milestones and one concealed surprise, evaluated locally from recorded facts using frozen count/day/cycle rules. AI does not write progress or unlock state.
- Completion uses a brief character-and-companion reaction; new achievements appear in a compact, non-interrupting summary. Personal achievement details offer a user-opened, skippable duet celebration. Previews and replays never increase progress, with Reduce Motion alternatives throughout.
- Original code-native 24-badge system, D/V monogram, unlock motion, and reproducible flat app icons; no generated or remotely hosted artwork ships in the interface.
- Original, layered streetwear avatar with breathing/blinking, four smoothly animated poses, and six achievement-earned wardrobe pieces across three slots. The Vault opens on the character studio; the complete achievement collection remains one tap away.
- Locked visible outfits can be tried on without being saved; concealed equipment withholds its name, appearance, and criteria. The studio and earned-equipment details offer a labeled, non-mutating stitching-and-dressing preview. Reduce Motion uses a short crossfade.
- Goal-scoped companion conversation cites supplied records and confirmed memories. Memory proposals require confirmation and can be edited or deleted; changing or removing cited records invalidates dependent AI text and memories.
- AI can propose moving the selected goal's unstarted occurrences within seven days. The user previews and confirms changes; the app rechecks live revisions, scope, rest and conflicts before applying a batch, and retains before/after adjustment records. It cannot use this operation to change durations, other goals or completed work.
- Outfit choices survive local relaunches, while ownership derives from existing permanent achievement records (including reconciled iCloud unlocks). Share cards are generated on-device from recorded completions and selected equipment; nothing is uploaded or posted automatically.
- StoreKit 2 lifetime Pro product with a local StoreKit configuration, verification, restore, Family Sharing configuration, transaction observation, and cached offline state.
- Pro appearance controls: five planner palettes, custom accents, three Vault treatments, three badge frames, three widget styles, and two alternate app icons.
- Simplified Chinese first-release app, permission, achievement, and widget copy; English resources remain staged for a later bilingual release.
- Interactive Home Screen widget plus accessory/Lock Screen presentation using an App Group snapshot.
- Swift Charts insights, accessibility labels, Dynamic Type, native materials, 44-point controls, and permanent dark styling for the Vault.

## Open and run

1. Open `DayVault.xcodeproj` in Xcode 26 or newer.
2. In Signing & Capabilities, select your Apple Developer team for **DayVault** and **DayVaultWidgets**.
3. Replace the placeholder bundle identifiers in `project.yml` if they are not available to your team, then run `xcodegen generate`.
4. Create matching App Group and iCloud containers, or update these values consistently:
   - App Group: `group.com.dayvault.shared`
   - CloudKit: `iCloud.com.dayvault.app`
5. Run the **DayVault** scheme on an iPhone running iOS 18 or later. The scheme already selects `Config/DayVault.storekit` for local purchase testing. Simulator builds use the local SwiftData store by default; pass `-enableCloudKitInSimulator` only for a signed CloudKit integration run.

The checked-in Xcode project is generated from `project.yml`. After changing targets, files, capabilities, or build settings, install [XcodeGen](https://github.com/yonaskolb/XcodeGen) and regenerate it:

```sh
brew install xcodegen
xcodegen generate
```

## AI planner setup

Daily recording runs immediately without AI. The original planning screen also has a labeled deterministic local preview; the companion and personal achievement generator do not substitute that preview for remote intelligence. To use a hosted model, deploy the Supabase Edge Function in `supabase/functions/generate-plan` and configure these Xcode scheme environment variables:

```text
DAYVAULT_AI_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-plan
DAYVAULT_SUPABASE_KEY=YOUR_PUBLISHABLE_KEY
# Required when unauthenticated preview mode is disabled:
DAYVAULT_SUPABASE_ACCESS_TOKEN=THE_SIGNED_IN_USER_ACCESS_TOKEN
```

Set the function secrets from `supabase/.env.example`. `OPENAI_API_KEY` stays on the server and must never be added to the iOS target. For a local prototype, set `DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW=true`. With that flag disabled, the function verifies the bearer token through Supabase Auth; the iOS client must send that access token before production deployment. Add per-user quotas at the same boundary.

The same endpoint accepts the original planner request and three versioned Journey operations. Each Journey request includes `requestID`, `goalID`, the goal title, current date/timezone and narrowly selected context. Source IDs are validated on the server and client; unknown IDs and extra response fields are rejected.

| Operation | Skill | Permitted result |
| --- | --- | --- |
| `designAchievements` | `dayvault-achievement-designer` | At most two visible definitions and one hidden definition; only `completionCount`, `activeDays`, or an already configured `completedCycles` rule; original badge-style keys only. |
| `companionReply` | `dayvault-companion` | A brief Chinese reply with source IDs and an optional, unconfirmed memory proposal; no hidden achievement rules or mutations. |
| `suggestAdjustment` | `dayvault-goal-planner` restricted adjustment mode | Known `occurrenceID` / `newStart` pairs only, within the permitted seven-day window. Date-only items remain date-only. |

The canonical instructions, rule policies, strict output schemas and Chinese contract evals live under `AI/Skills`. After editing them, regenerate both server bundles:

```sh
node Scripts/bundle-ai-skill.mjs
```

Challenge counts and popularity percentages are intentionally absent until backed by real aggregate data. The included database migration seeds the challenge definitions and exposes a popularity view without fabricating social proof.

### Local relay test

The checked-in local test path uses the user-selected third-party relay `https://api.3366.ai`, model `gpt-5.6-luna`, and `medium` reasoning through a host-side Deno proxy. The API key is kept in macOS Keychain and is never embedded in the Xcode project or app bundle. Planning sends the goal and scheduling constraints; Journey operations can additionally send selected task titles/completion dates, recent user messages from the current goal and confirmed memories. See [PRIVACY.md](PRIVACY.md) for the operation-specific data boundary. Calendar event titles, attendees, locations and notes are not included in AI requests.

> Compatibility recheck (2026-09-10, Asia/Shanghai): one minimal synthetic request asking only for `ok` was sent to `https://api.3366.ai/v1/responses`, using the existing Keychain credential, exactly `gpt-5.6-luna` and `medium`. The relay returned **HTTP 400 / model_not_supported**. No second structured-output probe was sent, no different model was substituted, and Simulator settings were untouched. Remote Journey behavior has passed local contract tests but has **not** been confirmed end-to-end through this relay. The relay account must support this exact model before remote generation can be used.

```sh
./Scripts/configure-local-ai.sh
./Scripts/run-local-ai-test.sh
```

Keep the second command running, then relaunch DayVault from Xcode. The script temporarily injects `DAYVAULT_AI_ENDPOINT=http://localhost:8000` into the booted simulator and removes it when the proxy stops. This is a local development path only; production should continue to call an authenticated server-side function.

## Verification

Run the platform-independent core suite:

```sh
swift test --package-path Packages/DayVaultCore
```

Run the app and UI suites on an installed simulator:

```sh
xcodebuild \
  -project DayVault.xcodeproj \
  -scheme DayVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

The core suite covers recurrence across month boundaries, DST, leap-day behavior, cross-day sparse occurrence overrides, 50-way overlaps, generated-plan safety validation, the 24-item catalog, exact achievement thresholds, concealed signals, and Vault Keeper category coverage. App/UI suites exercise local persistence, Today-first recording, optional planning and clarification, and the sequential Today and Calendar experiences without an hourly ruler.

Journey tests additionally cover V1→V2 disk-store migration, date-only semantics, personal-rule evaluation, delayed synchronization, source-bound AI responses and seven-day adjustments. Run the backend and Chinese contract fixtures without calling a model:

```sh
node Scripts/bundle-ai-skill.mjs
deno check supabase/functions/generate-plan/index.ts
deno test --allow-read=AI/Skills supabase/functions/_shared/*_test.ts
```

The latest isolated AI-contract verification passed 30 Deno tests (including 14 Chinese fixtures) and 9 Swift validator tests. These are deterministic validation tests, not evidence of successful live model generation or a full model-quality evaluation.

### Journey verification — 2026-09-10

- Core: **57 passed**, including an actual frozen V1 disk store migrated to V2.
- App: **40 passed**, including **25 Journey integration tests** for historical association, complete-batch sync selection, immutable unlocks, consent withdrawal/re-enabling, deleted sources, guarded adjustments and injected save-failure rollback/retry.
- UI: **15 passed** on iPhone 17 Pro / iOS 26.2, including title-only recording, no implicit midnight, optional companion setup, duet replay/skip, shared achievement collection, large text and reduced motion.
- Server: **30 passed**. The selected live relay still rejects `gpt-5.6-luna`; no fallback model was silently selected.

The final app test run rebuilt the Calendar permission/selection safeguards and fault-injection checks. Release builds omit the save-failure test hook. Real multi-device CloudKit, signed-device permission behavior and the companion-value user study remain release checks, not completed claims. See [the Chinese validation protocol](Design/Journey-Validation.md).

### Try the character studio

Run the app, then tap the small user character in today's header to open the Vault. Open **我的衣橱** to try equipment, or **看看解锁演出** to see a labeled preview without changing achievements. Complete your first actual schedule item to earn **启程护腕**, then wear it from the wardrobe. **分享形象** opens the system share sheet with a locally rendered image. The adjacent origami character opens the current goal's optional AI companion; it does not force the user into a chat.

The first six rewards reuse existing achievements: First Check → wristband, Steady Start → cap, Timekeeper I → jacket, In Rhythm → varsity jacket, Month in Motion → satchel, and a concealed achievement → concealed headwear. These are personal activity milestones, not externally verified sports results. There is no invented population percentile, multiplayer avatar ranking, cosmetic shop, or character XP economy in this increment. Wearing choices are device-local; earned eligibility follows achievement synchronization.

For an isolated simulator preview, launch with `-inMemoryStore -preview-screen vault`. Add `-preview-sample-data` for sample schedule history. Preview launches do not read or write the user's saved outfit, and no sample data is written to the normal schedule store.

Debug-only `-preview-accessibility` exercises Accessibility 3 text sizing and the avatar's reduced-motion path without changing OS preferences. The avatar UI tests retain screenshots as `.xcresult` attachments for visual review. A static original-art contact sheet is available in `Design/Previews/avatar-outfits.png`.

## Architecture

`Packages/DayVaultCore` contains domain models, versioned schema metadata, recurrence resolution, timeline placement, achievement definitions/evaluation, service protocols, and the App Group widget snapshot format. It has no UI dependency.

`DayVault` contains the SwiftUI feature screens and Apple-framework adapters. `AppModel` coordinates SwiftData persistence and derives achievement state from history on launch, so evaluator interruption cannot erase earned progress. Occurrence IDs include the original start instant and original time-zone identifier; duplicate CloudKit records are reconciled at the application layer by choosing the newest occurrence mutation and preserving existing permanent unlock state.

`DayVaultWidgets` consumes only a small JSON snapshot from the shared App Group. Its interactive completion intent records a pending occurrence ID and opens the app, which applies the mutation through the same achievement and persistence path as the main UI.

## Before TestFlight

- Register the final bundle IDs, App Group, CloudKit container, and `com.dayvault.app.pro.lifetime` product in App Store Connect.
- Set the in-app purchase’s price tier, Family Sharing, review screenshot, and localized metadata in App Store Connect; the JSON StoreKit price is for local testing only.
- Produce final App Store screenshots, preview media, and localized product-page metadata.
- Exercise the full release matrix in the product plan: denied/revoked permissions, offline and concurrent CloudKit edits, StoreKit pending/unverified cases, locked-device widget privacy, VoiceOver, large Dynamic Type, Chinese truncation, and performance data sets.
- Deploy and validate the CloudKit production schema before submitting the build.

No advertising SDK, third-party analytics, or runtime tracking dependency is included. The optional Supabase/AI relay is separate from local recording. Production AI access still requires authenticated deployment, per-user quotas, a working model account, and review of the chosen relay's data handling; failure of that service must not block ordinary recording.
