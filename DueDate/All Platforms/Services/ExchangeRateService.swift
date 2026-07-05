//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import OSLog

// MARK: - Rate Table

/// A snapshot of exchange rates with SEK as base: `rates[code]` is the
/// SEK price of 1 unit of `code` (SEK itself is 1).
nonisolated struct RateTable: Codable, Sendable {
    var base: String = "SEK"
    /// The most recent observation date among the fetched series.
    var asOf: Date
    var rates: [String: Decimal]

    func rate(for currencyCode: String) -> Decimal? {
        if currencyCode == base { return 1 }
        return rates[currencyCode]
    }

    var supportedCurrencyCodes: [String] {
        ([base] + rates.keys.sorted()).uniqued()
    }
}

private extension Array where Element: Hashable {
    nonisolated func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Provider

/// Abstracts the rate source so it can be swapped or mocked.
protocol ExchangeRateProviding: Sendable {
    func fetchRateTable() async throws -> RateTable
}

/// Fetches daily exchange rates from the Riksbank SWEA API
/// (`Docs/swea-api.json`). Two GETs per refresh:
///
/// 1. `/Series/ExchangeRateSeries` — maps series ids (`SEKUSDPMI`) to ISO
///    currency codes and identifies closed series.
/// 2. `/Observations/Latest/ByGroup/130` — the latest observation for every
///    exchange-rate series in one call (group 130 = exchange rates).
///
/// Rates are quoted as SEK per 1 unit of foreign currency, so the table's
/// base is SEK. No user data is ever sent (spec Section 25).
struct RiksbankExchangeRateProvider: ExchangeRateProviding {

    private static let baseURL = URL(string: "https://api.riksbank.se/swea/v1")!
    private static let exchangeRateGroupID = 130

    nonisolated struct SeriesInfo: Codable {
        var seriesId: String
        var shortDescription: String
        var seriesClosed: Bool
    }

    nonisolated struct Observation: Codable {
        var seriesId: String
        var date: String
        var value: Decimal
    }

    func fetchRateTable() async throws -> RateTable {
        let session = URLSession.shared

        let seriesURL = Self.baseURL.appending(path: "Series/ExchangeRateSeries")
        let (seriesData, _) = try await session.data(from: seriesURL)
        let series = try JSONDecoder().decode([SeriesInfo].self, from: seriesData)

        // Only open series represent live currencies; closed ones (ATS, BEF, …)
        // still appear in the group observations with decades-old dates.
        var codeBySeriesID: [String: String] = [:]
        for info in series where !info.seriesClosed {
            // Skip the synthetic SEK series used for inverted rates.
            guard info.shortDescription != "SEK" else { continue }
            codeBySeriesID[info.seriesId.uppercased()] = info.shortDescription
        }

        let observationsURL = Self.baseURL
            .appending(path: "Observations/Latest/ByGroup/\(Self.exchangeRateGroupID)")
        let (observationsData, _) = try await session.data(from: observationsURL)
        let observations = try JSONDecoder().decode([Observation].self, from: observationsData)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Europe/Stockholm")

        var rates: [String: Decimal] = [:]
        var asOf: Date = .distantPast
        for observation in observations {
            guard let code = codeBySeriesID[observation.seriesId.uppercased()],
                  observation.value > 0 else { continue }
            rates[code] = observation.value
            if let date = dateFormatter.date(from: observation.date), date > asOf {
                asOf = date
            }
        }

        guard !rates.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return RateTable(asOf: asOf, rates: rates)
    }
}

// MARK: - Service

/// Owns the current rate table: loads the local cache first so the UI never
/// blanks, then refreshes from the provider at most once per day.
/// Offline or failed fetches keep the cached table; the UI shows
/// "rates as of <date>" when the table is stale (spec Section 24).
@Observable
final class ExchangeRateService {

    private(set) var table: RateTable?
    private(set) var lastFetchDate: Date?

    @ObservationIgnored
    private let provider: any ExchangeRateProviding

    @ObservationIgnored
    private let logger = Logger(subsystem: "io.apparata.DueDate", category: "ExchangeRates")

    init(provider: any ExchangeRateProviding = RiksbankExchangeRateProvider()) {
        self.provider = provider
        loadCache()
    }

    /// Currency codes offered in pickers: the provider-supported set,
    /// falling back to a static list before the first successful fetch.
    var supportedCurrencyCodes: [String] {
        table?.supportedCurrencyCodes ?? CurrencyCatalog.codes
    }

    /// Whether the current table is from an earlier day (offline/stale).
    var isStale: Bool {
        guard let table else { return true }
        return !Calendar.current.isDateInToday(table.asOf)
            && !isWeekendGap(table.asOf)
    }

    /// Rates update on banking days; a Friday table shown during the weekend
    /// isn't meaningfully stale.
    private func isWeekendGap(_ asOf: Date) -> Bool {
        let calendar = Calendar.current
        guard let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: asOf),
            to: calendar.startOfDay(for: .now)
        ).day else { return false }
        return days <= 3
    }

    /// Fetches a fresh table if none has been fetched today.
    func refreshIfNeeded() async {
        if let lastFetchDate, Calendar.current.isDateInToday(lastFetchDate) {
            return
        }
        do {
            let fresh = try await provider.fetchRateTable()
            table = fresh
            lastFetchDate = .now
            saveCache()
        } catch {
            logger.warning("Exchange rate refresh failed, keeping cached table: \(error)")
        }
    }

    // MARK: - Cache

    nonisolated private struct CachedRates: Codable {
        var table: RateTable
        var fetchedAt: Date
    }

    private var cacheURL: URL? {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        return directory
            .appending(path: "DueDate", directoryHint: .isDirectory)
            .appending(path: "ExchangeRates.json")
    }

    private func loadCache() {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL) else { return }
        if let cached = try? JSONDecoder().decode(CachedRates.self, from: data) {
            table = cached.table
            lastFetchDate = cached.fetchedAt
        }
    }

    private func saveCache() {
        guard let cacheURL, let table, let lastFetchDate else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(CachedRates(table: table, fetchedAt: lastFetchDate))
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            logger.warning("Failed to write exchange rate cache: \(error)")
        }
    }
}

/// Fallback currency codes offered in pickers before the first successful
/// rate fetch (mirrors Riksbank's published set).
nonisolated enum CurrencyCatalog {
    static let codes: [String] = [
        "SEK", "EUR", "USD", "GBP", "NOK", "DKK", "CHF", "JPY",
        "AUD", "CAD", "NZD", "PLN", "CZK", "HUF", "ISK", "CNY",
        "HKD", "INR", "KRW", "MXN", "SGD", "THB", "TRY", "ZAR", "BRL", "IDR"
    ]
}

// MARK: - Mock Provider

/// Fixed rates for previews and mock environments; never touches the network.
struct MockExchangeRateProvider: ExchangeRateProviding {
    func fetchRateTable() async throws -> RateTable {
        RateTable(asOf: .now, rates: [
            "USD": 9.64, "EUR": 11.02, "GBP": 12.75, "NOK": 0.94,
            "DKK": 1.48, "CHF": 12.00, "JPY": 0.066, "AUD": 6.69
        ])
    }
}
