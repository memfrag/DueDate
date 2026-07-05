//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

public struct HelpWindow: Scene {

    public static let windowID = "help"

    public var body: some Scene {
        Window("DueDate Help", id: Self.windowID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Know what's due")
                        .font(.title2)
                        .fontWeight(.semibold)

                    helpSection(
                        "Getting started",
                        "Add each recurring cost with the + button: name, amount, billing cycle, and next due date. That's all that's required — everything else can be filled in later."
                    )
                    helpSection(
                        "Renewal & payment",
                        "For each subscription you can record how it renews (card on file, App Store, Autogiro, manual…), what pays for it, and where it's managed — so you always know where to cancel."
                    )
                    helpSection(
                        "Smart views",
                        "The sidebar's smart views show what's due in 7 or 30 days, annual renewals, ending trials, and anything that needs attention: overdue manual renewals, missing cancellation info, or unknown payment details."
                    )
                    helpSection(
                        "Reminders",
                        "DueDate schedules notifications before charges happen. Defaults per cycle type live in Settings > Reminders; each subscription can override them."
                    )
                    helpSection(
                        "Manual renewals",
                        "Subscriptions with a manual renewal method (like domains) are never advanced automatically. When the due date passes they appear in Needs Attention until you press Confirm Payment."
                    )
                    helpSection(
                        "Currencies",
                        "Subscriptions can be in any currency. Totals are converted to your display currency using daily rates from Sveriges Riksbank; no personal data ever leaves your Mac."
                    )
                    helpSection(
                        "Your data",
                        "Everything is stored locally. Export a complete JSON backup or a CSV spreadsheet at any time from File > Export."
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 500, minHeight: 350)
        }
        .commandsRemoved() // Don't show window in Windows menu
        .defaultPosition(.center)
        .defaultSize(width: 520, height: 560)
        .windowResizability(.contentMinSize)
    }

    private func helpSection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
