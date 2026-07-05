# DueDate Product Specification

## 1. Product Overview

**DueDate** is a native macOS app for tracking subscriptions, recurring bills, renewals, and upcoming charges.

The app helps users understand what they are paying for, when each service renews, how it renews, and where it can be managed or cancelled.

### Core Promise

> Know what’s due.

### Working Description

> DueDate helps you see what you pay for, when it renews, and what needs attention before it costs you money.

### Primary Use Cases

- Track streaming subscriptions
- Track internet, cable TV, and cell phone plans
- Track domain names and hosting
- Track software licenses and SaaS tools
- Track App Store subscriptions
- Track PayPal automatic payments
- Track card-on-file subscriptions
- Track Swedish Autogiro payments
- Track annual renewals
- Get reminders before charges happen
- Understand monthly and yearly recurring spend
- Know where and how to cancel or manage a subscription

## 2. Target Users

DueDate is designed for people who have recurring expenses spread across different services and payment mechanisms.

Primary users include:

- Individuals with many digital subscriptions
- Families managing shared services
- Freelancers and consultants
- Small business owners
- Developers managing domains, hosting, software, and SaaS subscriptions
- Privacy-conscious users who prefer a local-first Mac app

The app should support both personal subscriptions and more technical/professional recurring services, such as domains, hosting, API tools, email providers, cloud storage, software licenses, and infrastructure services.

## 3. Product Positioning

DueDate should feel like a calm, practical, private Mac utility.

It should not feel like a bank app, budgeting app, or financial surveillance tool. Its focus is recurring commitments, not total personal finance.

### Positioning Statement

> DueDate is a private macOS app for tracking subscriptions, recurring bills, domains, services, and renewals. See what you pay, what renews next, and what needs your attention before it costs you money.

### Tone

- Calm
- Practical
- Private
- Native
- Trustworthy
- Lightweight
- Organized

## 4. MVP Scope

The first version should be manual-entry, local-first, and highly reliable.

### MVP Goals

A user should be able to:

- Add all recurring costs in under 15 minutes
- See monthly and annual recurring spend
- See what renews next
- Understand how each subscription renews
- Understand what payment method each subscription uses
- Receive reminders before important renewals
- Export their data
- Trust that the app keeps data private and local

### MVP Features

- Add/edit/delete subscriptions
- Sortable subscription table
- Dashboard with key totals
- Upcoming renewal timeline
- Renewal and payment tracking
- Categories
- Payment methods
- Status tracking
- Reminder notifications
- Local storage (SwiftData)
- Multi-currency support with a single display currency
- CSV/JSON export
- Settings for display currency and reminder defaults
- Opt-in sample data for first launch

### Platform Baseline

- **macOS 14+** (required by SwiftData)
- Distributed **directly** (outside the Mac App Store): Developer ID-signed, notarized, auto-updating via **Sparkle** with GitHub Releases
- **App Sandbox enabled**, with two entitlements:
  - Outgoing network connections (exchange-rate fetching only — see Section 25)
  - User notifications (reminders)

## 5. Core Concepts

DueDate should distinguish between these concepts:

### Subscription

A recurring cost or commitment, such as Netflix, internet service, a domain name, Apple Music, hosting, insurance, or a SaaS product.

### Renewal Method

How the subscription renews.

Examples:

- Manual payment
- Auto-renew
- Card on file
- Apple Pay
- PayPal automatic payment
- Apple App Store subscription
- Google Play subscription
- Autogiro
- Direct debit
- Invoice
- Bank transfer
- Unknown
- Other

### Payment Method

What actually pays for the subscription.

Examples:

- Visa debit ending in 1234
- Mastercard credit ending in 5678
- PayPal account
- Apple ID / Apple account
- Bank account via Autogiro
- Company card
- Personal debit card
- Klarna
- Invoice to email
- Other

### Managed Through

Where the subscription can be managed, changed, or cancelled.

Examples:

- Service website
- Apple App Store
- Google Play
- PayPal
- Bank / Autogiro
- Provider support
- Invoice
- Other

This is important because the place where a subscription is managed is often different from the service itself.

Example:

```text
Netflix
Renewal method: Apple App Store subscription
Payment method: Apple ID / Mastercard ending in 1234
Managed through: Apple ID Subscriptions
```

## 6. Subscription Fields

### Required Fields

- Name
- Amount
- Currency
- Billing cycle
- Next billing date

### Recommended Optional Fields

- Category
- Status
- Auto-renews
- Renewal method
- Payment method (optional by design — see Section 12)
- Managed through
- Cancellation URL
- Cancellation notes
- Website URL
- Account email
- Notes
- Reminder preference
- Tags
- Owner/person
- Business expense flag
- Contract end date
- Minimum commitment end date
- Trial end date
- Notice period

## 7. Subscription Statuses

Supported statuses:

- Active
- Trial
- Paused
- Cancelled (still active)
- Cancelled (ended)
- Expired

**Cancelled is deliberately split in two.** A subscription is often cancelled well before its paid period ends: the user has cancelled, access continues until the period runs out, and no further renewal will happen. That state is materially different from a subscription that has fully ended.

- **Cancelled (still active)** — cancelled, but the paid period has not yet run out. The subscription still represents money spent for the current period and remains part of current reality. The existing `endDate` field records the paid-through / access-until date.
- **Cancelled (ended)** — cancelled and no longer active. Kept for history.

Both cancelled statuses are set manually by the user; the app does not auto-transition between them.

### How Status Affects Totals, Filtering, and Reminders

| Status | Counts toward headline totals | Reminders fire | Default visibility |
|---|---|---|---|
| Active | Yes | Yes | Visible |
| Trial | No (shown separately via Trials Ending) | Yes (trial-end reminders) | Visible |
| Paused | Yes | No | Visible |
| Cancelled (still active) | Yes | No | Visible, with badge |
| Cancelled (ended) | No | No | History/Archive |
| Expired | No | No | History/Archive |

Headline "Monthly Total" and "Annual Projection" therefore include **Active + Paused + Cancelled (still active)** and exclude Trials, Cancelled (ended), and Expired.

## 8. Billing Cycles

DueDate should support common and custom billing intervals.

### Built-in Billing Cycles

- Weekly
- Monthly
- Quarterly
- Semiannual
- Annual

### Custom Billing Cycles

Support:

- Every N days
- Every N weeks
- Every N months
- Every N years

This avoids hardcoding assumptions that all services are monthly or annual.

## 9. Renewal and Payment Design

Renewal and payment information should be first-class, not hidden in notes.

Each subscription should include a dedicated **Renewal & Payment** section.

Example:

```text
Renewal & Payment

Renews automatically       Yes
Renewal method             Apple App Store subscription
Payment method             Apple ID / Mastercard •••• 1234
Managed through            Apple ID Subscriptions
Cancellation location      Settings > Apple ID > Subscriptions
Notice period              None
```

For a Swedish Autogiro subscription:

```text
Renewal & Payment

Renews automatically       Yes
Renewal method             Autogiro
Payment method             Handelsbanken household account
Managed through            Bank / provider
Amount type                Variable
Notice period              1 month
```

For a manually renewed domain:

```text
Renewal & Payment

Renews automatically       No
Renewal method             Manual renewal
Payment method             Visa debit •••• 1234
Managed through            Registrar website
Reminder                   30 days before due date
```

## 10. Autogiro Support

Because Autogiro is common in Sweden, it should be represented explicitly.

### Useful Autogiro Fields

- Bank
- Account alias
- Payee/company
- Mandate/reference number
- Amount type: fixed or variable
- Notice period
- Cancellation instructions
- Last confirmed date

The app should avoid storing sensitive bank account numbers. User-defined aliases are safer and usually sufficient.

Example aliases:

- Handelsbanken household account
- SEB personal account
- Nordea salary account
- Company account

## 11. App Store Subscription Support

Apple App Store subscriptions should also be explicitly supported.

### Useful App Store Fields

- Apple ID email
- Subscription group/service
- Storefront/country
- Family Sharing enabled
- Payment method behind Apple ID
- Cancellation location
- Trial end date
- Renewal reminder timing

Example:

```text
Apple Music
Renewal method: Apple App Store subscription
Payment method: Apple ID family payment method
Managed through: Apple ID > Subscriptions
```

This matters because App Store subscriptions are usually cancelled through Apple account settings rather than through the service website.

## 12. Payment Methods

Payment methods should be reusable records.

A subscription should reference a payment method rather than storing all payment details directly.

**Payment methods are optional.** A subscription with no payment method is a valid saved state — this keeps the "add everything in 15 minutes" goal achievable. Subscriptions with an unknown payment method are flagged by the Needs Attention view (Section 23) so incomplete records get filled in over time rather than blocking entry.

### Payment Method Fields

- Display name
- Kind
- Institution name
- Last four digits, if applicable
- Expiration date, if applicable
- Notes
- Owner/person
- Archived status

### Payment Method Kinds

- Debit card
- Credit card
- Bank account
- PayPal
- Apple account
- Google account
- Invoice
- Cash
- Other

### Deleting Payment Methods

Deleting a payment method that subscriptions still reference is **blocked with a reassignment prompt**:

```text
"Visa Debit •••• 1234" is used by 5 subscriptions.
Reassign those subscriptions to another payment method, or remove
the payment method from them, before deleting.
```

This prevents silent data loss. Archiving remains available for payment methods that are no longer in use but should be preserved for history.

### Payment Method Views

DueDate should make it easy to view subscriptions by payment method.

Example:

```text
Apple App Store
  iCloud+
  Apple Music
  Fantastical

PayPal
  Spotify
  Patreon

Visa Debit •••• 1234
  Netflix
  Disney+
  Dropbox

Autogiro
  Internet
  Mobile Plan
  Electricity
```

## 13. Dashboard

The dashboard should answer the most important questions immediately:

- What am I paying per month?
- What am I paying per year?
- What renews soon?
- What needs attention?
- Which subscriptions cost the most?

### Headline Totals

"Monthly recurring spend" and "Annual projection" include subscriptions with status **Active, Paused, or Cancelled (still active)**. Trials, Cancelled (ended), and Expired are excluded (Section 7). All amounts are converted to the app's display currency (Section 24).

### Dashboard Cards

Recommended cards:

- Monthly recurring spend
- Annual projected spend
- Due in next 7 days
- Due in next 30 days
- Annual renewals coming soon
- Trials ending soon
- Auto-renewing subscriptions
- Needs attention

Example:

```text
Monthly recurring spend
SEK 4,362

Annual projection
SEK 52,344

Due in next 7 days
3 subscriptions

Due in next 30 days
8 subscriptions
```

### Dashboard Lists

Recommended lists:

- Upcoming renewals
- Largest subscriptions
- Trials ending soon
- Annual renewals
- Missing cancellation information
- Payment methods with many linked subscriptions

## 14. Main App Navigation

DueDate should use a native macOS sidebar layout.

Recommended sidebar sections:

```text
Dashboard
Subscriptions
Calendar
Reports
Payment Methods
Categories
Archive
Settings
```

Recommended smart views:

```text
Due in 7 Days
Due in 30 Days
Annual Renewals
Trials Ending
Auto-Renewing
Needs Attention
```

## 15. Subscription List

The main working view should be a sortable table.

### Suggested Columns

- Name
- Category
- Cost
- Billing cycle
- Monthly equivalent
- Next due date
- Renewal method
- Payment method
- Status

Example:

```text
Name                  Category    Cost      Cycle     Next Due      Renewal Method       Payment Method       Status
Netflix               Streaming   SEK 159   Monthly   May 24        Card on file         Visa •••• 1234       Active
Disney+               Streaming   SEK 119   Monthly   May 27        PayPal               PayPal               Active
Mobile Plan           Mobile      SEK 249   Monthly   May 28        Autogiro             Handelsbanken        Active
Domain: example.com   Domains     SEK 139   Annual    Sep 3         Manual               Visa •••• 1234       Active
```

### List Features

- Search
- Sort
- Filter
- Group by category
- Group by payment method
- Group by renewal method
- Show active/cancelled/trial filters
- Inline status indicators
- Detail inspector for selected subscription

## 16. Subscription Detail View

Selecting a subscription should show a detail inspector.

**The inspector is read-only.** Creating and editing use a modal sheet (`SubscriptionEditorView`) with the full form and explicit Save/Cancel — the `+` toolbar button and the inspector's Edit button both open it. This keeps a clear commit boundary, makes validation straightforward, and matches the narrow inspector layout.

### Detail Sections

- Overview
- Renewal & Payment
- Billing
- Reminders
- Notes
- History

### Overview Fields

- Website
- Description
- Category
- Status
- Auto-renews

### Renewal & Payment Fields

- Renewal method
- Payment method
- Managed through
- Cancellation URL
- Cancellation notes
- Notice period

### Billing Fields

- Cost
- Billing cycle
- Next due date
- Start date
- Trial end date
- Contract end date

### Reminder Fields

- Reminder timing
- Next reminder date
- Additional reminders

## 17. Calendar / Timeline View

DueDate uses an agenda/timeline-style chronological view of upcoming charges (not a month grid in v1).

Groupings:

- Today
- This week
- Later this month
- Next month
- Next 90 days
- Annual renewals

Each subscription's upcoming charges are projected **about 12 months ahead** from its next billing date and billing cycle, so annual renewals always appear in the timeline.

## 18. Reports

Reports should start simple. v1 reports are rendered with the **Charts framework**.

### MVP Reports

- Monthly equivalent spend
- Annual projected spend
- Spend by category
- Spend by payment method
- Spend by renewal method
- Active vs cancelled subscriptions
- Annual renewals by month

### Future Reports

- Price history
- Spend change over time
- Category trend
- Payment method concentration
- Forgotten or unused subscriptions
- Renewal risk

## 19. Reminders and Notifications

Reminders are central to DueDate.

### Delivery Mechanics

- Reminders are delivered as **scheduled local notifications** via `UNUserNotificationCenter`, so they fire even when the app is not running.
- Notification permission is requested **the first time the user sets up a reminder**, not at app launch.
- Notifications include two actions: **Mark handled** and **Snooze**. Clicking the notification body opens the app at the subscription.
- The set of scheduled notifications is **re-synced on every app launch** and whenever a due date, reminder rule, or subscription status changes, so the pending schedule always reflects current data.
- Reminders fire only for statuses where they make sense (Section 7): Active subscriptions and Trials (trial-end reminders).

### Default Reminder Suggestions

- Monthly subscriptions: 1 day before
- Annual subscriptions: 30 days and 7 days before
- Trials: 3 days before
- Domains: 60 days, 30 days, and 7 days before
- Contract renewals: 30 days before
- Manual renewals: 14 or 30 days before

### Example Notifications

```text
Netflix renews tomorrow
SEK 159 will be charged on May 24.
```

```text
example.com renews in 30 days
Annual renewal: SEK 139 through your registrar.
```

```text
Your mobile plan renews in 6 days
Paid by Autogiro from Handelsbanken household account.
```

## 20. Categories

DueDate should include built-in categories but allow custom categories.

### Built-in Categories

- Streaming
- Internet
- Mobile
- Software
- Cloud
- Domains
- Hosting
- Utilities
- Gaming
- News
- Music
- Fitness
- Finance
- Insurance
- Membership
- Other

Categories should be editable and mergeable.

Deleting a category that subscriptions still reference is **blocked with a reassignment prompt**, the same as payment methods (Section 12): the user must reassign the affected subscriptions (or clear the category from them) first.

> **Open Question:** Should categories support icons and colors in v1? The mockup implies colored category indicators; lean yes, but confirm during design.

## 21. Domain-Specific Support

Domains are a strong use case for developers and small business owners.

### Domain Fields

- Domain name
- Registrar
- Expiration date
- Auto-renew enabled
- Renewal price
- WHOIS/privacy protection cost
- DNS provider
- Related hosting/email service
- Cancellation or transfer notes

Example:

```text
Domain: example.com
Category: Domains
Renewal method: Manual
Managed through: Registrar website
Renewal price: SEK 139/year
DNS provider: Cloudflare
Reminder: 60 days before
```

## 22. Data Model Sketch

The model is implemented in **SwiftData** and must remain **CloudKit-compatible from day one**, even though iCloud sync ships later (Section 27). Concretely:

- No `@Attribute(.unique)` constraints
- All relationships are optional
- Every stored property has a sensible default value

This makes enabling sync in v2.0 a configuration change rather than a schema migration.

### Subscription

```swift
struct Subscription {
    var id: UUID
    var name: String
    var category: Category?
    var status: SubscriptionStatus

    var amount: Decimal
    var currencyCode: String
    var billingCycle: BillingCycle

    var startDate: Date?
    var nextBillingDate: Date
    var endDate: Date?          // for Cancelled (still active): the paid-through / access-until date
    var trialEndDate: Date?
    var contractEndDate: Date?

    var autoRenews: Bool?
    var renewalMethod: RenewalMethod
    var paymentMethod: PaymentMethod?
    var managedThrough: ManagedThrough

    var accountEmail: String?
    var websiteURL: URL?
    var cancellationURL: URL?
    var cancellationNotes: String
    var noticePeriod: NoticePeriod?
    var notes: String

    var reminderRule: ReminderRule?
    var isSampleData: Bool      // flags opt-in demo entries (Section 29)

    var createdAt: Date
    var updatedAt: Date
}
```

### Billing Cycle

```swift
enum BillingCycle {
    case weekly
    case monthly
    case quarterly
    case semiAnnual
    case annual
    case custom(value: Int, unit: BillingUnit)
}


enum BillingUnit {
    case days
    case weeks
    case months
    case years
}
```

### Subscription Status

```swift
enum SubscriptionStatus {
    case active
    case trial
    case paused
    case cancelledStillActive   // cancelled, but paid period has not yet ended
    case cancelledEnded         // cancelled and no longer active
    case expired
}
```

### Renewal Method

```swift
enum RenewalMethod {
    case manual
    case autoRenew
    case cardOnFile
    case applePay
    case paypalAutomaticPayment
    case appStoreSubscription
    case googlePlaySubscription
    case autogiro
    case directDebit
    case invoice
    case bankTransfer
    case unknown
    case other(String)
}
```

### Payment Method

```swift
struct PaymentMethod {
    var id: UUID
    var displayName: String
    var kind: PaymentMethodKind
    var institutionName: String?
    var lastFour: String?
    var expirationDate: Date?
    var owner: String?
    var notes: String
    var isArchived: Bool
}


enum PaymentMethodKind {
    case debitCard
    case creditCard
    case bankAccount
    case paypal
    case appleAccount
    case googleAccount
    case invoice
    case cash
    case other
}
```

### Managed Through

```swift
enum ManagedThrough {
    case serviceWebsite
    case appleAppStore
    case googlePlay
    case paypal
    case bankOrAutogiro
    case providerSupport
    case invoice
    case other(String)
    case unknown
}
```

## 23. Key Calculations

### Monthly Equivalent

Normalize all costs into a monthly equivalent.

Examples:

- Monthly: amount
- Annual: amount / 12
- Quarterly: amount / 3
- Weekly: amount × 52 / 12
- Semiannual: amount / 6

### Annual Projection

Normalize all costs into an annual projection.

Examples:

- Monthly: amount × 12
- Annual: amount
- Quarterly: amount × 4
- Weekly: amount × 52
- Semiannual: amount × 2

Totals sum only the statuses defined in Section 7 and convert each amount to the display currency (Section 24).

### Due Date Rollover

What happens when a subscription's next billing date passes depends on how it renews. Rollover is recomputed on every app launch.

- **Auto-renewing subscriptions**: the next billing date **auto-advances by the billing cycle** (May 24 → June 24) so "what's due" stays correct with zero upkeep. Month-end dates are clamped (Jan 31 → Feb 28; a subscription anchored to the 31st bills on the last day of shorter months).
- **Manual-renewal subscriptions** (e.g. domains): the date is **not** advanced automatically, because payment isn't guaranteed to have happened. The subscription flips to an **overdue** state, appears in Needs Attention, and waits for the user to confirm they paid — confirming advances the date by one cycle.

### Upcoming Charges

Given a next billing date and billing cycle, generate upcoming charge dates roughly 12 months ahead for the calendar and reminder views (Section 17).

### Needs Attention

**v1 triggers** — a subscription appears in the Needs Attention smart view when any of these hold:

1. The next due date is within the reminder window, or a trial is ending soon
2. Missing cancellation info: no cancellation URL **and** no managed-through location stored
3. The renewal method or payment method is unknown / not set
4. A manual-renewal subscription is overdue (due date passed without payment confirmation)

**Future signals** (post-v1): large annual renewal approaching, card expiration date near, notice period longer than the reminder window, subscription not reviewed in a long time.

## 24. Technical Architecture

### Stack

- Swift
- SwiftUI
- **SwiftData** (macOS 14+ deployment target)
- UserNotifications (`UNUserNotificationCenter`)
- AppStorage / Settings scene
- **Charts framework** for v1 reports
- EventKit later for Calendar integration
- **Sparkle** for auto-updates (direct distribution)

### Storage

DueDate is a local-first app. **SwiftData** is the committed persistence layer — modern, minimal boilerplate, native `@Model`/`@Query` integration with SwiftUI, and the cleanest path to iCloud sync in v2.0. The model follows CloudKit compatibility constraints from day one (Section 22).

### Currency and Exchange Rates

- Every subscription stores its own `currencyCode`; the app has **one app-wide display currency** (default **SEK**, changeable in Settings). Dashboard totals, reports, and monthly equivalents convert each amount into the display currency.
- Exchange rates come from the **Riksbank SWEA API** (`api.riksbank.se/swea/v1`) — Sweden's central bank, anonymous access, rates quoted as SEK per unit of foreign currency. The full set of open exchange-rate series is fetched **once per day** and **cached locally**; conversions pivot through SEK. Supported currencies are those Riksbank publishes.
- When offline or the rate API is unavailable, the **cached table is used** and the UI shows "rates as of \<date\>". Totals always render; they never break or blank out for lack of connectivity.
- See Section 25 for why this is compatible with the privacy principles.

### Distribution

- Direct distribution outside the Mac App Store: Developer ID-signed, **notarized**, packaged with **Sparkle** auto-update fed by GitHub Releases.
- **App Sandbox enabled.** Entitlements are limited to outgoing network connections (rate fetching) and user notifications.

### Suggested Project Structure

```text
App
  DueDateApp.swift

Models
  Subscription.swift
  BillingCycle.swift
  Category.swift
  PaymentMethod.swift
  RenewalMethod.swift
  ManagedThrough.swift
  ReminderRule.swift

Views
  DashboardView.swift
  SubscriptionListView.swift
  SubscriptionDetailView.swift
  SubscriptionEditorView.swift
  CalendarView.swift
  ReportsView.swift
  PaymentMethodsView.swift
  SettingsView.swift

Services
  BillingCalculator.swift
  RenewalScheduler.swift
  NotificationManager.swift
  ImportExportService.swift
  CurrencyFormatter.swift
  ExchangeRateService.swift

ViewModels
  DashboardViewModel.swift
  SubscriptionListViewModel.swift
  ReportsViewModel.swift
```

## 25. Privacy Principles

DueDate should be private by default.

### Privacy Goals

- No account required
- Data stored locally by default
- No bank connection in MVP
- No email scraping in MVP
- No sensitive card or bank account numbers stored
- Export available at any time
- Optional iCloud sync later

### The One Network Call: Exchange Rates

The only network activity in v1 is the daily fetch of a **public exchange-rate table** (Section 24). This is compatible with the privacy goals because **no user data leaves the device**: the app downloads a generic rate table — it does not transmit subscription names, amounts, or anything derived from the user's data. When offline, cached rates are used and the app remains fully functional.

### Sensitive Data Guidance

The app should encourage aliases instead of sensitive details.

Examples:

- Use `Visa debit •••• 1234`, not full card number
- Use `Handelsbanken household account`, not full bank account number
- Use `Apple ID family payment method`, not detailed payment credentials

## 26. Import and Export

### MVP Export

- **JSON export** — a complete, **re-importable backup**: subscriptions, categories, payment methods, and settings, with IDs and relationships preserved. This is the format future import (v1.1+) will read back.
- **CSV export** — a flat, spreadsheet-friendly subscriptions table. Category and payment method are exported as **resolved display names** (text, not IDs), and a computed **monthly equivalent** column is included.

### Future Import

- CSV import
- JSON import (reads the backup format above)
- App Store receipt import
- Calendar import/export
- Email parsing
- Bank statement import
- PDF invoice extraction

Bank, email, and OCR integrations should not be part of the first version because they introduce privacy, trust, maintenance, and technical complexity.

## 27. Roadmap

### Version 1.0

- Native macOS SwiftUI app (macOS 14+)
- Local SwiftData database (CloudKit-ready model)
- Manual subscription entry
- Dashboard
- Sortable subscription table
- Detail inspector (read-only) + modal editor sheet
- Categories
- Payment methods
- Renewal methods
- Managed-through field
- Upcoming renewals
- Monthly/yearly totals in a display currency with daily-cached FX
- Reminder notifications with Mark handled / Snooze
- CSV/JSON export
- Settings
- Polished onboarding with opt-in sample data
- Direct distribution: notarized + Sparkle auto-update

### Version 1.1

- CSV import
- JSON import (restore from backup)
- Price history
- Calendar export
- Attachments
- Menu bar helper
- More advanced smart views
- Card expiration warnings

### Version 2.0

- iCloud sync (enabled on the already-CloudKit-compatible model)
- iOS companion app
- Smart import
- Domain-specific tracking improvements
- Shared household/business workspaces
- Advanced reporting
- Review workflow

## 28. Possible Killer Features

### Renewal Intelligence

Examples:

```text
You have 4 annual renewals in September totaling SEK 6,120.
```

```text
Your monthly recurring spend is SEK 870 higher than six months ago.
```

```text
You have 3 subscriptions without cancellation links.
```

### Cancellation Readiness

Each subscription can store:

- Cancellation URL
- Required notice period
- Contract end date
- Support phone number
- Notes from last cancellation attempt
- Managed-through location

This helps users answer:

> Where do I cancel this?

### Domain and SaaS Tracking

Domain and SaaS support can differentiate DueDate from consumer-focused subscription trackers.

Potential specialized types:

- Domain
- Hosting
- Email provider
- Cloud service
- SaaS product
- Developer tool
- App Store subscription
- Autogiro bill

## 29. Design Direction

DueDate should look and feel like a polished native macOS app.

### Recommended Layout

- Left sidebar for sections and smart views
- Main content area with dashboard or table
- Right inspector panel for selected subscription (read-only; editing via modal sheet)
- Toolbar with add, filter, view options, and search

### First Launch and Sample Data

- The empty state offers two clear paths: **"Add your first subscription"** or **"Explore with sample data"**.
- Sample data is strictly **opt-in** — nothing is seeded unless the user chooses it.
- Sample entries are visibly flagged as samples (`isSampleData`) and removable in a single action ("Remove sample data"), so demo entries can never be mistaken for or tangled with real subscriptions.

### Visual Style

- Calm colors
- Clear typography
- Rounded dashboard cards
- Native controls
- Minimal charts
- Strong table usability
- Subtle status indicators
- Clear due-date emphasis

### Mockup Direction

A likely app screen includes:

- Sidebar with Dashboard, Subscriptions, Calendar, Reports, Payment Methods, Categories
- Smart views for Due in 7 Days, Due in 30 Days, Annual Renewals, Trials Ending, Auto-Renewing, Needs Attention
- Dashboard cards for monthly total, annual projection, due soon, and due within 30 days
- Subscription table with name, category, cost, billing cycle, next due date, renewal method, payment method, and status
- Detail inspector showing Overview, Renewal & Payment, Billing, and Reminders

## 30. Resolved Decisions and Open Questions

Most of the original open questions have been resolved during specification refinement:

1. **Trials in projected spend** — No. Trials are excluded from headline totals and surfaced separately via the Trials Ending smart view (Section 7).
2. **Cancelled subscription visibility** — Split into two statuses: Cancelled (still active) stays visible and counts toward totals; Cancelled (ended) moves to history/Archive (Section 7).
3. **Payment methods required or optional** — Optional; missing payment methods are flagged via Needs Attention (Section 12).
4. **Renewal methods enum or custom** — Enum-based with an `.other(String)` escape hatch (Section 22).
5. **Calendar view style** — Agenda/timeline list in v1, no month grid (Section 17).
6. **Multiple currencies** — Yes from v1, with a single display currency and daily-cached live FX (Section 24).
7. **iCloud sync planning** — Model is CloudKit-compatible from v1; sync itself ships in v2.0 (Sections 22, 27).

Remaining open questions:

> **Open Question:** Should categories support icons and colors in v1? The mockup implies colored indicators; lean yes.

> **Open Question:** Should subscriptions support a tax/business-expense flag in v1? The field is listed as optional (Section 6) but its UI treatment is undecided.

> **Open Question:** Attachments are slated for v1.1 — confirm nothing in v1's data model needs to anticipate them.

## 31. Summary

DueDate should be a local-first macOS app that tracks recurring costs with special attention to due dates, renewal methods, payment methods, and cancellation paths.

The app becomes useful when it answers four questions clearly:

1. What am I paying for?
2. When is it due?
3. How does it renew?
4. Where do I manage or cancel it?

The strongest v1 is not a complex finance app. It is a reliable, private, well-designed recurring cost tracker that makes upcoming charges visible and actionable.
