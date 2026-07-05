//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// The main working view: a sortable, searchable table of subscriptions.
/// Also renders the smart views (same table, filtered).
struct SubscriptionsPane: View {

    var smartView: SmartView?

    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notifications

    @Query private var subscriptions: [Subscription]

    @State private var searchText: String = ""
    @State private var sortOrder: [KeyPathComparator<Subscription>] = [
        KeyPathComparator(\Subscription.nextBillingDate)
    ]

    init(smartView: SmartView? = nil) {
        self.smartView = smartView
    }

    var body: some View {
        Group {
            if subscriptions.isEmpty {
                SubscriptionsEmptyState()
            } else if visibleSubscriptions.isEmpty {
                ContentUnavailableView(
                    smartView != nil ? "Nothing Here" : "No Matches",
                    systemImage: smartView?.symbolName ?? "magnifyingglass",
                    description: Text(emptyFilterDescription)
                )
            } else {
                table
            }
        }
        .navigationSubtitle(smartView?.displayName ?? "All Subscriptions")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search subscriptions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigation.editorTarget = .new
                } label: {
                    Label("Add Subscription", systemImage: "plus")
                }
                .help("Add a new subscription")
            }
        }
    }

    private var table: some View {
        Table(visibleSubscriptions, selection: selectionBinding, sortOrder: $sortOrder) {

            TableColumn("Name", value: \.name) { subscription in
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .fontWeight(.medium)
                    if smartView == .needsAttention {
                        AttentionReasonChips(subscription: subscription)
                    } else if !subscription.websiteURLString.isEmpty,
                              let host = subscription.websiteURL?.host() {
                        Text(host)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            TableColumn("Category", value: \.categoryName) { subscription in
                if let category = subscription.category {
                    CategoryLabel(category: category)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }

            TableColumn("Cost", value: \.amount) { subscription in
                Text(subscription.amount, format: .currency(code: subscription.currencyCode))
                    .monospacedDigit()
            }

            TableColumn("Cycle", value: \.billingCycleName) { subscription in
                Text(subscription.billingCycle.displayName)
            }

            TableColumn("Next Due", value: \.nextBillingDate) { subscription in
                NextDueCell(subscription: subscription)
            }

            TableColumn("Renewal Method", value: \.renewalMethodName) { subscription in
                Text(subscription.renewalMethod.displayName)
            }

            TableColumn("Payment Method", value: \.paymentMethodName) { subscription in
                if let paymentMethod = subscription.paymentMethod {
                    Label {
                        Text(paymentMethod.displayName)
                    } icon: {
                        Image(systemName: paymentMethod.kind.symbolName)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }

            TableColumn("Status", value: \.statusRaw) { subscription in
                StatusBadge(status: subscription.status)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first {
                Button("Edit…") {
                    navigation.editorTarget = .edit(id)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    delete(ids: ids)
                }
            }
        } primaryAction: { ids in
            if let id = ids.first {
                navigation.editorTarget = .edit(id)
            }
        }
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { navigation.selectedSubscriptionID },
            set: { navigation.selectedSubscriptionID = $0 }
        )
    }

    private var visibleSubscriptions: [Subscription] {
        var result = subscriptions

        if let smartView {
            result = SmartViewEvaluator.filter(result, view: smartView)
        } else {
            // The main list hides archived subscriptions (they live in Archive).
            result = result.filter { !$0.status.isArchived }
        }

        if !searchText.isEmpty {
            result = result.filter { subscription in
                subscription.name.localizedCaseInsensitiveContains(searchText)
                    || subscription.categoryName.localizedCaseInsensitiveContains(searchText)
                    || subscription.paymentMethodName.localizedCaseInsensitiveContains(searchText)
                    || subscription.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted(using: sortOrder)
    }

    private var emptyFilterDescription: String {
        if smartView != nil {
            "No subscriptions match this smart view right now."
        } else {
            "No subscriptions match your search."
        }
    }

    private func delete(ids: Set<UUID>) {
        for subscription in subscriptions where ids.contains(subscription.id) {
            if navigation.selectedSubscriptionID == subscription.id {
                navigation.selectedSubscriptionID = nil
            }
            modelContext.delete(subscription)
        }
        try? modelContext.save()
        Task {
            await notifications.resync()
        }
    }
}

/// Compact chips explaining why a subscription needs attention.
struct AttentionReasonChips: View {

    let subscription: Subscription

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SmartViewEvaluator.attentionReasons(for: subscription), id: \.self) { reason in
                Label(reason.displayName, systemImage: reason.symbolName)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
    }
}

/// A category name with its color dot.
struct CategoryLabel: View {

    let category: SubscriptionCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(category.color)
                .frame(width: 8, height: 8)
            Text(category.name)
        }
    }
}

/// Next due date with "in N days" emphasis (mockup style).
struct NextDueCell: View {

    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(subscription.nextBillingDate, format: .dateTime.year().month().day())
            Text(relativeText)
                .font(.caption)
                .foregroundStyle(relativeColor)
        }
    }

    private var days: Int {
        subscription.daysUntilNextBilling
    }

    private var relativeText: String {
        if days < 0 {
            "\(-days) day\(days == -1 ? "" : "s") overdue"
        } else if days == 0 {
            "today"
        } else {
            "in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    private var relativeColor: Color {
        if days < 0 {
            .red
        } else if days <= 7 {
            .orange
        } else {
            .secondary
        }
    }
}

#Preview {
    SubscriptionsPane()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
