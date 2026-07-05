//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// A rounded dashboard stat card (mockup style).
struct DashboardCard: View {

    let title: String
    let value: String
    var detail: String?
    var symbolName: String = "circle"
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.body)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        DashboardCard(
            title: "Monthly Total",
            value: "SEK 4,362",
            detail: "24 subscriptions",
            symbolName: "chart.line.uptrend.xyaxis",
            tint: .green
        )
        DashboardCard(
            title: "Due in 7 Days",
            value: "SEK 593",
            detail: "3 subscriptions",
            symbolName: "calendar.badge.clock",
            tint: .orange
        )
    }
    .padding()
    .frame(width: 500)
}
