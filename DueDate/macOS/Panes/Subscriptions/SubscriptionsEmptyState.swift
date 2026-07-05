//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// First-launch empty state: add a subscription or explore with sample data.
/// Sample data is strictly opt-in (spec Section 29).
struct SubscriptionsEmptyState: View {

    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Know what's due")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Track subscriptions, bills, domains, and renewals —\nand see what needs attention before it costs you money.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button {
                    navigation.editorTarget = .new
                } label: {
                    Label("Add Your First Subscription", systemImage: "plus")
                        .frame(minWidth: 220)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button {
                    SampleDataService.seedSamples(context: modelContext)
                } label: {
                    Label("Explore with Sample Data", systemImage: "sparkles")
                        .frame(minWidth: 220)
                }
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SubscriptionsEmptyState()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
