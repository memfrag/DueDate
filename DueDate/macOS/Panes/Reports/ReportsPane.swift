//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

/// Simple Charts-based reports (spec Section 18): spend by category,
/// payment method, and renewal method; annual renewals by month;
/// active vs cancelled counts.
struct ReportsPane: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    @Query private var subscriptions: [Subscription]

    private var displayCurrency: String {
        settings.displayCurrencyCode
    }

    var body: some View {
        Group {
            if subscriptions.isEmpty {
                ContentUnavailableView(
                    "No Data to Report",
                    systemImage: "chart.bar",
                    description: Text("Add subscriptions to see spending reports.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        headline
                        HStack(alignment: .top, spacing: 14) {
                            ReportCard(title: "Monthly Spend by Category") {
                                SpendBarChart(
                                    entries: spend(by: { $0.category?.name ?? "Uncategorized" }),
                                    currencyCode: displayCurrency
                                )
                            }
                            ReportCard(title: "Monthly Spend by Payment Method") {
                                SpendBarChart(
                                    entries: spend(by: { $0.paymentMethod?.displayName ?? "None" }),
                                    currencyCode: displayCurrency
                                )
                            }
                        }
                        HStack(alignment: .top, spacing: 14) {
                            ReportCard(title: "Monthly Spend by Renewal Method") {
                                SpendBarChart(
                                    entries: spend(by: { $0.renewalMethod.displayName }),
                                    currencyCode: displayCurrency
                                )
                            }
                            ReportCard(title: "Annual Renewals by Month") {
                                AnnualRenewalsChart(
                                    entries: annualRenewalsByMonth,
                                    currencyCode: displayCurrency
                                )
                            }
                        }
                        ReportCard(title: "Subscriptions by Status") {
                            StatusChart(entries: statusCounts)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaneBackground())
        .navigationSubtitle("Reports")
    }

    private var headline: some View {
        let totals = TotalsCalculator.totals(
            for: subscriptions,
            displayCurrencyCode: displayCurrency,
            table: exchangeRates.table
        )
        return HStack(spacing: 24) {
            LabeledContent("Monthly equivalent") {
                Text(totals.monthlyTotal.formatted(
                    .currency(code: displayCurrency).precision(.fractionLength(0))
                ))
                .fontWeight(.semibold)
                .monospacedDigit()
            }
            LabeledContent("Annual projection") {
                Text(totals.annualTotal.formatted(
                    .currency(code: displayCurrency).precision(.fractionLength(0))
                ))
                .fontWeight(.semibold)
                .monospacedDigit()
            }
        }
        .font(.callout)
    }

    // MARK: - Data

    /// Monthly-equivalent spend in the display currency, grouped by a key.
    private func spend(by key: (Subscription) -> String) -> [SpendEntry] {
        var totals: [String: Decimal] = [:]
        for subscription in subscriptions where subscription.countsTowardTotals {
            guard let monthly = TotalsCalculator.convert(
                subscription.monthlyEquivalent,
                from: subscription.currencyCode,
                to: displayCurrency,
                table: exchangeRates.table
            ) else { continue }
            totals[key(subscription), default: 0] += monthly
        }
        return totals
            .map { SpendEntry(label: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    /// Converted cost of annual-cycle charges per month, next 12 months.
    private var annualRenewalsByMonth: [MonthEntry] {
        let calendar = Calendar.current
        let charges = UpcomingCharge.project(from: subscriptions)
            .filter { $0.cycleKind == .annual }
        var byMonth: [Date: Decimal] = [:]
        for charge in charges {
            guard let monthStart = calendar.dateInterval(of: .month, for: charge.date)?.start,
                  let converted = TotalsCalculator.convert(
                    charge.amount,
                    from: charge.currencyCode,
                    to: displayCurrency,
                    table: exchangeRates.table
                  ) else { continue }
            byMonth[monthStart, default: 0] += converted
        }
        return byMonth
            .map { MonthEntry(month: $0.key, amount: $0.value) }
            .sorted { $0.month < $1.month }
    }

    private var statusCounts: [StatusEntry] {
        var counts: [SubscriptionStatus: Int] = [:]
        for subscription in subscriptions {
            counts[subscription.status, default: 0] += 1
        }
        return SubscriptionStatus.allCases.compactMap { status in
            guard let count = counts[status], count > 0 else { return nil }
            return StatusEntry(status: status.displayName, count: count)
        }
    }
}

// MARK: - Chart Data Entries

struct SpendEntry: Identifiable {
    let label: String
    let amount: Decimal
    var id: String { label }
}

struct MonthEntry: Identifiable {
    let month: Date
    let amount: Decimal
    var id: Date { month }
}

struct StatusEntry: Identifiable {
    let status: String
    let count: Int
    var id: String { status }
}

#Preview {
    ReportsPane()
        .previewEnvironment()
        .frame(width: 900, height: 700)
}
