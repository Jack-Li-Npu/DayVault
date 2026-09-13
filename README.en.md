# DayVault

Record what you do. Look back at how long you have kept at it.

[简体中文](README.md) · [v1.3 introduction](docs/releases/v1.3.0.md) · [GitHub Release](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.3.0) · [v1.2 introduction](docs/releases/v1.2.0.md) · [v1.1 introduction](docs/releases/v1.1.0.md) · [Original version](https://github.com/Jack-Li-Npu/DayVault/blob/v1.0.0/README.en.md)

![DayVault brand illustration](Design/Previews/dayvault-readme-banner.svg)

DayVault is an iPhone daily recorder with a Simplified Chinese interface. Write down a workout, a reading session or something you want to get done. Completed records contribute to achievements and unlock clothing for your character.

The idea came from wanting to share the satisfaction of sticking with something for a long time. DayVault keeps those records in an achievement collection, with short character animations and an optional AI companion. When the companion mentions your past progress, its reply should point to records you actually shared.

This is a development prototype in a public repository, not an App Store release. Recording, existing achievements and animation work offline. Live AI planning has returned useful plans, but recent tests still hit upstream HTTP 504. See the [integration record](docs/AI-PLANNER-LIVE-VALIDATION.zh-CN.md).

## A look inside

<table>
  <tr>
    <th align="center">Start with today</th>
    <th align="center">Record without a long form</th>
    <th align="center">Celebrate together</th>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/journey-today.png" width="260" alt="Chinese Today screen with a concise daily list and a small companion area" /></td>
    <td align="center"><img src="Design/Previews/journey-editor.png" width="260" alt="Chinese task editor showing a title, date and collapsed advanced options" /></td>
    <td align="center"><img src="Design/Previews/journey-duet.png" width="260" alt="Replay screen showing the DayVault character beside an original origami companion" /></td>
  </tr>
  <tr>
    <td align="center">A sequential list, without an hourly ruler.</td>
    <td align="center">Only add timing details when you need them.</td>
    <td align="center">A skippable duet, with replay that never adds progress.</td>
  </tr>
</table>

These are reused iOS Simulator captures with isolated sample data. The layout remains, while some wording has changed. The images do not show a new live AI test; the banner is a brand illustration.

## What you can do

Save an item with just a title. Its date defaults to today. Timing, recurrence, reminders and templates sit behind More settings. Calendar, Insights and appearance controls have secondary entries. There is no required questionnaire or chat.

An item can have a date only, a specific time, or stay in the inbox. Date-only items do not become midnight appointments or inflate time statistics. Mark an item complete without timing it, or use Start to record actual time separately from planned time.

Recurrence, single-occurrence moves, day review, Apple Calendar overlays, reminders and widgets remain available. Calendar and notification permissions are optional.

## Achievements and your character

The shared catalog has 24 achievements, including 8 hidden ones. Visible achievements show progress; concealed ones offer signals and clues before unlocking. Six clothing pieces are tied to shared achievements. “Shared” refers to the catalog, not public access to your records.

With your consent, AI can design up to two visible achievements and one concealed achievement for a goal. The app evaluates completion counts, distinct days or completed cycles based on your confirmed routine. Accepted rules are frozen. AI cannot award an achievement in chat or lower its conditions, and personal achievements do not affect shared equipment eligibility.

Older records count only after you associate them with a goal. Unlocked achievements remain yours; corrections to their evidence are reflected in the details.

In v1.3, personal achievement headings use milestones derived from accepted rules, such as “首次完成” (First completion) and “累计记录 7 天” (Record activity on 7 days). Cards, details and share previews use the same names, with conditions that distinguish counts, days and qualifying cycles. Existing achievements update their display without regeneration. Original AI wording remains in a collapsed detail section and stays concealed until a hidden achievement unlocks.

<table>
  <tr>
    <th align="center">Your character studio</th>
    <th align="center">A wardrobe earned through actions</th>
    <th align="center">Calendar, one level deeper</th>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/readme-vault.png" width="260" alt="Current dark DayVault Vault screen with the original character and achievement collection entry" /></td>
    <td align="center"><img src="Design/Previews/avatar-wardrobe.png" width="260" alt="DayVault wardrobe with equipment slots and achievement-linked clothing" /></td>
    <td align="center"><img src="Design/Previews/readme-calendar.png" width="260" alt="Current Chinese Calendar screen with a month view and sequential items using isolated sample data" /></td>
  </tr>
</table>

These captures also show retained features from earlier builds. The wardrobe image comes from an earlier character preview. All use sample data.

An origami companion appears alongside your character. Their duet changes after 7 and 30 distinct days recorded together. Rest does not reduce the stage, and imported history does not count as shared time. The roughly six-second sequence supports skipping, replay and Reduce Motion. Replay adds no progress. Ordinary completion uses a short response; multiple unlocks are grouped.

Share cards can include your character, an achievement, the recorded activity span and a confirmed memory you choose. Private messages are excluded by default. Cards are rendered on the device and shared only through a destination you select. There are no invented global rankings.

## Optional AI help

“智能排程” (AI scheduling) accepts a goal such as “give a talk in two weeks.” It asks one question when a necessary detail is missing, then proposes stages and near-term tasks. You review the draft before adding it to the schedule. Built-in challenges are plan templates, not live competitions or enrollment systems.

Tap the origami companion to discuss the current goal. Automatic replies appear at most once a day, with additional replies allowed for major personal achievements. Messages you initiate are not subject to that display limit. Suggested memories require confirmation and can be edited or deleted. Replies and memories with invalidated sources are withdrawn.

Adjustment proposals can move unstarted items for the current goal within the next seven days. You see the changes before approving them. The app rechecks conflicts and current records at save time. It cannot delete tasks, shorten durations, extend the deadline or change the whole recurrence rule; undo also checks later edits.

The build includes shared writing rules in actual model requests: name the action, state what counts as finished and ground praise in supplied records. Each operation keeps its response schema and permissions. See [writing notes and skill sources](docs/WRITING.md).

## Your first minute

1. Tap “新增事项” (New item), enter a title and save. You do not need a goal or AI setup.
2. Check the item when you finish. Tap your character to browse achievements and clothing.
3. Create a goal when you want to track something over time. Enable planning or companionship after reviewing what will be sent.

## Run it locally

You need a Mac, Xcode 26 or newer and an iPhone simulator. The deployment target is iOS 18+. The repository is public, but no project-wide open-source redistribution license has been granted.

```sh
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

Choose the DayVault scheme and a simulator, then press ⌘R. Basic recording needs no AI configuration. The project is checked in; use `xcodegen generate` after changing the project definition. For a physical device, configure your development team, bundle IDs, App Group and CloudKit container. The local StoreKit configuration is for purchase testing, not a live product.

Provider keys belong in server secrets or macOS Keychain. Personal endpoint and model settings go in an ignored `.env.local`. Published example addresses are not working services. [English developer guide](docs/DEVELOPMENT.en.md) / [中文开发指南](docs/DEVELOPMENT.zh-CN.md)

## Verification and limitations

The full local regression recorded on September 10, 2026 passed 57 Core, 40 App, 15 UI and 30 server tests. A later connection-fix run passed 46 server, 13 iOS unit and 2 UI tests. These runs overlap; their counts should not be added or treated as production reliability evidence.

Recent live requests still received upstream HTTP 504. Seven-day adjustment has not completed live validation. Signed-device permissions, multi-device CloudKit sync, purchase sandbox tests and the [companion-value study](Design/Journey-Validation.md) need further work. This copy revision did not rerun paid model tests.

## Under the surface

The app uses SwiftUI, SwiftData / CloudKit, EventKit, WidgetKit, StoreKit 2 and Swift Charts, with no third-party iOS runtime packages. The local `DayVaultCore` package holds recurrence, achievement rules and versioned models. The optional Deno / Supabase proxy calls the model and cannot directly change phone records.

## Privacy and ownership

Records stay on the device and, when available, in your private iCloud database. AI is enabled per goal. Other goals, the full journal and Calendar titles are not sent by default. Deleting local data does not remove data already processed by a provider; review that provider's policy before enabling it. [Privacy summary](PRIVACY.md)

There is no advertising SDK, third-party analytics, social feed or leaderboard. Pro options remain secondary, with no new startup paywall. Near-term work focuses on testing recording and companionship rather than adding a challenge marketplace, MCP or a complex game economy.

The interface uses paper-like backgrounds, heavy outlines and code-drawn characters. Sources and design references are in [ATTRIBUTIONS.md](ATTRIBUTIONS.md). Behavior changes need tests; screenshots should use isolated sample data. No project-wide open-source license has been granted, and repository access does not grant redistribution rights.
