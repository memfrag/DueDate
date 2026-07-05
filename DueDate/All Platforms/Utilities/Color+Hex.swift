//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI

extension Color {

    /// Creates a color from a hex string like `"FF9500"` or `"#FF9500"`.
    /// Returns `nil` for malformed input.
    nonisolated init?(hex: String) {
        let trimmed = hex
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension SubscriptionCategory {

    /// The category's display color, falling back to gray for no/invalid hex.
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}
