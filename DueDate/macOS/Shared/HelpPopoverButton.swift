//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// A small question-mark button that shows an explanatory popover on click.
/// Used to clarify concepts inline, like renewal vs. payment method.
struct HelpPopoverButton: View {

    let title: String
    let text: String

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
        }
        .help(title)
    }
}

#Preview {
    HelpPopoverButton(
        title: "Renewal method",
        text: "How the subscription renews — the mechanism that triggers the charge."
    )
    .padding()
}
