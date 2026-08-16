//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// First-launch welcome (spec Section 29). A single screen: what DueDate is
/// for, the one setting worth choosing up front, and the two start paths the
/// spec calls for. Everything here is skippable — nothing is seeded, and no
/// permission is requested, unless the user asks for it.
struct OnboardingView: View {

    let onAddFirstSubscription: () -> Void
    let onExploreSampleData: () -> Void
    let onSkip: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    private struct Feature: Identifiable {
        let id = UUID()
        let symbolName: String
        let title: String
        let detail: String
    }

    private let features: [Feature] = [
        Feature(
            symbolName: "list.bullet.rectangle",
            title: "Everything you pay for",
            detail: "Subscriptions, bills, domains, insurance, and renewals in one list."
        ),
        Feature(
            symbolName: "bell.badge",
            title: "Warning before it renews",
            detail: "Reminders ahead of each charge, with notice periods for the ones you must cancel in time."
        ),
        Feature(
            symbolName: "chart.bar",
            title: "What it actually costs",
            detail: "Monthly and yearly totals, with other currencies converted at daily rates."
        )
    ]

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 18) {
                ForEach(features) { feature in
                    featureRow(feature)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 28)

            Divider()
                .padding(.horizontal, 40)
                .padding(.top, 28)

            HStack {
                Text("Show totals in:")
                Picker("Show totals in:", selection: $settings.displayCurrencyCode) {
                    ForEach(exchangeRates.supportedCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            Text("Subscriptions keep their own currencies. You can change this later in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 4)

            actions
        }
        .frame(width: 520)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            Text("Welcome to DueDate")
                .font(.title)
                .fontWeight(.semibold)

            Text("Know what's due — before it costs you money.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 36)
    }

    private func featureRow(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.symbolName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .fontWeight(.medium)
                Text(feature.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onAddFirstSubscription) {
                Text("Add Your First Subscription")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)

            Button(action: onExploreSampleData) {
                Text("Explore with Sample Data")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button("Skip for Now", action: onSkip)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 40)
        .padding(.top, 24)
        .padding(.bottom, 28)
    }
}

#if DEBUG
#Preview {
    OnboardingView(
        onAddFirstSubscription: {},
        onExploreSampleData: {},
        onSkip: {}
    )
    .previewEnvironment()
}
#endif
