//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Compact monthly-total summary at the bottom of the sidebar.
struct SidebarFooter: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ExchangeRateService.self) private var exchangeRates

    @Query private var subscriptions: [Subscription]

    var body: some View {
        let totals = TotalsCalculator.totals(
            for: subscriptions,
            displayCurrencyCode: settings.displayCurrencyCode,
            table: exchangeRates.table
        )
        VStack(spacing: 4) {
            Text(
                totals.monthlyTotal.formatted(
                    .currency(code: settings.displayCurrencyCode)
                        .precision(.fractionLength(0))
                )
            )
            .font(.title3)
            .fontWeight(.semibold)
            .monospacedDigit()
            Text("per month · \(totals.subscriptionCount) active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }
}

#Preview {
    SidebarFooter()
        .previewEnvironment()
        .frame(width: 220)
}
