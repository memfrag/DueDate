//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import Charts

/// A rounded card wrapping a single report chart.
struct ReportCard<Content: View>: View {

    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Horizontal bar chart of monthly-equivalent spend per label.
struct SpendBarChart: View {

    let entries: [SpendEntry]
    let currencyCode: String

    var body: some View {
        if entries.isEmpty {
            emptyText
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Spend", NSDecimalNumber(decimal: entry.amount).doubleValue),
                    y: .value("Group", entry.label)
                )
                .cornerRadius(3)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(entry.amount.formatted(
                        .currency(code: currencyCode).precision(.fractionLength(0))
                    ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .chartXAxisLabel("per month")
            .frame(height: max(120, CGFloat(entries.count) * 28))
        }
    }

    private var emptyText: some View {
        Text("No data")
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 120)
    }
}

/// Vertical bar chart of annual renewal cost per month.
struct AnnualRenewalsChart: View {

    let entries: [MonthEntry]
    let currencyCode: String

    var body: some View {
        if entries.isEmpty {
            Text("No annual renewals")
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Month", entry.month, unit: .month),
                    y: .value("Cost", NSDecimalNumber(decimal: entry.amount).doubleValue)
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .frame(height: 160)
        }
    }
}

/// Sector chart of subscription counts per status.
struct StatusChart: View {

    let entries: [StatusEntry]

    var body: some View {
        HStack(spacing: 24) {
            Chart(entries) { entry in
                SectorMark(
                    angle: .value("Count", entry.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(by: .value("Status", entry.status))
            }
            .chartLegend(position: .trailing, alignment: .center)
            .frame(height: 180)
        }
    }
}
