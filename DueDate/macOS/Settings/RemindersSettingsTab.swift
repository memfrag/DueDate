//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// Default reminder offsets (spec Section 19). Subscriptions using the
/// "Use defaults" reminder policy follow these; changing them retroactively
/// applies to all such subscriptions on the next schedule sync.
struct RemindersSettingsTab: View {

    @Environment(AppSettings.self) private var settings
    @Environment(NotificationManager.self) private var notifications

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField("Monthly & weekly:", text: $settings.reminderDefaultsMonthly, prompt: Text("1"))
                TextField("Annual & quarterly:", text: $settings.reminderDefaultsAnnual, prompt: Text("30, 7"))
                TextField("Trials:", text: $settings.reminderDefaultsTrial, prompt: Text("3"))
                TextField("Manual renewals:", text: $settings.reminderDefaultsManual, prompt: Text("30, 14"))
                Text("Days before the due date, comma-separated. Example: \"30, 7\" reminds 30 and 7 days ahead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onDisappear {
            Task {
                await notifications.resync()
            }
        }
    }
}

#Preview {
    RemindersSettingsTab()
        .previewEnvironment()
}
