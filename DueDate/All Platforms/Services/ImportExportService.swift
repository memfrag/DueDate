//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// Builds export payloads (spec Section 26):
/// - JSON: complete, re-importable backup with IDs and relationships.
/// - CSV: flat, spreadsheet-friendly subscriptions table with resolved
///   display names and a computed monthly-equivalent column.
enum ImportExportService {

    // MARK: - JSON Backup

    static func makeBackupData(
        context: ModelContext,
        settings: AppSettings
    ) throws -> Data {
        let categories = (try? context.fetch(FetchDescriptor<SubscriptionCategory>())) ?? []
        let paymentMethods = (try? context.fetch(FetchDescriptor<PaymentMethod>())) ?? []
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>())) ?? []

        let backup = BackupFile(
            exportedAt: .now,
            settings: BackupFile.SettingsDTO(
                displayCurrencyCode: settings.displayCurrencyCode,
                reminderDefaultsMonthly: settings.reminderDefaultsMonthly,
                reminderDefaultsAnnual: settings.reminderDefaultsAnnual,
                reminderDefaultsTrial: settings.reminderDefaultsTrial,
                reminderDefaultsManual: settings.reminderDefaultsManual
            ),
            categories: categories.map { category in
                BackupFile.CategoryDTO(
                    id: category.id,
                    name: category.name,
                    colorHex: category.colorHex,
                    symbolName: category.symbolName,
                    isBuiltIn: category.isBuiltIn,
                    sortOrder: category.sortOrder
                )
            },
            paymentMethods: paymentMethods.map { paymentMethod in
                BackupFile.PaymentMethodDTO(
                    id: paymentMethod.id,
                    displayName: paymentMethod.displayName,
                    kind: paymentMethod.kindRaw,
                    institutionName: paymentMethod.institutionName,
                    lastFour: paymentMethod.lastFour,
                    expirationDate: paymentMethod.expirationDate,
                    owner: paymentMethod.owner,
                    notes: paymentMethod.notes,
                    isArchived: paymentMethod.isArchived,
                    isSampleData: paymentMethod.isSampleData
                )
            },
            subscriptions: subscriptions.map(subscriptionDTO)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    private static func subscriptionDTO(_ subscription: Subscription) -> BackupFile.SubscriptionDTO {
        BackupFile.SubscriptionDTO(
            id: subscription.id,
            name: subscription.name,
            description: subscription.subscriptionDescription,
            status: subscription.statusRaw,
            amount: "\(subscription.amount)",
            currencyCode: subscription.currencyCode,
            billingCycleKind: subscription.billingCycleKindRaw,
            billingCycleValue: subscription.billingCycleValue,
            billingCycleUnit: subscription.billingCycleUnitRaw,
            billingAnchorDay: subscription.billingAnchorDay,
            startDate: subscription.startDate,
            nextBillingDate: subscription.nextBillingDate,
            endDate: subscription.endDate,
            trialEndDate: subscription.trialEndDate,
            contractEndDate: subscription.contractEndDate,
            autoRenews: subscription.autoRenews,
            renewalMethod: subscription.renewalMethodRaw,
            renewalMethodOtherLabel: subscription.renewalMethodOtherLabel,
            managedThrough: subscription.managedThroughRaw,
            managedThroughOtherLabel: subscription.managedThroughOtherLabel,
            categoryID: subscription.category?.id,
            paymentMethodID: subscription.paymentMethod?.id,
            accountEmail: subscription.accountEmail,
            websiteURL: subscription.websiteURLString,
            cancellationURL: subscription.cancellationURLString,
            cancellationNotes: subscription.cancellationNotes,
            noticePeriodValue: subscription.noticePeriodValue,
            noticePeriodUnit: subscription.noticePeriodUnitRaw,
            notes: subscription.notes,
            reminderPolicy: subscription.reminderPolicyRaw,
            reminderDaysBefore: subscription.reminderDaysBefore,
            isSampleData: subscription.isSampleData,
            createdAt: subscription.createdAt,
            updatedAt: subscription.updatedAt
        )
    }

    // MARK: - CSV

    static func makeCSVData(
        context: ModelContext,
        settings: AppSettings,
        rateTable: RateTable?
    ) -> Data {
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? []

        let displayCurrency = settings.displayCurrencyCode
        let header = [
            "Name", "Category", "Status", "Amount", "Currency", "Billing Cycle",
            "Monthly Equivalent (\(displayCurrency))", "Next Due Date", "Auto-Renews",
            "Renewal Method", "Payment Method", "Managed Through", "Website",
            "Cancellation URL", "Account Email", "Start Date", "Trial End Date",
            "Contract End Date", "Notes", "Is Sample"
        ]

        var rows: [[String]] = [header]
        for subscription in subscriptions {
            let monthlyEquivalent = TotalsCalculator.convert(
                subscription.monthlyEquivalent,
                from: subscription.currencyCode,
                to: displayCurrency,
                table: rateTable
            )
            rows.append([
                subscription.name,
                subscription.categoryName,
                subscription.status.displayName,
                "\(subscription.amount)",
                subscription.currencyCode,
                subscription.billingCycle.displayName,
                monthlyEquivalent.map { "\($0.rounded(2))" } ?? "",
                isoDay(subscription.nextBillingDate),
                autoRenewsText(subscription.autoRenews),
                subscription.renewalMethod.displayName,
                subscription.paymentMethodName,
                subscription.managedThrough.displayName,
                subscription.websiteURLString,
                subscription.cancellationURLString,
                subscription.accountEmail,
                subscription.startDate.map(isoDay) ?? "",
                subscription.trialEndDate.map(isoDay) ?? "",
                subscription.contractEndDate.map(isoDay) ?? "",
                subscription.notes,
                subscription.isSampleData ? "Yes" : "No"
            ])
        }

        let csv = rows
            .map { row in row.map(escapeCSVField).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
        return Data(csv.utf8)
    }

    /// RFC 4180: quote fields containing commas, quotes, or line breaks.
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func isoDay(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    private static func autoRenewsText(_ autoRenews: Bool?) -> String {
        switch autoRenews {
        case true: "Yes"
        case false: "No"
        default: ""
        }
    }
}

private extension Decimal {
    nonisolated func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .bankers)
        return result
    }
}
