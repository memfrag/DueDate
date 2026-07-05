//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// The dashboard: headline totals, due-soon cards, upcoming renewals,
/// and largest subscriptions (spec Section 13).
struct DashboardPane: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(AppNavigationModel.self) private var navigation

    @Query private var subscriptions: [Subscription]

    private var displayCurrency: String {
        settings.displayCurrencyCode
    }

    private var table: RateTable? {
        exchangeRates.table
    }

    private var totals: SpendTotals {
        TotalsCalculator.totals(
            for: subscriptions,
            displayCurrencyCode: displayCurrency,
            table: table
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cards
                listsRow
                footnotes
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaneBackground())
        .navigationSubtitle("Dashboard")
    }

    // MARK: - Cards

    private var cards: some View {
        let due7 = TotalsCalculator.dueWithin(
            days: 7, subscriptions: subscriptions,
            displayCurrencyCode: displayCurrency, table: table
        )
        let due30 = TotalsCalculator.dueWithin(
            days: 30, subscriptions: subscriptions,
            displayCurrencyCode: displayCurrency, table: table
        )

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4),
            spacing: 14
        ) {
            DashboardCard(
                title: "Monthly Total",
                value: format(totals.monthlyTotal),
                detail: "\(totals.subscriptionCount) subscription\(totals.subscriptionCount == 1 ? "" : "s")",
                symbolName: "chart.line.uptrend.xyaxis",
                tint: .green
            )
            DashboardCard(
                title: "Annual Projection",
                value: format(totals.annualTotal),
                detail: "projected 12 months",
                symbolName: "calendar",
                tint: .blue
            )
            DashboardCard(
                title: "Due in 7 Days",
                value: format(due7.total),
                detail: "\(due7.count) subscription\(due7.count == 1 ? "" : "s")",
                symbolName: "clock.badge.exclamationmark",
                tint: .orange
            )
            DashboardCard(
                title: "Due in 30 Days",
                value: format(due30.total),
                detail: "\(due30.count) subscription\(due30.count == 1 ? "" : "s")",
                symbolName: "calendar.badge.clock",
                tint: .purple
            )
        }
    }

    // MARK: - Lists

    private var listsRow: some View {
        HStack(alignment: .top, spacing: 14) {
            upcomingRenewals
            largestSubscriptions
        }
    }

    private var upcomingRenewals: some View {
        DashboardList(title: "Upcoming Renewals", symbolName: "clock") {
            let upcoming = subscriptions
                .filter { $0.countsForUpcoming && $0.daysUntilNextBilling >= 0 }
                .sorted { $0.nextBillingDate < $1.nextBillingDate }
                .prefix(8)

            if upcoming.isEmpty {
                DashboardListEmptyRow(text: "Nothing coming up")
            } else {
                ForEach(Array(upcoming)) { subscription in
                    DashboardListRow(
                        title: subscription.name,
                        subtitle: dueText(subscription),
                        value: subscription.amount
                            .formatted(.currency(code: subscription.currencyCode))
                    ) {
                        navigation.reveal(subscriptionID: subscription.id)
                    }
                }
            }
        }
    }

    private var largestSubscriptions: some View {
        DashboardList(title: "Largest Subscriptions", symbolName: "arrow.up.right") {
            let largest = subscriptions
                .filter(\.countsTowardTotals)
                .compactMap { subscription -> (Subscription, Decimal)? in
                    guard let monthly = TotalsCalculator.convert(
                        subscription.monthlyEquivalent,
                        from: subscription.currencyCode,
                        to: displayCurrency,
                        table: table
                    ) else { return nil }
                    return (subscription, monthly)
                }
                .sorted { $0.1 > $1.1 }
                .prefix(8)

            if largest.isEmpty {
                DashboardListEmptyRow(text: "No active subscriptions")
            } else {
                ForEach(Array(largest), id: \.0.id) { subscription, monthly in
                    DashboardListRow(
                        title: subscription.name,
                        subtitle: subscription.billingCycle.displayName,
                        value: format(monthly) + "/mo"
                    ) {
                        navigation.reveal(subscriptionID: subscription.id)
                    }
                }
            }
        }
    }

    // MARK: - Footnotes

    @ViewBuilder private var footnotes: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let table, exchangeRates.isStale {
                Label(
                    "Exchange rates as of \(table.asOf.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "wifi.slash"
                )
            }
            if totals.unconvertibleCount > 0 {
                Label(
                    "\(totals.unconvertibleCount) subscription\(totals.unconvertibleCount == 1 ? "" : "s") not included (no exchange rate available)",
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Formatting

    private func format(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: displayCurrency).precision(.fractionLength(0))
        )
    }

    private func dueText(_ subscription: Subscription) -> String {
        let days = subscription.daysUntilNextBilling
        let dateText = subscription.nextBillingDate
            .formatted(.dateTime.month(.abbreviated).day())
        return switch days {
        case 0: "Today"
        case 1: "\(dateText) · tomorrow"
        default: "\(dateText) · in \(days) days"
        }
    }
}

// MARK: - Dashboard List Components

struct DashboardList<Content: View>: View {

    let title: String
    let symbolName: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbolName)
                .font(.headline)
                .padding(.bottom, 4)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DashboardListRow: View {

    let title: String
    let subtitle: String
    let value: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }
}

struct DashboardListEmptyRow: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 8)
    }
}

#Preview {
    DashboardPane()
        .environment(AppNavigationModel())
        .previewEnvironment()
        .frame(width: 900, height: 600)
}
