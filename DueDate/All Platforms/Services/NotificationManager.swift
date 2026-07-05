//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData
import UserNotifications
import OSLog
#if os(macOS)
import AppKit
#endif

/// Schedules and maintains local reminder notifications (spec Section 19).
///
/// - Permission is requested lazily, the first time reminders become active,
///   never at app launch.
/// - Notifications are pre-scheduled via `UNUserNotificationCenter`, so they
///   fire even when the app is quit.
/// - `resync()` is idempotent: it diffs the desired set (stable, content-derived
///   identifiers) against the pending set, removing stale requests and adding
///   missing ones. Run it on launch and after any data change.
@Observable
final class NotificationManager {

    /// Deep-link target set when the user activates a notification.
    var pendingOpenSubscriptionID: UUID?

    /// Set once the user has granted (or been asked for) authorization.
    private(set) var authorizationRequested = false

    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private let appSettings: AppSettings
    @ObservationIgnored private let delegate = NotificationCenterDelegate()
    @ObservationIgnored private let logger = Logger(
        subsystem: "io.apparata.DueDate", category: "Notifications"
    )

    static weak var shared: NotificationManager?

    private static let reminderIDPrefix = "reminder."
    private static let snoozeIDPrefix = "snooze."
    static let categoryIdentifier = "subscriptionReminder"
    static let markHandledActionID = "markHandled"
    static let snoozeActionID = "snooze"

    /// Scheduling horizon and cap: the system keeps at most 64 pending
    /// requests, so schedule the soonest 60 within 90 days.
    private static let horizonDays = 90
    private static let maxScheduled = 60

    init(modelContainer: ModelContainer, appSettings: AppSettings) {
        self.modelContainer = modelContainer
        self.appSettings = appSettings
        Self.shared = self
        UNUserNotificationCenter.current().delegate = delegate
        registerCategory()
    }

    // MARK: - Authorization

    /// Requests notification permission if not yet determined.
    /// Called the first time a reminder is actually set up.
    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationRequested = true
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.warning("Notification authorization failed: \(error)")
        }
    }

    private var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional: return true
            default: return false
            }
        }
    }

    // MARK: - Sync

    /// Re-syncs the pending notification schedule against current data.
    func resync() async {
        guard await isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        let desired = desiredRequests()
        let desiredIDs = Set(desired.map(\.identifier))

        let pending = await center.pendingNotificationRequests()
        let pendingReminderIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.reminderIDPrefix) }

        let staleIDs = pendingReminderIDs.filter { !desiredIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        let existingIDs = Set(pendingReminderIDs)
        for request in desired where !existingIDs.contains(request.identifier) {
            do {
                try await center.add(request)
            } catch {
                logger.warning("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Builds the desired notification requests from current subscriptions.
    private func desiredRequests() -> [UNNotificationRequest] {
        let context = modelContainer.mainContext
        guard let subscriptions = try? context.fetch(FetchDescriptor<Subscription>()) else {
            return []
        }

        let calendar = Calendar.current
        let now = Date.now
        let horizon = calendar.date(byAdding: .day, value: Self.horizonDays, to: now) ?? now

        struct Planned {
            var identifier: String
            var fireDate: Date
            var content: UNMutableNotificationContent
        }

        var planned: [Planned] = []

        for subscription in subscriptions where subscription.status.allowsReminders {
            let offsets = resolvedOffsets(for: subscription)
            guard !offsets.isEmpty else { continue }

            let targetDate = subscription.status == .trial
                ? (subscription.trialEndDate ?? subscription.nextBillingDate)
                : subscription.nextBillingDate
            let targetDay = calendar.startOfDay(for: targetDate)
            let targetDayString = targetDay.formatted(.iso8601.year().month().day())

            for offset in Set(offsets) {
                guard let fireDay = calendar.date(byAdding: .day, value: -offset, to: targetDay),
                      var fireDate = calendar.date(
                        bySettingHour: 9, minute: 0, second: 0, of: fireDay
                      ) else { continue }
                // Same-day reminders created after 09:00 would otherwise be dropped.
                if offset == 0 && fireDate < now {
                    fireDate = now.addingTimeInterval(60)
                }
                guard fireDate > now, fireDate <= horizon else { continue }

                let identifier = "\(Self.reminderIDPrefix)\(subscription.id.uuidString).\(targetDayString).\(offset)"
                let content = notificationContent(
                    for: subscription, offset: offset, targetDate: targetDate
                )
                planned.append(Planned(identifier: identifier, fireDate: fireDate, content: content))
            }
        }

        return planned
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(Self.maxScheduled)
            .map { plan in
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: plan.fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                return UNNotificationRequest(
                    identifier: plan.identifier, content: plan.content, trigger: trigger
                )
            }
    }

    /// Resolves the effective "days before" offsets for a subscription:
    /// its own custom offsets, the app-wide defaults, or none.
    private func resolvedOffsets(for subscription: Subscription) -> [Int] {
        switch subscription.reminderPolicy {
        case .disabled:
            return []
        case .custom:
            return subscription.reminderDaysBefore
        case .useDefaults:
            if subscription.status == .trial {
                return appSettings.reminderOffsets(.trial)
            }
            if !subscription.effectivelyAutoRenews {
                return appSettings.reminderOffsets(.manual)
            }
            switch subscription.billingCycle {
            case .weekly, .monthly:
                return appSettings.reminderOffsets(.monthly)
            case .quarterly, .semiAnnual, .annual:
                return appSettings.reminderOffsets(.annual)
            case .custom(_, let unit):
                return unit == .days || unit == .weeks
                    ? appSettings.reminderOffsets(.monthly)
                    : appSettings.reminderOffsets(.annual)
            }
        }
    }

    private func notificationContent(
        for subscription: Subscription,
        offset: Int,
        targetDate: Date
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let relative = switch offset {
        case 0: "today"
        case 1: "tomorrow"
        default: "in \(offset) days"
        }
        let amountText = subscription.amount
            .formatted(.currency(code: subscription.currencyCode))
        let dateText = targetDate.formatted(.dateTime.month(.wide).day())

        if subscription.status == .trial {
            content.title = "\(subscription.name) trial ends \(relative)"
            content.body = "The trial ends on \(dateText). \(amountText) will be charged unless you cancel."
        } else if subscription.effectivelyAutoRenews {
            content.title = "\(subscription.name) renews \(relative)"
            var body = "\(amountText) will be charged on \(dateText)."
            if let paymentMethod = subscription.paymentMethod {
                body += " Paid by \(paymentMethod.displayName)."
            }
            content.body = body
        } else {
            content.title = "\(subscription.name) is due \(relative)"
            content.body = "Manual renewal: \(amountText) due on \(dateText)."
        }

        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["subscriptionID": subscription.id.uuidString]
        return content
    }

    // MARK: - Actions

    private func registerCategory() {
        let markHandled = UNNotificationAction(
            identifier: Self.markHandledActionID,
            title: "Mark Handled"
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeActionID,
            title: "Snooze 1 Day"
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [markHandled, snooze],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// The Sendable subset of a notification needed to handle a response.
    nonisolated struct ResponsePayload: Sendable {
        var title: String
        var body: String
        var subscriptionID: UUID?
    }

    /// Handles a user response to a notification (called from the delegate).
    func handleResponse(
        actionIdentifier: String,
        requestIdentifier: String,
        payload: ResponsePayload
    ) {
        switch actionIdentifier {
        case Self.markHandledActionID:
            // Drop any other pending reminders for the same subscription+target.
            guard requestIdentifier.hasPrefix(Self.reminderIDPrefix) else { return }
            let withoutOffset = requestIdentifier
                .split(separator: ".")
                .dropLast()
                .joined(separator: ".")
            Task {
                let center = UNUserNotificationCenter.current()
                let pending = await center.pendingNotificationRequests()
                let siblings = pending
                    .map(\.identifier)
                    .filter { $0.hasPrefix(withoutOffset) }
                center.removePendingNotificationRequests(withIdentifiers: siblings)
            }

        case Self.snoozeActionID:
            // Re-deliver a copy of this notification tomorrow at 09:00.
            let calendar = Calendar.current
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now),
                  let fireDate = calendar.date(
                    bySettingHour: 9, minute: 0, second: 0, of: tomorrow
                  ) else { return }
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "\(Self.snoozeIDPrefix)\(requestIdentifier).\(Int(fireDate.timeIntervalSince1970))"
            let content = UNMutableNotificationContent()
            content.title = payload.title
            content.body = payload.body
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            if let subscriptionID = payload.subscriptionID {
                content.userInfo = ["subscriptionID": subscriptionID.uuidString]
            }
            let request = UNNotificationRequest(
                identifier: identifier, content: content, trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)

        default:
            // Default tap: open the app at the subscription.
            if let subscriptionID = payload.subscriptionID {
                pendingOpenSubscriptionID = subscriptionID
            }
            #if os(macOS)
            NSApplication.shared.activate()
            #endif
        }
    }
}

// MARK: - Delegate

/// Forwards `UNUserNotificationCenter` delegate callbacks (which arrive on a
/// background queue) onto the main actor. Only Sendable values are captured.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show reminders even while the app is frontmost.
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let request = response.notification.request
        let requestIdentifier = request.identifier
        let content = request.content
        // Extract only Sendable values before hopping to the main actor.
        let payload = NotificationManager.ResponsePayload(
            title: content.title,
            body: content.body,
            subscriptionID: (content.userInfo["subscriptionID"] as? String)
                .flatMap(UUID.init(uuidString:))
        )

        Task { @MainActor in
            NotificationManager.shared?.handleResponse(
                actionIdentifier: actionIdentifier,
                requestIdentifier: requestIdentifier,
                payload: payload
            )
        }
        completionHandler()
    }
}
