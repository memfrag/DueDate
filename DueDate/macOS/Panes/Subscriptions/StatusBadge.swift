//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

/// A colored capsule showing a subscription's status.
struct StatusBadge: View {

    let status: SubscriptionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        switch status {
        case .active: .green
        case .trial: .blue
        case .paused: .orange
        case .cancelledStillActive: .yellow
        case .cancelledEnded: .secondary
        case .expired: .secondary
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(SubscriptionStatus.allCases, id: \.self) { status in
            StatusBadge(status: status)
        }
    }
    .padding()
}
