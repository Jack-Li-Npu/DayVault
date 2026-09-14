# DayVault

Record what you do. Look back at how long you have kept at it.

[简体中文](README.md) · **English**

[Getting started](#your-first-minute) · [Run locally](#run-it-locally) · [Developer guide](docs/DEVELOPMENT.en.md)

![DayVault brand illustration](Design/Previews/dayvault-readme-banner.svg)

DayVault is an iPhone daily recorder with a Simplified Chinese interface. Write down a workout, a reading session or something you want to get done. Completed records contribute to achievements and unlock clothing for your character.

The idea came from wanting to share the satisfaction of sticking with something for a long time. The achievement collection and replayable character animations are based on the things you have recorded and completed.

The current development build no longer offers AI scheduling, chat, new personal achievement generation or adjustment proposals. It makes no model requests. Recording, existing achievement evaluation and character animations work offline; iCloud, Calendar and purchases still follow their respective settings. Goals, records and personal achievements saved in earlier builds are retained.

DayVault is not yet on the App Store. This scope change has no new release tag; the links below preserve the previously published versions.

## Releases

- [v1.3.0](docs/releases/v1.3.0.md) (latest published) · Personal achievement copy · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.3.0)
- [v1.2.0](docs/releases/v1.2.0.md) · UI terminology and achievement copy · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.2.0)
- [v1.1.0](docs/releases/v1.1.0.md) · Planner instructions, connection fixes and private configuration · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.1.0)
- [v1.0.0](https://github.com/Jack-Li-Npu/DayVault/blob/v1.0.0/README.en.md) · Original version · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.0.0)

[All releases](https://github.com/Jack-Li-Npu/DayVault/releases)

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

These are historical iOS Simulator captures with isolated sample data, kept as design references. Any AI or chat entries in them are not current features. Updated captures are still pending. The banner is a brand illustration; the origami companion is a locally animated character.

## What you can do

Save an item with just a title. Its date defaults to today. Timing, recurrence, reminders and templates sit behind More settings. Calendar, Insights and appearance controls have secondary entries. There is no required questionnaire or chat.

An item can have a date only, a specific time, or stay in the inbox. Date-only items do not become midnight appointments or inflate time statistics. Mark an item complete without timing it, or use Start to record actual time separately from planned time.

Recurrence, single-occurrence moves, day review, Apple Calendar overlays, reminders and widgets remain available. Calendar and notification permissions are optional.

## Achievements and your character

The shared catalog has 24 achievements, including 8 hidden ones. Visible achievements show progress; concealed ones offer signals and clues before unlocking. Six clothing pieces are tied to shared achievements. “Shared” refers to the catalog, not public access to your records.

Personal achievements generated and saved in earlier builds continue to be evaluated locally using their accepted rules: completion counts, distinct days or qualifying cycles based on a confirmed routine. Rules and earned achievements are retained. Personal achievements do not affect shared equipment eligibility. This build does not generate new personal achievements.

Older records count only after you associate them with a goal. Unlocked achievements remain yours; corrections to their evidence are reflected in the details.

Personal achievement headings keep the rule-based milestones introduced in v1.3, such as “首次完成” (First completion) and “累计记录 7 天” (Record activity on 7 days). Cards, details and share previews use the same names, with conditions that distinguish counts, days and qualifying cycles. Previously generated wording is historical content, not a new model response. Hidden achievement content remains concealed until unlocking.

<table>
  <tr>
    <th align="center">Your character studio</th>
    <th align="center">A wardrobe earned through actions</th>
    <th align="center">Calendar, one level deeper</th>
  </tr>
  <tr>
    <td align="center"><img src="Design/Previews/readme-vault.png" width="260" alt="Earlier dark DayVault Vault screen with the original character and achievement collection entry" /></td>
    <td align="center"><img src="Design/Previews/avatar-wardrobe.png" width="260" alt="DayVault wardrobe with equipment slots and achievement-linked clothing" /></td>
    <td align="center"><img src="Design/Previews/readme-calendar.png" width="260" alt="Earlier Chinese Calendar screen with a month view and sequential items using isolated sample data" /></td>
  </tr>
</table>

These captures also show retained features from earlier builds. The wardrobe image comes from an earlier character preview. All use sample data.

The origami companion appears alongside your character in local animations. Existing characters, outfits and saved performance stages remain. The roughly six-second sequence supports skipping, replay and Reduce Motion. Replay adds no progress. Ordinary completion uses brief visual feedback; multiple unlocks are grouped.

Share cards can include your character, an achievement, the recorded activity span and a confirmed memory you choose. Private messages are excluded by default. Cards are rendered on the device and shared only through a destination you select. There are no invented global rankings.

## A smaller scope

Remote AI entry points and model requests have been removed to keep ongoing service costs manageable for an individual developer. Fixed templates are not presented as AI replies, and existing records do not need an AI server to remain usable.

You can create a goal manually, link existing items, and set its weekly frequency and rest days. Previously accepted schedules, goals and personal achievements remain. Goals with saved conversations or memories expose them through the historical companion records entry, rather than the home screen. No new conversation is generated.

Pro, iCloud, Calendar and widgets are not removed by this change. They still need their respective release checks; no pricing change or new paid-service promise is being made.

AI instruction packages, proxy code and [past integration results](docs/AI-PLANNER-LIVE-VALIDATION.zh-CN.md) remain in the repository as historical development material. Model-configuration sections of the developer guides are also legacy references, not setup steps for the current app. See the [release preparation plan](docs/APP-STORE-LAUNCH-PLAN.zh-CN.md) for outstanding work.

## Your first minute

1. Tap “新增事项” (New item), enter a title and save. You do not need a goal or service configuration.
2. Check the item when you finish. Tap your character to browse achievements and clothing.
3. Use the advanced options for recurring items, or create a goal manually to group related records.

## Run it locally

You need a Mac, Xcode 26 or newer and an iPhone simulator. The deployment target is iOS 18+. The repository is public, but no project-wide open-source redistribution license has been granted.

```sh
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

Choose the DayVault scheme and a simulator, then press ⌘R. No AI proxy or API key is needed. The project is checked in; use `xcodegen generate` after changing the project definition. For a physical device, configure your development team, bundle IDs, App Group and CloudKit container. The local StoreKit configuration is for purchase testing, not a live product.

[English developer guide](docs/DEVELOPMENT.en.md) / [中文开发指南](docs/DEVELOPMENT.zh-CN.md). Their AI setup and server test instructions describe the historical implementation.

## Verification and limitations

The full local regression recorded on September 10, 2026 passed 57 Core, 40 App, 15 UI and 30 server tests. A later connection-fix run passed 46 server, 13 iOS unit and 2 UI tests. These runs overlap; their counts should not be added or treated as production reliability evidence.

On September 14, 2026, the final regression after AI removal passed 57/57 Core tests, 60/60 App unit and integration tests, and 19/19 UI tests, with no skips. The Release-configuration iOS Simulator build also succeeded. These results are separate from the historical runs above. The first UI run encountered a multiline-field lookup issue; the complete suite passed after switching to a stable identifier, retaining the save and delete assertions.

A Release Simulator build is not a signed archive or App Store approval. Signed-device permissions, multi-device CloudKit sync, purchase sandbox tests, upgrades from actual earlier builds and offline behavior still need release validation. Those checks are not marked as passed by this change.

## Under the surface

The app uses SwiftUI, SwiftData / CloudKit, EventKit, WidgetKit, StoreKit 2 and Swift Charts, with no third-party iOS runtime packages. The local `DayVaultCore` package holds recurrence, achievement rules and versioned models. The historical Deno / Supabase proxy is not a runtime dependency of the current app.

## Privacy and ownership

Records stay on the device and, when available, in your private iCloud database. The current app sends no records, goals or chat requests to a model service. Disabling AI does not withdraw data sent by earlier versions; historical copies remain subject to the provider's applicable data policy. [Privacy summary](PRIVACY.md)

There is no advertising SDK, third-party analytics, social feed or leaderboard. Pro options remain secondary, with no new startup paywall. Near-term work focuses on recording, reviewing and saving achievements, without adding a challenge marketplace, MCP or a complex game economy.

The interface uses paper-like backgrounds, heavy outlines and code-drawn characters. Sources and design references are in [ATTRIBUTIONS.md](ATTRIBUTIONS.md). Behavior changes need tests; screenshots should use isolated sample data. No project-wide open-source license has been granted, and repository access does not grant redistribution rights.
