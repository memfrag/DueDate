//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftData
import AppRouting

/// An application-wide environment container.
///
/// This type centralizes access to shared app state and dependencies that are safe to
/// read from anywhere in the app, such as `AppSettings`. Prefer injecting instances via
/// SwiftUI's `@Environment`.
///
/// Use ``AppEnvironment/shared`` for the process-global environment that is created
/// lazily at launch based on build configuration and the `APP_ENVIRONMENT` process
/// environment variable.
///
/// - Important: Avoid creating your own instances unless you are writing previews or tests.
///
public final class AppEnvironment {

    // MARK: - Properties

    /// Application settings used throughout the app.
    public let appSettings: AppSettings

    /// Engineering mode
    internal let engineeringMode: EngineeringMode

    /// The SwiftData model container holding subscriptions, categories,
    /// and payment methods.
    public let modelContainer: ModelContainer

    /// Daily-cached exchange rates for display-currency conversion.
    internal let exchangeRateService: ExchangeRateService

    /// Scheduled local reminder notifications.
    internal let notificationManager: NotificationManager

    // MARK: - Init

    /// Creates an environment with the provided dependencies.
    ///
    /// - Parameters:
    ///    - appSettings: The application settings to expose.
    /// - Note: Use ``live()``/``mock()`` rather than this initializer.
    ///
    internal init(
        appSettings: AppSettings,
        engineeringMode: EngineeringMode,
        modelContainer: ModelContainer,
        exchangeRateService: ExchangeRateService
    ) {
        self.appSettings = appSettings
        self.engineeringMode = engineeringMode
        self.modelContainer = modelContainer
        self.exchangeRateService = exchangeRateService
        self.notificationManager = NotificationManager(
            modelContainer: modelContainer,
            appSettings: appSettings
        )
    }
}
