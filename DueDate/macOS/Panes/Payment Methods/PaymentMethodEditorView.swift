//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Modal sheet for adding or editing a payment method.
/// Encourages aliases over sensitive details (spec Section 25).
struct PaymentMethodEditorView: View {

    let target: PaymentMethodEditorTarget

    /// Called with the saved record, so callers (like the subscription
    /// editor's inline "New Payment Method…") can select it immediately.
    var onSave: ((PaymentMethod) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var displayName: String = ""
    @State private var kind: PaymentMethodKind = .debitCard
    @State private var institutionName: String = ""
    @State private var lastFour: String = ""
    @State private var hasExpirationDate: Bool = false
    @State private var expirationDate: Date = .now
    @State private var owner: String = ""
    @State private var notes: String = ""
    @State private var isLoaded = false

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $displayName, prompt: Text("Visa Debit •••• 1234"))
                    Picker("Kind", selection: $kind) {
                        ForEach(PaymentMethodKind.allCases, id: \.self) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    TextField("Institution", text: $institutionName, prompt: Text("Handelsbanken"))
                    TextField("Last four digits", text: $lastFour, prompt: Text("1234"))
                        .onChange(of: lastFour) {
                            lastFour = String(lastFour.filter(\.isNumber).prefix(4))
                        }
                    Toggle("Expiration date", isOn: $hasExpirationDate)
                    if hasExpirationDate {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                    }
                    TextField("Owner", text: $owner, prompt: Text("Personal / company / family member"))
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    Text("Use an alias. Never store full card or bank account numbers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 460, height: 420)
        .onAppear(perform: load)
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        if case .edit(let id) = target, let paymentMethod = fetch(id: id) {
            displayName = paymentMethod.displayName
            kind = paymentMethod.kind
            institutionName = paymentMethod.institutionName
            lastFour = paymentMethod.lastFour
            hasExpirationDate = paymentMethod.expirationDate != nil
            expirationDate = paymentMethod.expirationDate ?? .now
            owner = paymentMethod.owner
            notes = paymentMethod.notes
        }
    }

    private func save() {
        let paymentMethod: PaymentMethod
        if case .edit(let id) = target, let existing = fetch(id: id) {
            paymentMethod = existing
        } else {
            paymentMethod = PaymentMethod()
            modelContext.insert(paymentMethod)
        }
        paymentMethod.displayName = displayName.trimmingCharacters(in: .whitespaces)
        paymentMethod.kind = kind
        paymentMethod.institutionName = institutionName
        paymentMethod.lastFour = lastFour
        paymentMethod.expirationDate = hasExpirationDate ? expirationDate : nil
        paymentMethod.owner = owner
        paymentMethod.notes = notes
        try? modelContext.save()
        onSave?(paymentMethod)
        dismiss()
    }

    private func fetch(id: UUID) -> PaymentMethod? {
        let descriptor = FetchDescriptor<PaymentMethod>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    PaymentMethodEditorView(target: .new)
        .previewEnvironment()
}
