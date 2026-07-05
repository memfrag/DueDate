//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Fully ended subscriptions: Cancelled (ended) and Expired.
/// They stay in history without affecting totals (spec Section 7).
struct ArchivePane: View {

    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    private static let archivedStatusesRaw = [
        SubscriptionStatus.cancelledEnded.rawValue,
        SubscriptionStatus.expired.rawValue
    ]

    @Query(
        filter: #Predicate<Subscription> { archivedStatusesRaw.contains($0.statusRaw) },
        sort: \Subscription.updatedAt,
        order: .reverse
    ) private var archived: [Subscription]

    var body: some View {
        Group {
            if archived.isEmpty {
                ContentUnavailableView(
                    "Archive Is Empty",
                    systemImage: "archivebox",
                    description: Text("Subscriptions marked Cancelled (ended) or Expired end up here.")
                )
            } else {
                List {
                    ForEach(archived) { subscription in
                        row(subscription)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationSubtitle("Archive")
    }

    private func row(_ subscription: Subscription) -> some View {
        Button {
            navigation.selectedSubscriptionID = subscription.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .fontWeight(.medium)
                    if let category = subscription.category {
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(subscription.amount, format: .currency(code: subscription.currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                StatusBadge(status: subscription.status)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reactivate") {
                subscription.status = .active
                subscription.updatedAt = .now
                try? modelContext.save()
            }
            Divider()
            Button("Delete Permanently", role: .destructive) {
                if navigation.selectedSubscriptionID == subscription.id {
                    navigation.selectedSubscriptionID = nil
                }
                modelContext.delete(subscription)
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    ArchivePane()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
