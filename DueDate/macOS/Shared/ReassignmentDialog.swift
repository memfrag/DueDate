//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// Blocked-delete flow (spec Sections 12 & 20): deleting an in-use payment
/// method or category requires choosing where its subscriptions go first.
/// Prevents silent data loss.
struct ReassignmentDialog: View {

    /// A reassignment destination.
    struct Option: Identifiable, Hashable {
        var id: UUID
        var name: String
    }

    let title: String
    let message: String
    let options: [Option]
    /// Called with the chosen destination (`nil` = remove from subscriptions),
    /// after which the caller performs the reassignment and deletion.
    let onReassign: (Option?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selection: Option?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(message)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Reassign to:", selection: $selection) {
                Text("None (remove from subscriptions)").tag(nil as Option?)
                ForEach(options) { option in
                    Text(option.name).tag(option as Option?)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Reassign & Delete", role: .destructive) {
                    onReassign(selection)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

#Preview {
    ReassignmentDialog(
        title: "Payment Method In Use",
        message: "\"Visa Debit •••• 1234\" is used by 5 subscriptions. Choose another payment method for them, or remove it from them, before deleting.",
        options: [
            ReassignmentDialog.Option(id: UUID(), name: "PayPal"),
            ReassignmentDialog.Option(id: UUID(), name: "Apple ID")
        ],
        onReassign: { _ in }
    )
}
