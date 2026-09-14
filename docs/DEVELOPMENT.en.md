# DayVault developer guide

> v1.4 scope (September 14, 2026): remote AI is disabled in the app. Ordinary use needs no proxy or API key. Optional local MCP uses exported goal snapshots, externally generated proposals and explicit iPhone preview and confirmation. See the [MCP guide](MCP.en.md). It does not read external chat histories or restore in-app AI scheduling.
>
> AI configuration, endpoints, old UI names and integration instructions below describe the historical implementation. Environment variables cannot re-enable it. Use the [README](../README.en.md) and MCP guide for current entries and workflows. Existing goals, records, personal achievements and companion history remain; iCloud, Calendar and StoreKit are unaffected by this scope change.
>
> Known date limitation: MCP proposals are validated and saved in the goal's time zone, while Today still selects its date range using the device time zone. A date-only item may appear on the adjacent day after cross-zone travel. This release does not claim to fix that display behavior.

> Release privacy note / 发布脱敏说明：`api.example.com`, `example-model` and legacy model labels are placeholders, not actual provider settings. 私人接口与模型仅保存在忽略的本地配置中；历史测试结论保留。

[简体中文](DEVELOPMENT.zh-CN.md) · [Project introduction](../README.en.md) · [MCP setup](MCP.en.md) · [Privacy](../PRIVACY.md)

This guide covers building, configuration, data boundaries and verification. DayVault is a native iPhone prototype, not a production-ready hosted AI service. The current app ships in Simplified Chinese; English resource files are retained but excluded from the first-release app and widget resources. English documentation does not imply an English-language app release.

## 1. Run the app without AI

### Requirements

- A Mac with Xcode 26 or newer, the Swift 6 toolchain and an installed iPhone simulator. The project was last tested with Xcode 26.2 and iOS 26.2 Simulator; its deployment target is iOS 18.
- Git and access to this repository. A private repository requires an authorized GitHub account; a `404` can mean missing access, not a missing project.
- XcodeGen is optional for opening the checked-in project, and required when regenerating it after project-structure or build-setting changes.
- Node.js, Deno and the AI proxy are **not required** for daily recording, local achievements, character previews or the ordinary iOS build. They are used for optional AI development and backend contract tests.

```sh
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

Choose the **DayVault** scheme and an installed iPhone simulator, then press **⌘R**. The first screen is today's list. Use **记一件事** to save an item with just a title; the date defaults to today. No AI account, conversation or questionnaire is required.

Simulator builds use a local SwiftData store by default. An unsigned command-line simulator build is also available:

```sh
xcodebuild \
  -project DayVault.xcodeproj \
  -scheme DayVault \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/DayVault-build \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This builds the app; use Xcode to run it. It does not validate CloudKit or physical-device signing.

### Regenerate the project when needed

[project.yml](../project.yml) is the source for the checked-in Xcode project. After adding files, changing targets, bundle IDs, capabilities or build settings, regenerate it. Settings changed only in Xcode may be overwritten by regeneration.

```sh
brew install xcodegen
xcodegen generate
```

The first command is only needed if XcodeGen is not installed. No third-party runtime dependency is added to the app.

### Isolated visual previews

In **Product → Scheme → Edit Scheme → Run → Arguments**, add the arguments below for a Debug build. Use `-inMemoryStore` whenever you add sample data: the sample-data flag by itself does not isolate persistence.

| Preview | Launch arguments |
| --- | --- |
| Empty Today screen | `-inMemoryStore` |
| Today with sample records | `-inMemoryStore -preview-sample-data` |
| Lightweight editor | `-inMemoryStore -preview-editor` |
| Character studio | `-inMemoryStore -preview-screen vault` |
| Studio with sample history | `-inMemoryStore -preview-screen vault -preview-sample-data` |
| Large-text / avatar reduced-motion preview | Add `-preview-accessibility` to an isolated preview |

The in-memory launch does not read or write the user's saved outfit or normal schedule database. The accessibility flag uses Accessibility 3 text sizing and the avatar reduced-motion path without modifying system settings; it is not a substitute for a full accessibility audit. Remove the preview arguments to return to normal persistent recording.

From Today, tap the small user character to open the Vault. **我的衣橱** offers equipment try-on, and **看看解锁演出** is a labeled, non-mutating preview. Complete a real item to earn **启程护腕**. The adjacent origami companion opens the selected goal's optional AI area. Duet replay and skipping do not add recorded days or unlock progress. Test screenshots are retained in `.xcresult` attachments; curated examples are in [Design/Previews](../Design/Previews).

## 2. Signing, Apple services and local purchases

For a physical iPhone, choose your Apple Developer team for both **DayVault** and **DayVaultWidgets** in Signing & Capabilities. The current identifiers are placeholders that must be available to your team or changed consistently:

| Capability | Current identifier | Update locations |
| --- | --- | --- |
| App bundle | `com.dayvault.app` | [project.yml](../project.yml) |
| Widget bundle | `com.dayvault.app.widgets` | [project.yml](../project.yml) |
| App Group | `group.com.dayvault.shared` | Both target entitlement files and [WidgetSnapshot.swift](../Packages/DayVaultCore/Sources/DayVaultCore/WidgetSnapshot.swift) |
| Private CloudKit container | `iCloud.com.dayvault.app` | [App entitlements](../DayVault/DayVault.entitlements) and [PersistenceController.swift](../DayVault/PersistenceController.swift) |
| Lifetime Pro product | `com.dayvault.app.pro.lifetime` | [EntitlementStore.swift](../DayVault/Services/EntitlementStore.swift), [DayVault.storekit](../Config/DayVault.storekit) and App Store Connect |

Create matching App Group and iCloud containers in the developer account. A local recording build does not require working CloudKit. The simulator opts out of CloudKit by default because an unsigned simulator lacks the required entitlement. Only add `-enableCloudKitInSimulator` for an intentionally signed CloudKit integration run. Device persistence attempts private CloudKit and falls back to the local store when container creation fails; this is not proof that every eventual synchronization failure is handled or validated.

The DayVault scheme selects [Config/DayVault.storekit](../Config/DayVault.storekit) for local purchase testing. It defines one family-shareable non-consumable at a local test price of `14.99`. StoreKit 2 handles verified transactions, restore, transaction observation and cached offline entitlement. This configuration neither creates an App Store Connect product nor sets its real price. Configure the final product, localized pricing, Family Sharing, review screenshot and metadata separately, then validate sandbox purchases before release.

Calendar access and reminders are opt-in. Selected Calendar events are read-only blocking overlays; export uses the system editor and creates an independent Calendar copy. There is no two-way synchronization promise. Widgets consume a minimal App Group JSON snapshot. Their completion intent records a pending occurrence ID and opens the app, which applies the mutation through the normal persistence and achievement path.

## 3. Optional AI configuration

### Distinguish local preview from remote AI

The original goal-planning screen provides an explicitly labeled deterministic local preview when no remote service is configured. It can demonstrate the plan-review flow without credentials. It is not model-generated advice.

Personal achievement design, companion conversation and seven-day adjustment proposals require a working remote endpoint. They return a clear unavailable/error state instead of substituting canned dialogue. Local recording, existing achievement evaluation and animation continue offline.

### Service boundary

The iOS app calls a server-side endpoint; it must never contain the upstream provider API key. The existing [generate-plan function](../supabase/functions/generate-plan/index.ts) handles the original planner request and three typed Journey operations:

| Operation | Versioned instruction package | Allowed output |
| --- | --- | --- |
| Initial planning | `dayvault-goal-planner` | A clarification or reviewable schedule plan |
| `designAchievements` | `dayvault-achievement-designer` | At most two visible and one hidden definitions, using allowed count/day/cycle rules and badge components |
| `companionReply` | `dayvault-companion` | A short Chinese response, validated source IDs and an optional unconfirmed memory proposal |
| `suggestAdjustment` | `dayvault-goal-planner`, restricted adjustment mode | Known occurrence IDs and proposed start values within the authorized window |

Canonical instructions, policies, output schemas and Chinese fixtures live in [AI/Skills](../AI/Skills). They are actually imported into the deployed function through generated TypeScript bundles, not merely kept as unused Markdown. After editing an instruction package or schema, run:

```sh
node Scripts/bundle-ai-skill.mjs
```

This regenerates `dayvault-goal-planner.bundle.ts` and `dayvault-journey.bundle.ts` in `supabase/functions/_shared`. Keep the canonical files and generated bundles consistent. The model output is an untrusted proposal: server and app validators reject unknown sources, unsupported rules, extra fields and invalid scope. The model cannot directly write progress, unlock dates, equipment ownership or executable code.

The planner instruction revision is `1.1.1`; companion and achievement-design instructions are `1.0.1`. The build includes scheduling policy, domain guidance and the existing contract, then appends the [shared writing rules](../AI/Editorial/voice.md) to all four operations. The [complete Chinese prompt](../AI/Skills/dayvault-goal-planner/PROMPT.zh-CN.md) matches the runtime input. Response schemas are unchanged. See [writing notes](WRITING.md), [planning research](AI-PLANNER-SKILL-RESEARCH.zh-CN.md) and the [earlier live integration results](AI-PLANNER-LIVE-VALIDATION.zh-CN.md). This copy revision did not rerun paid model tests.

### Local macOS relay

The existing local test configuration explicitly selects:

First create an ignored `.env.local` at the repository root and set `OPENAI_BASE_URL`, `DAYVAULT_OPENAI_MODEL` and optionally `DAYVAULT_OPENAI_REASONING_EFFORT`. Continue storing the key in Keychain. The endpoint and model below are placeholders, not a working service.

- Upstream base URL: `https://api.example.com`
- Model: `example-model`
- Reasoning effort: `medium`
- iOS development endpoint: `http://127.0.0.1:8000` (legacy loopback addresses on port 8000 normalize to IPv4 to avoid refused `::1` connections)

A model-relay timeout means the local proxy responded; restarting it is unnecessary. This differs from a local connection failure. A client wait timeout does not establish whether generation finished upstream. Error details contain only fixed categories and status codes, never request bodies or keys.

**Current compatibility result, 2026-09-10 (Asia/Shanghai):** following explicit authorization, the initial planner's schema compatibility and response transport were fixed. The synthetic six-week speech goal returned HTTP 200 through the actual proxy, with prompt version `1.1.0`; that request took 81 seconds. The relay still has intermittent gateway failures. Earlier connectivity, companion and achievement tests succeeded; the adjustment operation's `invalid_structured_output` has not been reverified. This is not a production-reliability claim. See the [detailed scope](AI-PLANNER-LIVE-VALIDATION.zh-CN.md).

Only fictional goals were sent; no personal records were transmitted and no generated test schedule was saved. An isolated simulator session also rendered a complete Chinese speech plan after retry, with server-provided model/prompt metadata. This is not production reliability verification. See the [official OpenAI model documentation](https://developers.openai.com/api/docs/models) for the protocol; actual relay compatibility is determined by live testing. This change passed **45 server tests, 8 iOS unit tests and 2 iOS UI tests**, plus type, format and syntax checks. The 142-test snapshot below is an earlier full regression run.

For local testing, install Deno and ensure `deno`, `rg` and Xcode's `xcrun` are on `PATH`. Node.js is needed to regenerate instruction bundles. Check available tools without printing environment secrets:

```sh
command -v deno
command -v node
command -v rg
xcrun --find simctl
```

Boot one iPhone simulator, then run from the repository root:

```sh
./Scripts/configure-local-ai.sh
./Scripts/run-local-ai-test.sh
```

The first script securely prompts for the provider key and stores it in macOS Keychain under service `com.dayvault.local-ai`, account `dayvault-local`; skip it if already configured. Never put the key in a command example, `.xcconfig`, screenshot or commit. The second rebuilds the current skill bundle, reads the key into the host process environment, binds the proxy to `127.0.0.1:8000`, and persists only the non-secret endpoint in the simulator. Keep that terminal open and relaunch the app from Xcode. **Starting the proxy does not prove the selected model works; remote AI sends data and may incur provider charges.**

Press **Control-C** to stop. Cleanup removes the temporary environment override but retains the app's endpoint preference. A stopped proxy produces an explicit connection error, not a demo. To intentionally restore local-demo mode, stop the proxy, remove both non-secret settings, then relaunch the app:

```sh
xcrun simctl spawn booted launchctl unsetenv DAYVAULT_AI_ENDPOINT
xcrun simctl spawn booted defaults delete com.dayvault.app aiPlannerEndpoint
```

Also check Xcode Run environment overrides if the app continues to target an old endpoint. Debug Journey clients accept loopback HTTP; normal remote configuration requires HTTPS. Unauthenticated preview mode is appropriate only for this loopback development setup, never an Internet-exposed production service.

### Hosted endpoint

Deploy the existing Supabase Edge Function with server secrets described in [supabase/.env.example](../supabase/.env.example). The example contains placeholders, not usable credentials. Code defaults, the example and the local script now select the third-party relay `https://api.example.com` and `example-model`. Server environment variables override these defaults, so existing deployments need their secrets updated separately. Do not silently switch providers or model names to hide a compatibility error. This change updates local configuration only; no remote service was deployed.

Configure these Xcode scheme environment values for development:

```text
DAYVAULT_AI_ENDPOINT=https://YOUR_PROJECT.supabase.co/functions/v1/generate-plan
DAYVAULT_SUPABASE_KEY=YOUR_PUBLISHABLE_KEY
DAYVAULT_SUPABASE_ACCESS_TOKEN=THE_SIGNED_IN_USER_ACCESS_TOKEN
```

`OPENAI_API_KEY`, `OPENAI_BASE_URL`, `DAYVAULT_OPENAI_MODEL` and `DAYVAULT_OPENAI_REASONING_EFFORT` belong on the server. Keep `DAYVAULT_ALLOW_UNAUTHENTICATED_PREVIEW=false` for authenticated deployment. The function then checks the bearer token with Supabase Auth using server-side `SUPABASE_URL` and `SUPABASE_ANON_KEY`. [supabase/config.toml](../supabase/config.toml) disables the gateway's built-in JWT check; authorization is deliberately performed in the function. Do not mistake that setting for a production authentication bypass.

The repository does **not** provide a complete production sign-in experience, token-refresh integration, deployed service, per-user quota system or abuse protection. Supply and validate those before exposing paid model calls. The challenge seed migration supplies plan templates and a popularity view; it is not evidence of live participants or rankings. No popularity numbers should be invented to fill empty data.

## 4. Data and architecture

```text
DayVault/
  Features/                 SwiftUI Today, editor, Vault, avatar, companion, settings
  Services/                 Calendar, notifications, StoreKit, planner and Journey adapters
  AppModel.swift            Recording, occurrence mutations and public achievements
  AppModelJourney.swift     Goals, personal achievements, source-bound companionship
  AppModelAdjustments.swift Preview, guarded apply and undo
  PersistenceController.swift
DayVaultWidgets/            WidgetKit and App Intent presentation
Packages/DayVaultCore/      Models, migration, recurrence, rules, validation, snapshots
AI/Skills/                 Versioned instructions, schemas and behavioral fixtures
supabase/                  Optional model proxy, validators and challenge seed migration
Scripts/                   Bundle generation, local relay and reproducible app icons
Design/                    Design references, previews and validation protocol
DayVaultTests/              App and Journey integration tests
DayVaultUITests/            Simulator interaction and accessibility-path tests
```

The core package has no UI dependency; the iOS targets use SwiftUI, SwiftData, CloudKit, EventKit, UserNotifications, WidgetKit/App Intents, StoreKit 2 and Swift Charts. There are no third-party iOS runtime packages. Character layers, origami companion, achievement badges and visual transitions are code-native; app icons can be reproduced by [generate-editorial-app-icons.swift](../Scripts/generate-editorial-app-icons.swift).

### Invariants to preserve

- **Migrate; do not reset.** [FrozenSchemaV1.swift](../Packages/DayVaultCore/Sources/DayVaultCore/FrozenSchemaV1.swift) preserves the actual old schema. [DayVaultSchema.swift](../Packages/DayVaultCore/Sources/DayVaultCore/DayVaultSchema.swift) defines V2 and its migration. Preserve existing IDs, recurrence, actual times, achievements and outfit ownership; do not “fix” migration by deleting a store.
- **Sparse occurrences.** Store recurring definitions plus logs only when an occurrence changes. Stable occurrence identity retains the original instant and time-zone identifier. UUID foreign keys avoid required relationships, and app-level deduplication reconciles CloudKit duplicates without relying on unique constraints.
- **Date precision is meaningful.** Date-only, timed and inbox entries are distinct. Date-only items do not become implicit midnight appointments and do not count toward punctuality, timed conflicts or planned-minute totals.
- **Goal identity survives planning.** `PersonalGoal` persists accepted-plan context and cadence. Items and completion logs carry stable goal IDs; historical association is explicit. A completion retains its recorded attribution instead of being guessed from a matching title.
- **Personal rules are frozen.** `PersonalAchievementDefinition` uses a separate namespace and versioned count, distinct-day or completed-cycle rules. Cycles are fixed seven-day periods when cadence is configured, not a streak that erases earlier cycles. A complete batch has at most two visible and one concealed definition. Local evaluation deduplicates valid records and excludes future records. Already earned eligibility remains permanent after edits; evidence records retain the rule and source revisions, and the UI exposes changed evidence rather than rewriting history.
- **Common and personal remain separate.** All 24 public achievements and their six equipment links remain. Personal achievements do not grant public equipment or alter common collection counts. Public unlock merging keeps the earliest valid date; synchronized historical unlocks do not replay full ceremonies. Two devices offline at once may still independently show a ceremony.
- **Shared days are not imported years.** Companion stages progress at 0, 7 and 30 distinct recorded days after accompaniment begins. Confirmed earlier history may support a personal milestone but is not presented as time spent with the companion. Absence and rest do not downgrade the character.
- **Memories have sources.** [AppModelJourney.swift](../DayVault/AppModelJourney.swift) separates supplied facts, user messages, memory proposals and confirmed memories. Source versions are checked before accepting late responses and when records change; stale derived text and memories are withdrawn. Consent withdrawal/re-enabling cannot legitimize a reply from an older consent session. Hidden rules are never supplied to ordinary companion chat.
- **Adjustments are proposals.** [AppModelAdjustments.swift](../DayVault/AppModelAdjustments.swift) limits changes to unstarted occurrences of the current goal in the next seven days. It reloads authorized Calendar busy windows, checks rest, duration, cadence, revision and conflicts, then saves a confirmed batch before updating notifications and widgets. Recurring work uses occurrence overrides. Stale proposals are rejected; undo has its own conflict and revision checks and cannot blindly overwrite newly started or edited work.

Appearance preferences are device-local. Earned outfit eligibility follows permanent achievement state, not a local purchase or cosmetic economy. On-device share cards include only the chosen content; private memories are not included by default and no automatic publishing occurs.

## 5. Privacy and security checks

Read [PRIVACY.md](../PRIVACY.md) before enabling remote AI or changing transmitted context. Local schedules, goals, achievements, evidence, messages and memories use device storage and, when configured, the user's private iCloud database. They are separate from the optional model service.

Planning may send goal text, clarification and scheduling constraints. Journey requests may send selected task titles/completion dates, recent user-authored messages for the current goal and confirmed memories. Adjustment requests add eligible occurrence timing/revisions and busy/rest windows. Calendar titles, attendees, locations and notes are not sent. Neither all goals nor a user's Codex conversation history is imported.

Hidden rules are visible to the provider during their design request, but excluded from later companion conversations. `store: false` is set on upstream Responses requests; it does not establish a third-party relay's logging, retention or training practices. Deleting local records does not promise deletion of copies already processed by an external provider.

Do not commit keys, auth tokens, local `.env` files, provisioning material, databases, logs, build products or `.xcresult` artifacts. The checked-in [ignore rules](../.gitignore) exclude common sensitive/runtime files, but are not a secret scanner. Review diffs and screenshot content before publication. There is no advertising SDK, third-party analytics or cross-app tracking package in the iOS app.

## 6. Verification

From the repository root, run the core suite on macOS:

```sh
swift test --package-path Packages/DayVaultCore
```

Run app and UI tests against an installed simulator. Substitute its name if `iPhone 17 Pro` is unavailable:

```sh
xcodebuild \
  -project DayVault.xcodeproj \
  -scheme DayVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Regenerate instruction bundles and run deterministic backend checks without sending model requests:

```sh
node Scripts/bundle-ai-skill.mjs
deno check supabase/functions/generate-plan/index.ts
deno test --allow-read=AI/Skills supabase/functions/_shared/*_test.ts
```

The **recorded 2026-09-10 run**, not a new result from this documentation update, passed:

| Suite | Recorded result | Coverage examples |
| --- | --- | --- |
| Core | 57 passed | Real V1 disk-store migration, recurrence/DST/leap days, sparse overrides, 50-way overlaps, rule thresholds, historical association and time-zone/cycle anchors |
| App | 40 passed | Includes 25 Journey integration tests: complete-batch sync, permanent unlocks, consent changes, deleted sources, guarded adjustment and save-failure rollback/retry |
| UI | 15 passed | Title-only entry, no implicit midnight, optional companion, duet replay/skip, shared collection, large text and reduced motion on iPhone 17 Pro / iOS 26.2 |
| Server | 30 passed | Includes 14 Chinese fixtures, untrusted output, forged references and configuration validation |

Total: **142 automated tests in that recorded run**. Nine Swift Journey validator tests are included in Core, not an extra nine. These are not live AI success, a deployed CI status or evidence of production readiness. Release builds omit the injected save-failure hook.

## 7. Remaining release gates

- Revalidate the chosen model through the actual relay before describing companion generation as live. Local contract fixtures cannot establish model quality or provider compatibility.
- Validate signed-device Calendar permission changes/revocation, notifications and widget behavior; test locked-device privacy.
- Test two physical devices creating/editing offline and converging through CloudKit. Deploy and validate the production schema; do not infer this from the local migration test.
- Verify StoreKit sandbox purchase, cancellation, pending/unverified transaction handling, restore, Family Sharing and offline launch with the actual App Store Connect product.
- Perform real VoiceOver reading-order checks, Chinese truncation review, Dynamic Type, Reduce Motion, contrast, sound/haptic controls and physical-device performance/energy testing.
- Prepare final App Store screenshots, preview media, product-page copy and review metadata. Repository previews are not App Store approval assets.
- Run the controlled companion-value comparison in [Design/Journey-Validation.md](../Design/Journey-Validation.md): the same animation with statistics alone versus statistics plus an evidence-based response. It is a planned user study, not a completed retention or emotional-benefit claim.

Keep ordinary recording usable when AI, iCloud, Calendar permission, notifications or purchases are unavailable. The current scope deliberately does not add leaderboards, social feeds, a challenge marketplace, psychotherapy, MCP access or a character economy.
