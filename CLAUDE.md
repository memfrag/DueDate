# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

DueDate is a local-first macOS SwiftUI app for tracking subscriptions, recurring
bills, domains, and renewals. It is built on an Apparata boilerplate template.
`Docs/DueDate_Product_Specification.md` is the authoritative product spec —
consult it before changing behavior; it records the decisions the code encodes.

## Build & run

```bash
# Build (schemes have spaces + parens — quote them)
xcodebuild -project DueDate.xcodeproj -scheme "DueDate (Debug)" -destination 'platform=macOS,arch=arm64' build

# Release scheme is "DueDate (Release)"
```

- Deployment target **macOS 26**, Swift 6.2, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- App Sandbox is on with `ENABLE_OUTGOING_NETWORK_CONNECTIONS` (for exchange
  rates) already set — **no pbxproj edits are needed to add files**; the project
  uses `PBXFileSystemSynchronizedRootGroup`, so files created on disk appear in
  the target automatically.
- **No unit test target.** Verify changes by running the app — see
  `.claude/skills/verify/SKILL.md` for the build → launch → UI-drive →
  screenshot recipe (accessibility scripting + CGEvent clicks; `print()` from
  the GUI is not observable). Run in an isolated in-memory store with
  `APP_ENVIRONMENT=mock` to avoid touching real data.

Lint: SwiftLint 0.49.1 via Mint (`mint run realm/SwiftLint`), config in
`.swiftlint.yml` (allowlist of rules; `force_try`/`force_unwrapping` are errors).

Release: `DueDate/scripts/build-and-notarize.sh` archives, notarizes, builds a
DMG, signs for Sparkle, and publishes a GitHub release + appcast to
`memfrag/DueDate`. Sparkle auto-update is already wired in `Info.plist`.

## Architecture

**Dependency injection.** `AppEnvironment` (`DueDate/macOS/App Environment/`) is
the container for all shared services: the SwiftData `ModelContainer`,
`AppSettings`, `ExchangeRateService`, and `NotificationManager`. `.appEnvironment(.default)`
in `MainWindow` injects the container + services into the environment;
`AppEnvironment.mock()` gives previews/tests an in-memory container. Views reach
services via `@Environment(ExchangeRateService.self)` etc. `AppEnvironment.default`
is also read directly from `Commands` (e.g. `ExportCommands`) which don't get the
view-hierarchy environment.

**SwiftData models** live in `DueDate/All Platforms/Model/` and are
**CloudKit-compatible by construction** (v2.0 sync ships without migration): no
`@Attribute(.unique)`, all relationships optional, a default on every stored
property. This constraint is load-bearing — keep it when adding fields.

**Enum storage pattern (important).** Enums with associated values
(`BillingCycle.custom`, `RenewalMethod.other`, `ManagedThrough.other`) can't be
stored directly, so `Subscription` stores **raw scalar fields** (`statusRaw`,
`billingCycleKindRaw` + `billingCycleValue` + `billingCycleUnitRaw`,
`renewalMethodRaw` + `renewalMethodOtherLabel`, …) with computed enum wrappers in
`Subscription+Wrappers.swift`. The raw fields are `internal` **specifically so
`#Predicate` can reference them** — computed wrappers cannot appear in predicates.
Each associated-value enum has a `String`-backed `*Kind` mirror that also drives
editor `Picker`s.

**Navigation.** `Sidebar` owns an `AppNavigationModel` (`@Observable`: sidebar
selection, selected subscription id, modal editor target) injected via
`.environment`. `SidebarPane` enum drives a `NavigationSplitView` detail switch;
smart views are `SidebarPane.smartView(SmartView)`. Gotcha: a sidebar
`NavigationLink`'s `.badge()` must be applied to the link's **label**, not the
link itself, or List selection silently breaks.

**Read vs. write.** The right inspector (`SubscriptionInspector`) is strictly
read-only. All mutation goes through the modal `SubscriptionEditorView` sheet,
which edits a value-type `SubscriptionDraft` and only writes to the model on
Save (explicit commit boundary).

**Pure service layer** (`DueDate/All Platforms/Services/`), all `nonisolated`
static/pure where possible, is where the domain logic lives — prefer extending
these over inlining logic in views:
- `BillingCalculator` — monthly-equivalent / annual-projection math and
  next-billing-date advancement with **month-end clamping** (Jan 31 → Feb 28 → Mar 31).
- `RenewalScheduler` — launch-time rollover: auto-renewing subs advance to today;
  manual renewals are left overdue until the user confirms payment. Runs from
  `Sidebar.task` and on `didBecomeActiveNotification`.
- `SmartViewEvaluator` — pure membership + badge counts + the four Needs-Attention
  triggers. Smart-view filtering and badges are computed **in-memory** over one
  `@Query`, not via predicates, so the badge, filtered list, and dashboard always
  agree.
- `TotalsCalculator` / `CurrencyConverter` — convert per-subscription currencies
  into the app-wide display currency (default SEK); only Active/Paused/Cancelled-
  still-active statuses count toward totals.
- `ExchangeRateService` — daily-cached rates from the **Riksbank SWEA API**
  (`api.riksbank.se/swea/v1`, group 130), behind `ExchangeRateProviding`. Loads
  the local cache first so the UI never blanks; shows "rates as of <date>" when
  offline. Only public rate data crosses the network — no user data leaves the
  device (see spec §25).
- `NotificationManager` — idempotent `resync()` diffs a desired set of scheduled
  local notifications (stable content-derived ids) against pending ones. Call it
  after any data mutation. Permission is requested lazily on first reminder setup.
  The `UNUserNotificationCenterDelegate` is `nonisolated` and hops to MainActor,
  passing only a Sendable payload.
- `AmountParser` — locale-agnostic money parsing (accepts both `.` and `,`,
  tolerates spaces/symbols). The editor's amount field is a plain text field
  parsed through this, **not** a `.number` FormatStyle field (which mis-parses on
  non-US locales).

## Concurrency

Everything is MainActor by default (`SWIFT_DEFAULT_ACTOR_ISOLATION`). Pure
enums/services are marked `nonisolated` so they can be used off the main actor.
`nonisolated` is needed in exactly three shapes: `FileDocument` structs (hold only
pre-serialized `Data`), the notification-center delegate callbacks, and Codable
backup DTOs — all cross an isolation boundary and must be Sendable.

## Status model (spec §7)

Six statuses: `active`, `trial`, `paused`, `cancelledStillActive`,
`cancelledEnded`, `expired`. Cancelled is deliberately split: a subscription
cancelled before its paid period ends (`cancelledStillActive`, with `endDate` =
paid-through date) still counts toward totals; `cancelledEnded` is history.
`SubscriptionStatus` centralizes the `countsTowardTotals` / `isArchived` /
`allowsReminders` rules — change behavior there, not at call sites.
