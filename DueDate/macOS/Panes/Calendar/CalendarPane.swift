//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Agenda-style timeline of upcoming charges, grouped chronologically,
/// with annual renewals highlighted at the end (spec Section 17).
struct CalendarPane: View {

    @Environment(AppNavigationModel.self) private var navigation

    @Query private var subscriptions: [Subscription]

    private enum AgendaGroup: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case laterThisMonth = "Later This Month"
        case nextMonth = "Next Month"
        case next90Days = "Next 90 Days"

        static func group(for date: Date, calendar: Calendar = .current) -> AgendaGroup? {
            let today = calendar.startOfDay(for: .now)
            let day = calendar.startOfDay(for: date)
            guard let days = calendar.dateComponents([.day], from: today, to: day).day,
                  days >= 0 else { return nil }
            if days == 0 { return .today }
            if days <= 7 { return .thisWeek }
            if calendar.isDate(day, equalTo: today, toGranularity: .month) { return .laterThisMonth }
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: today),
               calendar.isDate(day, equalTo: nextMonth, toGranularity: .month) {
                return .nextMonth
            }
            if days <= 90 { return .next90Days }
            return nil
        }
    }

    private var charges: [UpcomingCharge] {
        UpcomingCharge.project(from: subscriptions)
    }

    private var groupedCharges: [(AgendaGroup, [UpcomingCharge])] {
        let grouped = Dictionary(grouping: charges.compactMap { charge in
            AgendaGroup.group(for: charge.date).map { ($0, charge) }
        }, by: \.0)
        return AgendaGroup.allCases.compactMap { group in
            guard let items = grouped[group], !items.isEmpty else { return nil }
            return (group, items.map(\.1))
        }
    }

    private var annualRenewals: [UpcomingCharge] {
        charges.filter { $0.cycleKind == .annual }
    }

    var body: some View {
        Group {
            if charges.isEmpty {
                ContentUnavailableView(
                    "No Upcoming Charges",
                    systemImage: "calendar",
                    description: Text("Add subscriptions to see their upcoming charges here.")
                )
            } else {
                List {
                    ForEach(groupedCharges, id: \.0) { group, items in
                        Section(group.rawValue) {
                            ForEach(items) { charge in
                                chargeRow(charge)
                            }
                        }
                    }
                    if !annualRenewals.isEmpty {
                        Section("Annual Renewals") {
                            ForEach(annualRenewals) { charge in
                                chargeRow(charge)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationSubtitle("Calendar")
    }

    private func chargeRow(_ charge: UpcomingCharge) -> some View {
        Button {
            navigation.reveal(subscriptionID: charge.subscriptionID)
        } label: {
            HStack {
                VStack(alignment: .center, spacing: 0) {
                    Text(charge.date, format: .dateTime.day())
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(charge.date, format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 40)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(charge.name)
                        .fontWeight(.medium)
                    Text(relativeText(for: charge.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(charge.amount, format: .currency(code: charge.currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func relativeText(for date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        default: "In \(days) days · \(date.formatted(.dateTime.weekday(.wide)))"
        }
    }
}

#Preview {
    CalendarPane()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
