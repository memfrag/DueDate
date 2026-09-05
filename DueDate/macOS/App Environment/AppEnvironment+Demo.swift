//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import KeyValueStore

extension AppEnvironment {

    // MARK: - Demo AppEnvironment

    /// Builds the environment used by ``DemoMode``: an in-memory store with no
    /// CloudKit mirroring, in-memory settings, and fixed exchange rates.
    ///
    /// Unlike ``mock()`` this ships in release builds — demo mode is a product
    /// feature, not a test fixture. Rates come from `MockExchangeRateProvider`
    /// so converted totals are identical every run, which is what makes
    /// screenshots reproducible; it also keeps the demo entirely offline.
    ///
    internal static func demo() -> AppEnvironment {
        let store = InMemoryKeyValueStore(keyedBy: AppSettings.Key.self, initialContent: [
            .colorScheme: AppColorScheme.system
        ])
        let settings = AppSettings(store: store.eraseToAnyKeyValueStore())
        // The welcome is about setting up real data; it has no place in a demo.
        settings.hasCompletedOnboarding = true

        return AppEnvironment(
            appSettings: settings,
            engineeringMode: EngineeringMode.shared,
            modelContainer: ModelContainerFactory.make(inMemory: true),
            exchangeRateService: ExchangeRateService(provider: MockExchangeRateProvider())
        )
    }
}
