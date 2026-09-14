# DayVault

A daily list and a record of what you have earned.

[简体中文](README.md) · **English**

[Getting started](#getting-started) · [Run locally](#run-locally) · [MCP setup](docs/MCP.en.md) · [Developer guide](docs/DEVELOPMENT.en.md) · [Privacy](PRIVACY.md)

![DayVault brand illustration](Design/Previews/dayvault-readme-banner.svg)

DayVault is an iPhone daily recorder with a Simplified Chinese interface. Write down what you plan to do and check it off when it is done. Completed records contribute to achievements and unlock equipment for your character. The home screen is a list; there is no required questionnaire, goal setup or chat.

The project started with a specific feeling: after months of training, reading or learning, it is satisfying to see that effort collected in one place and have something to share. The achievement gallery, original character and replayable animations are built around those records.

v1.4 disables in-app AI and adds optional local MCP file exchange. Recording, existing achievement evaluation and animation do not require AI. When you want help with planning, you can take selected records to an AI tool you already use. DayVault does not fund model calls or quietly add items to your schedule.

This is a source release, not an App Store release. The scope of the experiment is settled; that does not mean every launch check is complete, or that the repository will never receive a fix.

## Releases

- [v1.4.0](docs/releases/v1.4.0.md) (current) · Offline recording and optional MCP file exchange · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.4.0)
- [v1.3.0](docs/releases/v1.3.0.md) · Personal achievement copy · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.3.0)
- [v1.2.0](docs/releases/v1.2.0.md) · UI terminology and achievement copy · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.2.0)
- [v1.1.0](docs/releases/v1.1.0.md) · Planner instructions, connection fixes and private configuration · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.1.0)
- [v1.0.0](https://github.com/Jack-Li-Npu/DayVault/blob/v1.0.0/README.en.md) · Original version · [Release page](https://github.com/Jack-Li-Npu/DayVault/releases/tag/v1.0.0)

[All releases](https://github.com/Jack-Li-Npu/DayVault/releases)

## Screens

<table>
  <tr><th align="center">Today</th><th align="center">New item</th><th align="center">Animation replay</th></tr>
  <tr>
    <td align="center"><img src="Design/Previews/journey-today.png" width="260" alt="Historical Today screen with isolated sample records" /></td>
    <td align="center"><img src="Design/Previews/journey-editor.png" width="260" alt="Task editor with a title, date and collapsed advanced options" /></td>
    <td align="center"><img src="Design/Previews/journey-duet.png" width="260" alt="The user character and origami companion in a skippable, replayable local animation" /></td>
  </tr>
</table>

These are actual iOS Simulator captures from earlier builds, using isolated sample data. AI and chat entries shown in old screenshots have been removed. This README and the v1.4 notes describe the current features. The banner is an illustration, not an app screenshot.

## Daily recording

Save an item with just a title. Its date defaults to today. Time, duration, category, recurrence, reminders and templates stay in advanced options. Calendar, Insights, appearance and Settings have secondary entries.

An item can have a date only, a specific time, or remain unscheduled. Date-only items do not become midnight appointments or count toward time statistics and conflicts. You can mark an item complete without running a timer. Use Start when actual time matters; planned and actual intervals are stored separately.

Recurring items support single-occurrence moves. Create a goal manually to group related records. Apple Calendar overlays, reminders and widgets remain available, with optional permissions.

## Achievements and your character

The common catalog contains 24 achievements, including 8 hidden ones. Visible achievements show conditions and progress; hidden ones offer signals and clues before unlocking. Six equipment pieces are tied to common achievements. The catalog is common to all users; your records are not public.

Previously saved personal achievements still use their accepted local rules: completion counts, distinct activity days or qualifying cycles. Older records count after you confirm their goal association. Earned achievements remain yours, and later corrections are reflected in the evidence details. v1.4 does not generate new personal achievements or invent global rarity percentages.

<table>
  <tr><th align="center">Character and achievements</th><th align="center">Equipment try-on</th><th align="center">Calendar</th></tr>
  <tr>
    <td align="center"><img src="Design/Previews/readme-vault.png" width="260" alt="Earlier dark achievement screen with the original DayVault character" /></td>
    <td align="center"><img src="Design/Previews/avatar-wardrobe.png" width="260" alt="Character wardrobe distinguishing unlocked, previewable and hidden equipment" /></td>
    <td align="center"><img src="Design/Previews/readme-calendar.png" width="260" alt="Earlier Calendar screen with a month view and a sequential list" /></td>
  </tr>
</table>

These images also use sample data from earlier builds and remain as design references.

Ordinary completions have brief feedback; simultaneous unlocks are grouped. The roughly six-second duet can be skipped or replayed without adding progress. Reduce Motion uses a static result and short fade. The origami companion is locally animated, not an AI response.

Share cards can include the character, achievement, activity span and a confirmed memory you select. Preview the card before choosing where to send it. Private messages are excluded by default, and images are not uploaded automatically.

## Optional MCP access

The v1.4 MCP server targets macOS / Linux computers and tools that support local stdio MCP. Setup examples cover Codex, Claude Code and Gemini CLI. It does not read their chat histories or open a listening port on the iPhone. File-permission protection on Windows has not been verified.

<table>
  <tr><th align="center">Export a goal snapshot</th><th align="center">Confirm a proposal</th></tr>
  <tr>
    <td align="center"><img src="Design/Previews/v1.4-mcp-exchange.png" width="300" alt="v1.4 MCP file exchange screen with a seven-record sample reading goal, export preview and import entry" /></td>
    <td align="center"><img src="Design/Previews/v1.4-mcp-proposal.png" width="300" alt="v1.4 proposal preview with two dated test items, not yet saved before confirmation" /></td>
  </tr>
</table>

Actual v1.4 Simulator captures. The reading goal, seven records and two-item proposal are isolated synthetic test data, not private records or replies from a paid model session.

1. Select a goal under Settings → “MCP 文件交换” (MCP file exchange), preview its JSON snapshot and export it to your computer.
2. Your AI tool reads the snapshot through MCP and proposes new items. That tool supplies the model; its charges and data policies apply.
3. Transfer the proposal back to the iPhone. Preview it and confirm before anything is saved.

A snapshot contains the selected goal and related items from 30 days ago through 14 days ahead. Notes, conversations, memories, Calendar data and hidden achievement rules are excluded. It is neither a complete backup nor a live sync connection.

Proposals can add date-only, non-recurring items. MCP cannot complete or delete items, rewrite existing plans or unlock achievements. The app rechecks dates, rest days, deadlines and duplicates at confirmation. Instructions inside a file cannot replace that confirmation.

[Setup guide](docs/MCP.en.md) · [中文接入指南](docs/MCP.zh-CN.md) · [Data contract](docs/MCP-CONTRACT.md)

## Getting started

1. Tap “新增事项” (New item), enter a title and save.
2. Check it off when done. Tap the character to open achievements and equipment.
3. Create a goal when you need one. MCP is optional; no setup is required for ordinary use.

Disabling in-app AI does not erase accepted plans, goals, personal achievements or historical conversations. Goals with old companion records retain a history entry. The repository keeps the old proxy and instruction packages for reference; entering old credentials will not restore AI in the current app.

## Run locally

You need a Mac, Xcode 26 or newer and an iPhone simulator. The deployment target is iOS 18. The app and widgets currently use Simplified Chinese; English documentation does not imply an English-language interface.

```sh
git clone https://github.com/Jack-Li-Npu/DayVault.git
cd DayVault
open DayVault.xcodeproj
```

Choose the DayVault scheme and a simulator, then press ⌘R. No API key, Node.js installation or AI proxy is needed for the app. Physical devices require your development team, bundle IDs, App Group and CloudKit container. Run `xcodegen generate` after changing the project structure.

The app uses SwiftUI, SwiftData / CloudKit, EventKit, WidgetKit, StoreKit 2 and Swift Charts, without third-party iOS runtime packages. Recurrence and achievement rules live in `Packages/DayVaultCore`; the optional MCP server is in `MCP`.

## Verification and unfinished work

The v1.4 regression passed 71/71 Core, 76/76 App unit and integration, 22/22 UI and 33/33 MCP tests. The 98 App and UI tests had no failures or skips. The Release-configuration iOS Simulator build passed, with its version verified as 1.4.0, build 5. This is not a signed device archive. The [release notes](docs/releases/v1.4.0.md) describe the test scope and separate historical baseline. Counts from different runs are not added together.

App Store readiness still requires physical-device permissions, multi-device CloudKit, purchase sandbox checks, upgrades from actual earlier builds and lock-screen privacy validation. The local StoreKit file is not a live product. Pro remains in secondary settings; this release adds no paywall or pricing change. [Launch checklist, in Chinese](docs/APP-STORE-LAUNCH-PLAN.zh-CN.md)

## Privacy and contributions

Basic records stay on the device and, when available, in the private iCloud database. The app makes no model requests. An external AI tool may send the MCP snapshot to its model provider: a local MCP server does not make the model local. Disabling the old AI service does not withdraw data previously sent to providers. [Privacy details](PRIVACY.md)

There is no advertising SDK, third-party analytics or leaderboard. The project does not promise a hosted AI service, challenge marketplace or elaborate game economy.

The interface uses paper-like backgrounds, heavy outlines and code-drawn characters. See [ATTRIBUTIONS.md](ATTRIBUTIONS.md) for sources and [writing notes](docs/WRITING.md) for the Chinese and English copy guidelines. Include tests with behavior changes, and keep private records, snapshots and credentials out of screenshots and issues. Read the [contribution guide](CONTRIBUTING.md) and [security reporting notes](SECURITY.md) before submitting changes. The project-wide redistribution license is still awaiting confirmation; public access does not itself grant redistribution rights.
