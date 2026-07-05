//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

struct GeneralSettingsTab: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("Display currency:", selection: $settings.displayCurrencyCode) {
                    ForEach(exchangeRates.supportedCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                Text("Totals and reports are shown in this currency. Subscriptions keep their own currencies; conversion uses daily rates from Sveriges Riksbank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let table = exchangeRates.table {
                    LabeledContent("Exchange rates:") {
                        Text("As of \(table.asOf.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
            }
        }
        .padding(20)
    }
}

#Preview {
    GeneralSettingsTab()
        .previewEnvironment()
}
