//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// Locale-agnostic parsing of a user-typed monetary amount.
///
/// Accepts both `.` and `,` as the decimal separator, tolerates whitespace
/// used as a thousands separator, and ignores stray currency symbols or
/// letters — so "85.99", "85,99", "8 599", and "1 188 kr" all parse the way
/// a person means them, regardless of the Mac's locale.
nonisolated enum AmountParser {

    static func parse(_ text: String) -> Decimal? {
        // Keep only digits, separators, and a leading minus sign.
        var s = text.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard !s.isEmpty else { return nil }

        let hasDot = s.contains(".")
        let hasComma = s.contains(",")

        if hasDot && hasComma {
            // Both present: the last-occurring one is the decimal separator,
            // the other is a grouping separator (e.g. "8,599.00" / "8.599,00").
            let decimalChar: Character = s.lastIndex(of: ".")! > s.lastIndex(of: ",")! ? "." : ","
            let groupingChar: Character = decimalChar == "." ? "," : "."
            s.removeAll { $0 == groupingChar }
            s = s.replacingOccurrences(of: String(decimalChar), with: ".")
        } else if hasDot || hasComma {
            let separator: Character = hasDot ? "." : ","
            let occurrences = s.filter { $0 == separator }.count
            let digitsAfterLast = s.distance(
                from: s.index(after: s.lastIndex(of: separator)!),
                to: s.endIndex
            )
            // A single separator with exactly 3 trailing digits (e.g. "1,000"
            // or "1.000"), or any repeated separator, is grouping — remove it.
            // Otherwise it's the decimal separator (e.g. "85,99", "1.5").
            if occurrences > 1 || digitsAfterLast == 3 {
                s.removeAll { $0 == separator }
            } else {
                s = s.replacingOccurrences(of: String(separator), with: ".")
            }
        }

        // `Decimal(string:)` is locale-independent and expects "." as the point.
        return Decimal(string: s)
    }
}
