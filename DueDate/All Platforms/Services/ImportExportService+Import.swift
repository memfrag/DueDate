//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// Reading a JSON backup produced by ``ImportExportService/makeBackupData(context:settings:)``
/// (spec Section 26).
///
/// Records are matched on their stored `UUID`, never on name. The model carries
/// no `@Attribute(.unique)` — CloudKit forbids it — so "one record per id" is
/// enforced here, in the write layer, exactly as the CloudKit guide prescribes.
extension ImportExportService {

    // MARK: - Types

    enum ImportMode: Sendable {
        /// Update records that already exist, insert the ones that don't,
        /// delete nothing. Idempotent: importing twice changes nothing the
        /// second time.
        case merge
        /// Wipe all subscriptions, categories and payment methods, then insert
        /// the backup's. With CloudKit mirroring on, those deletions propagate
        /// to every signed-in device, so the caller must confirm first.
        case replaceAll
    }

    struct ImportSummary: Sendable {
        var subscriptionsInserted = 0
        var subscriptionsUpdated = 0
        var categoriesInserted = 0
        var categoriesUpdated = 0
        var paymentMethodsInserted = 0
        var paymentMethodsUpdated = 0
        var deleted = 0
    }

    enum ImportError: LocalizedError {
        case unsupportedFormatVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormatVersion(let version):
                "This backup uses format version \(version), which this version of DueDate can't read."
            }
        }
    }

    // MARK: - Reading

    /// Decodes and validates a backup file without touching the store.
    /// Call this before asking the user how to apply it, so a malformed file
    /// fails before any destructive choice is offered.
    static func readBackup(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: data)
        guard backup.formatVersion <= BackupFile.currentFormatVersion else {
            throw ImportError.unsupportedFormatVersion(backup.formatVersion)
        }
        return backup
    }

    // MARK: - Applying

    @discardableResult
    static func applyBackup(
        _ backup: BackupFile,
        mode: ImportMode,
        context: ModelContext,
        settings: AppSettings
    ) throws -> ImportSummary {
        var summary = ImportSummary()

        if mode == .replaceAll {
            summary.deleted = try deleteAll(context: context)
        }

        // Categories and payment methods first: subscriptions reference them.
        var categoriesByID = try existingByID(SubscriptionCategory.self, context: context, id: \.id)

        // `BuiltInSeeder` seeds the 16 built-in categories once per store with
        // freshly generated ids, so "Streaming" has a different id on every
        // device. Matching those on id alone would duplicate all 16 whenever a
        // backup is restored onto a store that has ever launched — which is
        // every store. Fall back to matching a built-in by name; the survivor
        // adopts the backup's id, so the two stores converge.
        var builtInsByName = Dictionary(
            categoriesByID.values
                .filter(\.isBuiltIn)
                .map { ($0.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for dto in backup.categories {
            if let existing = categoriesByID[dto.id] {
                apply(dto, to: existing)
                summary.categoriesUpdated += 1
            } else if dto.isBuiltIn, let existing = builtInsByName[dto.name.lowercased()] {
                apply(dto, to: existing)
                categoriesByID[dto.id] = existing
                builtInsByName[dto.name.lowercased()] = nil
                summary.categoriesUpdated += 1
            } else {
                let category = SubscriptionCategory()
                apply(dto, to: category)
                context.insert(category)
                categoriesByID[dto.id] = category
                summary.categoriesInserted += 1
            }
        }

        var paymentMethodsByID = try existingByID(PaymentMethod.self, context: context, id: \.id)
        for dto in backup.paymentMethods {
            if let existing = paymentMethodsByID[dto.id] {
                apply(dto, to: existing)
                summary.paymentMethodsUpdated += 1
            } else {
                let paymentMethod = PaymentMethod()
                apply(dto, to: paymentMethod)
                context.insert(paymentMethod)
                paymentMethodsByID[dto.id] = paymentMethod
                summary.paymentMethodsInserted += 1
            }
        }

        var subscriptionsByID = try existingByID(Subscription.self, context: context, id: \.id)
        for dto in backup.subscriptions {
            let subscription: Subscription
            if let existing = subscriptionsByID[dto.id] {
                subscription = existing
                summary.subscriptionsUpdated += 1
            } else {
                subscription = Subscription()
                context.insert(subscription)
                subscriptionsByID[dto.id] = subscription
                summary.subscriptionsInserted += 1
            }
            apply(
                dto,
                to: subscription,
                categories: categoriesByID,
                paymentMethods: paymentMethodsByID
            )
        }

        // A restore reinstates the settings that were captured with the data;
        // a merge leaves the current settings alone, since there is no
        // meaningful way to merge two scalar preferences.
        if mode == .replaceAll {
            settings.displayCurrencyCode = backup.settings.displayCurrencyCode
            settings.reminderDefaultsMonthly = backup.settings.reminderDefaultsMonthly
            settings.reminderDefaultsAnnual = backup.settings.reminderDefaultsAnnual
            settings.reminderDefaultsTrial = backup.settings.reminderDefaultsTrial
            settings.reminderDefaultsManual = backup.settings.reminderDefaultsManual
        }

        try context.save()
        return summary
    }

    // MARK: - Helpers

    private static func deleteAll(context: ModelContext) throws -> Int {
        let subscriptions = try context.fetch(FetchDescriptor<Subscription>())
        let categories = try context.fetch(FetchDescriptor<SubscriptionCategory>())
        let paymentMethods = try context.fetch(FetchDescriptor<PaymentMethod>())
        // Subscriptions first so the nullify rules on the other two have
        // nothing left to nullify.
        subscriptions.forEach(context.delete)
        categories.forEach(context.delete)
        paymentMethods.forEach(context.delete)
        return subscriptions.count + categories.count + paymentMethods.count
    }

    /// Indexes existing records by id. The model has no uniqueness constraint,
    /// so duplicate ids are possible in principle; the first one wins and the
    /// rest are left untouched rather than silently overwritten.
    private static func existingByID<T: PersistentModel>(
        _ type: T.Type,
        context: ModelContext,
        id: (T) -> UUID
    ) throws -> [UUID: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        return Dictionary(models.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func apply(_ dto: BackupFile.CategoryDTO, to category: SubscriptionCategory) {
        category.id = dto.id
        category.name = dto.name
        category.colorHex = dto.colorHex
        category.symbolName = dto.symbolName
        category.isBuiltIn = dto.isBuiltIn
        category.sortOrder = dto.sortOrder
    }

    private static func apply(_ dto: BackupFile.PaymentMethodDTO, to paymentMethod: PaymentMethod) {
        paymentMethod.id = dto.id
        paymentMethod.displayName = dto.displayName
        paymentMethod.kindRaw = dto.kind
        paymentMethod.institutionName = dto.institutionName
        paymentMethod.lastFour = dto.lastFour
        paymentMethod.expirationDate = dto.expirationDate
        paymentMethod.owner = dto.owner
        paymentMethod.notes = dto.notes
        paymentMethod.isArchived = dto.isArchived
        paymentMethod.isSampleData = dto.isSampleData
    }

    private static func apply(
        _ dto: BackupFile.SubscriptionDTO,
        to subscription: Subscription,
        categories: [UUID: SubscriptionCategory],
        paymentMethods: [UUID: PaymentMethod]
    ) {
        subscription.id = dto.id
        subscription.name = dto.name
        subscription.subscriptionDescription = dto.description
        subscription.statusRaw = dto.status
        // Amounts round-trip as strings to avoid binary-float drift; parsed
        // through AmountParser so a file written under any locale reads back.
        subscription.amount = AmountParser.parse(dto.amount) ?? Decimal(0)
        subscription.currencyCode = dto.currencyCode
        subscription.billingCycleKindRaw = dto.billingCycleKind
        subscription.billingCycleValue = dto.billingCycleValue
        subscription.billingCycleUnitRaw = dto.billingCycleUnit
        subscription.billingAnchorDay = dto.billingAnchorDay
        subscription.startDate = dto.startDate
        subscription.nextBillingDate = dto.nextBillingDate
        subscription.endDate = dto.endDate
        subscription.trialEndDate = dto.trialEndDate
        subscription.contractEndDate = dto.contractEndDate
        subscription.autoRenews = dto.autoRenews
        subscription.renewalMethodRaw = dto.renewalMethod
        subscription.renewalMethodOtherLabel = dto.renewalMethodOtherLabel
        subscription.managedThroughRaw = dto.managedThrough
        subscription.managedThroughOtherLabel = dto.managedThroughOtherLabel
        subscription.category = dto.categoryID.flatMap { categories[$0] }
        subscription.paymentMethod = dto.paymentMethodID.flatMap { paymentMethods[$0] }
        subscription.accountEmail = dto.accountEmail
        subscription.websiteURLString = dto.websiteURL
        subscription.cancellationURLString = dto.cancellationURL
        subscription.cancellationNotes = dto.cancellationNotes
        subscription.noticePeriodValue = dto.noticePeriodValue
        subscription.noticePeriodUnitRaw = dto.noticePeriodUnit
        subscription.notes = dto.notes
        subscription.reminderPolicyRaw = dto.reminderPolicy
        subscription.reminderDaysBefore = dto.reminderDaysBefore
        subscription.isSampleData = dto.isSampleData
        subscription.createdAt = dto.createdAt
        subscription.updatedAt = dto.updatedAt
    }
}
