//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData
import SwiftUIToolbox

/// Read-only inspector for the selected subscription (spec Section 16).
/// Editing happens in the modal editor sheet, never inline here.
struct SubscriptionInspector: View {

    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationManager.self) private var notifications

    @Query private var subscriptions: [Subscription]

    private var subscription: Subscription? {
        guard let id = navigation.selectedSubscriptionID else { return nil }
        return subscriptions.first { $0.id == id }
    }

    var body: some View {
        if let subscription {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(subscription)
                    details(subscription)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer(subscription)
            }
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "sidebar.trailing",
                description: Text("Select a subscription to see its details.")
            )
        }
    }

    // MARK: - Header

    private func header(_ subscription: Subscription) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(subscription.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                StatusBadge(status: subscription.status)
            }
            if let category = subscription.category {
                CategoryLabel(category: category)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Details

    private func details(_ subscription: Subscription) -> some View {
        InspectorGrid {
            InspectorSectionHeader("Overview")

            if !subscription.subscriptionDescription.isEmpty {
                GridRow {
                    InspectorLabel("Description")
                    InspectorTextValue(subscription.subscriptionDescription)
                }
            }

            if let websiteURL = subscription.websiteURL {
                GridRow {
                    InspectorLabel("Website")
                    Link(websiteURL.host() ?? websiteURL.absoluteString, destination: websiteURL)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GridRow {
                InspectorLabel("Status")
                InspectorTextValue(subscription.status.displayName)
            }

            GridRow {
                InspectorLabel("Auto-renews")
                InspectorTextValue(autoRenewsText(subscription))
            }

            if subscription.status == .cancelledStillActive, let endDate = subscription.endDate {
                GridRow {
                    InspectorLabel("Access until")
                    InspectorTextValue(endDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            InspectorDivider()

            InspectorSectionHeader("Renewal & Payment")

            GridRow {
                InspectorLabel("Renewal method")
                InspectorTextValue(subscription.renewalMethod.displayName)
            }

            GridRow {
                InspectorLabel("Payment method")
                InspectorTextValue(subscription.paymentMethod?.displayName ?? "None")
            }

            GridRow {
                InspectorLabel("Managed through")
                InspectorTextValue(subscription.managedThrough.displayName)
            }

            if let cancellationURL = subscription.cancellationURL {
                GridRow {
                    InspectorLabel("Cancellation URL")
                    Link("Open cancellation page", destination: cancellationURL)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !subscription.cancellationNotes.isEmpty {
                GridRow {
                    InspectorLabel("How to cancel")
                    InspectorTextValue(subscription.cancellationNotes)
                }
            }

            GridRow {
                InspectorLabel("Notice period")
                InspectorTextValue(noticePeriodText(subscription))
            }

            InspectorDivider()

            InspectorSectionHeader("Billing")

            GridRow {
                InspectorLabel("Cost")
                InspectorTextValue(
                    subscription.amount.formatted(.currency(code: subscription.currencyCode))
                )
            }

            GridRow {
                InspectorLabel("Billing cycle")
                InspectorTextValue(subscription.billingCycle.displayName)
            }

            GridRow {
                InspectorLabel("Monthly equiv.")
                InspectorTextValue(
                    subscription.monthlyEquivalent.formatted(.currency(code: subscription.currencyCode))
                )
            }

            GridRow {
                InspectorLabel("Next due")
                InspectorTextValue(subscription.nextBillingDate.formatted(date: .abbreviated, time: .omitted))
            }

            if let startDate = subscription.startDate {
                GridRow {
                    InspectorLabel("Started")
                    InspectorTextValue(startDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if let trialEndDate = subscription.trialEndDate {
                GridRow {
                    InspectorLabel("Trial ends")
                    InspectorTextValue(trialEndDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if let contractEndDate = subscription.contractEndDate {
                GridRow {
                    InspectorLabel("Contract ends")
                    InspectorTextValue(contractEndDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            InspectorDivider()

            InspectorSectionHeader("Reminders")

            GridRow {
                InspectorLabel("Remind me")
                InspectorTextValue(reminderText(subscription))
            }

            if !subscription.accountEmail.isEmpty {
                InspectorDivider()
                InspectorSectionHeader("Account")
                GridRow {
                    InspectorLabel("Email")
                    InspectorTextValue(subscription.accountEmail)
                }
            }

            if !subscription.notes.isEmpty {
                InspectorDivider()
                InspectorSectionHeader("Notes")
                GridRow {
                    InspectorLabel("Notes")
                    InspectorTextValue(subscription.notes)
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private func footer(_ subscription: Subscription) -> some View {
        VStack(spacing: 8) {
            if subscription.isOverdueManualRenewal {
                Button {
                    RenewalScheduler.confirmPayment(for: subscription, context: modelContext)
                    Task {
                        await notifications.resync()
                    }
                } label: {
                    Label("Confirm Payment", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .help("Mark this manual renewal as paid and advance the due date one cycle")
            }
            Button {
                navigation.editorTarget = .edit(subscription.id)
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(12)
        .background(.bar)
    }

    // MARK: - Formatting

    private func autoRenewsText(_ subscription: Subscription) -> String {
        switch subscription.autoRenews {
        case true: "Yes"
        case false: "No"
        default: "Unknown"
        }
    }

    private func noticePeriodText(_ subscription: Subscription) -> String {
        guard subscription.noticePeriodValue > 0,
              let unit = BillingUnit(rawValue: subscription.noticePeriodUnitRaw) else {
            return "None"
        }
        let value = subscription.noticePeriodValue
        return "\(value) \(value == 1 ? unit.singularName : unit.pluralName)"
    }

    private func reminderText(_ subscription: Subscription) -> String {
        switch subscription.reminderPolicy {
        case .useDefaults:
            "Default schedule"
        case .custom:
            subscription.reminderDaysBefore
                .sorted(by: >)
                .map { "\($0) day\($0 == 1 ? "" : "s") before" }
                .joined(separator: ", ")
        case .disabled:
            "Off"
        }
    }
}

#Preview {
    SubscriptionInspector()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
