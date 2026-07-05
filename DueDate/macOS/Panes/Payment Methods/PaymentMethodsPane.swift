//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Payment methods with their linked subscriptions (spec Section 12).
struct PaymentMethodsPane: View {

    @Environment(AppNavigationModel.self) private var navigation
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PaymentMethod.displayName) private var paymentMethods: [PaymentMethod]

    @State private var editorTarget: PaymentMethodEditorTarget?
    @State private var reassignmentSource: PaymentMethod?
    @State private var showArchived = false

    private var visibleMethods: [PaymentMethod] {
        showArchived ? paymentMethods : paymentMethods.filter { !$0.isArchived }
    }

    var body: some View {
        Group {
            if visibleMethods.isEmpty {
                ContentUnavailableView(
                    "No Payment Methods",
                    systemImage: "creditcard",
                    description: Text("Add payment methods like \"Visa Debit •••• 1234\" and link subscriptions to them.\nUse aliases — never store full card or account numbers.")
                )
            } else {
                List {
                    ForEach(visibleMethods) { paymentMethod in
                        Section {
                            row(paymentMethod)
                            ForEach(activeSubscriptions(of: paymentMethod)) { subscription in
                                subscriptionRow(subscription)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationSubtitle("Payment Methods")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle("Show Archived", isOn: $showArchived)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = .new
                } label: {
                    Label("Add Payment Method", systemImage: "plus")
                }
                .help("Add a new payment method")
            }
        }
        .sheet(item: $editorTarget) { target in
            PaymentMethodEditorView(target: target)
        }
        .sheet(item: $reassignmentSource) { source in
            ReassignmentDialog(
                title: "Payment Method In Use",
                message: "\"\(source.displayName)\" is used by \(source.subscriptions?.count ?? 0) subscription\((source.subscriptions?.count ?? 0) == 1 ? "" : "s"). Choose another payment method for them, or remove it from them, before deleting.",
                options: paymentMethods
                    .filter { $0.id != source.id && !$0.isArchived }
                    .map { ReassignmentDialog.Option(id: $0.id, name: $0.displayName) },
                onReassign: { option in
                    reassignAndDelete(source, to: option)
                }
            )
        }
    }

    // MARK: - Rows

    private func row(_ paymentMethod: PaymentMethod) -> some View {
        HStack {
            Image(systemName: paymentMethod.kind.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(paymentMethod.displayName)
                        .fontWeight(.semibold)
                    if paymentMethod.isArchived {
                        Text("Archived")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(detailText(paymentMethod))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(paymentMethod.subscriptions?.count ?? 0) linked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Edit…") {
                editorTarget = .edit(paymentMethod.id)
            }
            Button(paymentMethod.isArchived ? "Unarchive" : "Archive") {
                paymentMethod.isArchived.toggle()
                try? modelContext.save()
            }
            Divider()
            Button("Delete", role: .destructive) {
                requestDelete(paymentMethod)
            }
        }
    }

    private func subscriptionRow(_ subscription: Subscription) -> some View {
        Button {
            navigation.reveal(subscriptionID: subscription.id)
        } label: {
            HStack {
                Text(subscription.name)
                    .padding(.leading, 32)
                Spacer()
                Text(subscription.amount, format: .currency(code: subscription.currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(subscription.billingCycle.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 70, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func activeSubscriptions(of paymentMethod: PaymentMethod) -> [Subscription] {
        (paymentMethod.subscriptions ?? [])
            .filter { !$0.status.isArchived }
            .sorted { $0.name < $1.name }
    }

    private func detailText(_ paymentMethod: PaymentMethod) -> String {
        var parts = [paymentMethod.kind.displayName]
        if !paymentMethod.institutionName.isEmpty {
            parts.append(paymentMethod.institutionName)
        }
        if let expirationDate = paymentMethod.expirationDate {
            parts.append("expires \(expirationDate.formatted(.dateTime.month(.twoDigits).year()))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Delete / Reassign

    private func requestDelete(_ paymentMethod: PaymentMethod) {
        if paymentMethod.subscriptions?.isEmpty ?? true {
            modelContext.delete(paymentMethod)
            try? modelContext.save()
        } else {
            // Blocked: in use. Require reassignment first (spec Section 12).
            reassignmentSource = paymentMethod
        }
    }

    private func reassignAndDelete(_ source: PaymentMethod, to option: ReassignmentDialog.Option?) {
        let destination = option.flatMap { chosen in
            paymentMethods.first { $0.id == chosen.id }
        }
        for subscription in source.subscriptions ?? [] {
            subscription.paymentMethod = destination
        }
        modelContext.delete(source)
        try? modelContext.save()
    }
}

/// What the payment method editor is editing.
enum PaymentMethodEditorTarget: Identifiable, Hashable {
    case new
    case edit(UUID)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

#Preview {
    PaymentMethodsPane()
        .environment(AppNavigationModel())
        .previewEnvironment()
}
