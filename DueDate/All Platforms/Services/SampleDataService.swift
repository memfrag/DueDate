//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftData

/// Opt-in sample data for exploring the app (spec Section 29).
/// Every sample record is flagged (`isSampleData`) and removable in one action;
/// nothing is ever seeded without an explicit user choice.
enum SampleDataService {

    static func hasSamples(context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.isSampleData }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    // MARK: - Seed

    // swiftlint:disable:next function_body_length
    static func seedSamples(context: ModelContext) {
        guard !hasSamples(context: context) else { return }

        BuiltInSeeder.seedIfNeeded(context: context)

        func category(_ name: String) -> SubscriptionCategory? {
            let descriptor = FetchDescriptor<SubscriptionCategory>(
                predicate: #Predicate { $0.name == name }
            )
            return try? context.fetch(descriptor).first
        }

        // Sample payment methods (aliases only, per privacy guidance).
        let visaDebit = PaymentMethod(displayName: "Visa Debit •••• 1234", kind: .debitCard, lastFour: "1234")
        let paypal = PaymentMethod(displayName: "PayPal", kind: .paypal)
        let handelsbanken = PaymentMethod(
            displayName: "Handelsbanken household account",
            kind: .bankAccount,
            institutionName: "Handelsbanken"
        )
        let appleID = PaymentMethod(displayName: "Apple ID / Mastercard •••• 9876", kind: .appleAccount, lastFour: "9876")
        let sebAccount = PaymentMethod(
            displayName: "SEB •••• 8765",
            kind: .bankAccount,
            institutionName: "SEB",
            lastFour: "8765"
        )
        for paymentMethod in [visaDebit, paypal, handelsbanken, appleID, sebAccount] {
            paymentMethod.isSampleData = true
            context.insert(paymentMethod)
        }

        struct Sample {
            var name: String
            var description: String = ""
            var website: String = ""
            var categoryName: String
            var amount: Decimal
            var cycle: BillingCycle = .monthly
            var daysUntilDue: Int
            var status: SubscriptionStatus = .active
            var renewal: RenewalMethod
            var managed: ManagedThrough = .serviceWebsite
            var payment: PaymentMethod?
            var cancellationURL: String = ""
            var autoRenews: Bool? = true
        }

        let samples: [Sample] = [
            Sample(name: "Netflix", description: "Standard plan (2 screens)",
                   website: "https://www.netflix.com", categoryName: "Streaming",
                   amount: 159, daysUntilDue: 2, renewal: .cardOnFile,
                   payment: visaDebit, cancellationURL: "https://netflix.com/cancel"),
            Sample(name: "Disney+", website: "https://www.disneyplus.com", categoryName: "Streaming",
                   amount: 119, daysUntilDue: 5, renewal: .paypalAutomaticPayment,
                   managed: .paypal, payment: paypal),
            Sample(name: "Mobile Plan", website: "https://www.telia.se", categoryName: "Mobile",
                   amount: 249, daysUntilDue: 6, renewal: .autogiro,
                   managed: .bankOrAutogiro, payment: handelsbanken),
            Sample(name: "iCloud+ 200GB", website: "https://www.apple.com", categoryName: "Cloud",
                   amount: 39, daysUntilDue: 8, renewal: .appStoreSubscription,
                   managed: .appleAppStore, payment: appleID),
            Sample(name: "Internet (Home)", website: "https://www.bahnhof.se", categoryName: "Internet",
                   amount: 399, daysUntilDue: 10, renewal: .autogiro,
                   managed: .bankOrAutogiro, payment: handelsbanken),
            Sample(name: "Adobe Creative Cloud", website: "https://www.adobe.com", categoryName: "Software",
                   amount: 239, daysUntilDue: 12, renewal: .cardOnFile, payment: visaDebit),
            Sample(name: "Spotify Premium", website: "https://www.spotify.com", categoryName: "Music",
                   amount: 109, daysUntilDue: 14, renewal: .paypalAutomaticPayment,
                   managed: .paypal, payment: paypal),
            Sample(name: "Domain: example.com", description: "Renewed manually at registrar",
                   website: "https://www.example.com", categoryName: "Domains",
                   amount: 139, cycle: .annual, daysUntilDue: 104, renewal: .manual,
                   payment: visaDebit, autoRenews: false),
            Sample(name: "1Password", website: "https://1password.com", categoryName: "Software",
                   amount: 359, cycle: .annual, daysUntilDue: 143, renewal: .cardOnFile,
                   payment: appleID),
            Sample(name: "Gym Membership", website: "https://www.stc.se", categoryName: "Fitness",
                   amount: 299, daysUntilDue: 20, renewal: .autogiro,
                   managed: .bankOrAutogiro, payment: sebAccount),
            Sample(name: "YouTube Premium", website: "https://www.youtube.com", categoryName: "Streaming",
                   amount: 79, daysUntilDue: 25, status: .trial, renewal: .googlePlaySubscription,
                   managed: .googlePlay, payment: nil),
            Sample(name: "Home Insurance", website: "https://www.lansforsakringar.se",
                   categoryName: "Insurance", amount: 243, daysUntilDue: 17,
                   renewal: .autogiro, managed: .bankOrAutogiro, payment: handelsbanken)
        ]

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for sample in samples {
            let subscription = Subscription()
            subscription.name = sample.name
            subscription.subscriptionDescription = sample.description
            subscription.websiteURLString = sample.website
            subscription.category = category(sample.categoryName)
            subscription.amount = sample.amount
            subscription.currencyCode = "SEK"
            subscription.billingCycle = sample.cycle
            subscription.status = sample.status
            subscription.renewalMethod = sample.renewal
            subscription.managedThrough = sample.managed
            subscription.paymentMethod = sample.payment
            subscription.cancellationURLString = sample.cancellationURL
            subscription.autoRenews = sample.autoRenews
            let dueDate = calendar.date(byAdding: .day, value: sample.daysUntilDue, to: today) ?? today
            subscription.nextBillingDate = dueDate
            if sample.status == .trial {
                subscription.trialEndDate = dueDate
            }
            let isMonthBased = sample.cycle.kind != .weekly
            subscription.billingAnchorDay = isMonthBased ? calendar.component(.day, from: dueDate) : 0
            subscription.isSampleData = true
            context.insert(subscription)
        }

        try? context.save()
    }

    // MARK: - Remove

    /// Removes all sample subscriptions and sample payment methods in one action.
    static func removeSamples(context: ModelContext) {
        let subscriptions = (try? context.fetch(
            FetchDescriptor<Subscription>(predicate: #Predicate { $0.isSampleData })
        )) ?? []
        for subscription in subscriptions {
            context.delete(subscription)
        }

        let paymentMethods = (try? context.fetch(
            FetchDescriptor<PaymentMethod>(predicate: #Predicate { $0.isSampleData })
        )) ?? []
        for paymentMethod in paymentMethods {
            context.delete(paymentMethod)
        }

        try? context.save()
    }
}
