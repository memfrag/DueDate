//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation

/// The complete, re-importable JSON backup format (spec Section 26).
/// Relationships are preserved via UUIDs; `Decimal` values are encoded as
/// strings to avoid floating-point drift. v1.1 import reads this back.
nonisolated struct BackupFile: Codable, Sendable {

    var formatVersion: Int = 1
    var exportedAt: Date
    var settings: SettingsDTO
    var categories: [CategoryDTO]
    var paymentMethods: [PaymentMethodDTO]
    var subscriptions: [SubscriptionDTO]

    struct SettingsDTO: Codable, Sendable {
        var displayCurrencyCode: String
        var reminderDefaultsMonthly: String
        var reminderDefaultsAnnual: String
        var reminderDefaultsTrial: String
        var reminderDefaultsManual: String
    }

    struct CategoryDTO: Codable, Sendable {
        var id: UUID
        var name: String
        var colorHex: String
        var symbolName: String
        var isBuiltIn: Bool
        var sortOrder: Int
    }

    struct PaymentMethodDTO: Codable, Sendable {
        var id: UUID
        var displayName: String
        var kind: String
        var institutionName: String
        var lastFour: String
        var expirationDate: Date?
        var owner: String
        var notes: String
        var isArchived: Bool
        var isSampleData: Bool
    }

    struct SubscriptionDTO: Codable, Sendable {
        var id: UUID
        var name: String
        var description: String
        var status: String
        var amount: String
        var currencyCode: String
        var billingCycleKind: String
        var billingCycleValue: Int
        var billingCycleUnit: String
        var billingAnchorDay: Int
        var startDate: Date?
        var nextBillingDate: Date
        var endDate: Date?
        var trialEndDate: Date?
        var contractEndDate: Date?
        var autoRenews: Bool?
        var renewalMethod: String
        var renewalMethodOtherLabel: String
        var managedThrough: String
        var managedThroughOtherLabel: String
        var categoryID: UUID?
        var paymentMethodID: UUID?
        var accountEmail: String
        var websiteURL: String
        var cancellationURL: String
        var cancellationNotes: String
        var noticePeriodValue: Int
        var noticePeriodUnit: String
        var notes: String
        var reminderPolicy: String
        var reminderDaysBefore: [Int]
        var isSampleData: Bool
        var createdAt: Date
        var updatedAt: Date
    }
}
