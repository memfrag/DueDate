//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// A mutable value-type mirror of `Subscription` used as the editor's draft.
/// Gives the modal sheet an explicit Save/Cancel commit boundary: nothing
/// touches the model until Save.
struct SubscriptionDraft {

    var name: String = ""
    var subscriptionDescription: String = ""
    var status: SubscriptionStatus = .active

    var amount: Decimal = 0
    var currencyCode: String = "SEK"

    var billingCycleKind: BillingCycleKind = .monthly
    var customCycleValue: Int = 1
    var customCycleUnit: BillingUnit = .months

    var nextBillingDate: Date = .now
    var hasStartDate: Bool = false
    var startDate: Date = .now
    var hasTrialEndDate: Bool = false
    var trialEndDate: Date = .now
    var hasEndDate: Bool = false
    var endDate: Date = .now
    var hasContractEndDate: Bool = false
    var contractEndDate: Date = .now

    var autoRenews: Bool? = nil
    var renewalMethodKind: RenewalMethodKind = .unknown
    var renewalMethodOtherLabel: String = ""
    var managedThroughKind: ManagedThroughKind = .unknown
    var managedThroughOtherLabel: String = ""

    var category: SubscriptionCategory?
    var paymentMethod: PaymentMethod?

    var accountEmail: String = ""
    var websiteURLString: String = ""
    var cancellationURLString: String = ""
    var cancellationNotes: String = ""
    var noticePeriodValue: Int = 0
    var noticePeriodUnit: BillingUnit = .days
    var notes: String = ""

    var reminderPolicy: ReminderPolicy = .useDefaults
    var reminderDaysBefore: [Int] = []

    init() {}

    init(subscription: Subscription) {
        name = subscription.name
        subscriptionDescription = subscription.subscriptionDescription
        status = subscription.status
        amount = subscription.amount
        currencyCode = subscription.currencyCode
        billingCycleKind = subscription.billingCycle.kind
        if case .custom(let value, let unit) = subscription.billingCycle {
            customCycleValue = value
            customCycleUnit = unit
        }
        nextBillingDate = subscription.nextBillingDate
        hasStartDate = subscription.startDate != nil
        startDate = subscription.startDate ?? .now
        hasTrialEndDate = subscription.trialEndDate != nil
        trialEndDate = subscription.trialEndDate ?? .now
        hasEndDate = subscription.endDate != nil
        endDate = subscription.endDate ?? .now
        hasContractEndDate = subscription.contractEndDate != nil
        contractEndDate = subscription.contractEndDate ?? .now
        autoRenews = subscription.autoRenews
        renewalMethodKind = RenewalMethodKind(rawValue: subscription.renewalMethodRaw) ?? .unknown
        renewalMethodOtherLabel = subscription.renewalMethodOtherLabel
        managedThroughKind = ManagedThroughKind(rawValue: subscription.managedThroughRaw) ?? .unknown
        managedThroughOtherLabel = subscription.managedThroughOtherLabel
        category = subscription.category
        paymentMethod = subscription.paymentMethod
        accountEmail = subscription.accountEmail
        websiteURLString = subscription.websiteURLString
        cancellationURLString = subscription.cancellationURLString
        cancellationNotes = subscription.cancellationNotes
        noticePeriodValue = subscription.noticePeriodValue
        noticePeriodUnit = BillingUnit(rawValue: subscription.noticePeriodUnitRaw) ?? .days
        notes = subscription.notes
        reminderPolicy = subscription.reminderPolicy
        reminderDaysBefore = subscription.reminderDaysBefore
    }

    var billingCycle: BillingCycle {
        switch billingCycleKind {
        case .weekly: .weekly
        case .monthly: .monthly
        case .quarterly: .quarterly
        case .semiAnnual: .semiAnnual
        case .annual: .annual
        case .custom: .custom(value: max(1, customCycleValue), unit: customCycleUnit)
        }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    /// Writes the draft back onto a model object.
    func apply(to subscription: Subscription) {
        subscription.name = name.trimmingCharacters(in: .whitespaces)
        subscription.subscriptionDescription = subscriptionDescription
        subscription.status = status
        subscription.amount = amount
        subscription.currencyCode = currencyCode
        subscription.billingCycle = billingCycle
        subscription.nextBillingDate = nextBillingDate
        subscription.startDate = hasStartDate ? startDate : nil
        subscription.trialEndDate = hasTrialEndDate ? trialEndDate : nil
        subscription.endDate = hasEndDate ? endDate : nil
        subscription.contractEndDate = hasContractEndDate ? contractEndDate : nil
        subscription.autoRenews = autoRenews
        subscription.renewalMethodRaw = renewalMethodKind.rawValue
        subscription.renewalMethodOtherLabel = renewalMethodKind == .other ? renewalMethodOtherLabel : ""
        subscription.managedThroughRaw = managedThroughKind.rawValue
        subscription.managedThroughOtherLabel = managedThroughKind == .other ? managedThroughOtherLabel : ""
        subscription.category = category
        subscription.paymentMethod = paymentMethod
        subscription.accountEmail = accountEmail
        subscription.websiteURLString = websiteURLString
        subscription.cancellationURLString = cancellationURLString
        subscription.cancellationNotes = cancellationNotes
        subscription.noticePeriodValue = noticePeriodValue
        subscription.noticePeriodUnitRaw = noticePeriodUnit.rawValue
        subscription.notes = notes
        subscription.reminderPolicy = reminderPolicy
        subscription.reminderDaysBefore = reminderDaysBefore

        // Month-based cycles keep their day-of-month anchor so a subscription
        // billed on the 31st stays on month-end across short months.
        let isMonthBased: Bool = switch billingCycle {
        case .monthly, .quarterly, .semiAnnual, .annual: true
        case .custom(_, let unit): unit == .months || unit == .years
        case .weekly: false
        }
        subscription.billingAnchorDay = isMonthBased
            ? Calendar.current.component(.day, from: nextBillingDate)
            : 0

        subscription.updatedAt = .now
    }
}

/// Modal sheet for adding or editing a subscription.
/// The inspector stays read-only; this sheet is the only write path.
struct SubscriptionEditorView: View {

    let target: EditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationManager.self) private var notifications

    @Query(sort: \SubscriptionCategory.sortOrder) private var categories: [SubscriptionCategory]
    @Query(filter: #Predicate<PaymentMethod> { !$0.isArchived }, sort: \PaymentMethod.displayName)
    private var paymentMethods: [PaymentMethod]

    @State private var draft = SubscriptionDraft()
    @State private var isLoaded = false
    @State private var isCreatingPaymentMethod = false

    private var isNew: Bool {
        if case .new = target { true } else { false }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                overviewSection
                billingSection
                renewalAndPaymentSection
                cancellationSection
                remindersSection
                notesSection
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if !isNew {
                    Button("Delete", role: .destructive) {
                        deleteSubscription()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
            .padding()
        }
        .frame(width: 560, height: 680)
        .navigationTitle(isNew ? "Add Subscription" : "Edit Subscription")
        .onAppear(perform: load)
        .sheet(isPresented: $isCreatingPaymentMethod) {
            PaymentMethodEditorView(target: .new) { paymentMethod in
                draft.paymentMethod = paymentMethod
            }
        }
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section("Overview") {
            TextField("Name", text: $draft.name, prompt: Text("Netflix, example.com, …"))

            TextField("Description", text: $draft.subscriptionDescription,
                      prompt: Text("Standard plan (2 screens)"))

            Picker("Category", selection: $draft.category) {
                Text("None").tag(nil as SubscriptionCategory?)
                ForEach(categories) { category in
                    Text(category.name).tag(category as SubscriptionCategory?)
                }
            }

            Picker("Status", selection: $draft.status) {
                ForEach(SubscriptionStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }

            if draft.status == .cancelledStillActive {
                Toggle("Access until", isOn: $draft.hasEndDate)
                if draft.hasEndDate {
                    DatePicker("Paid through", selection: $draft.endDate, displayedComponents: .date)
                }
            }

            if draft.status == .trial {
                Toggle("Trial end date", isOn: $draft.hasTrialEndDate)
                if draft.hasTrialEndDate {
                    DatePicker("Trial ends", selection: $draft.trialEndDate, displayedComponents: .date)
                }
            }

            TextField("Website", text: $draft.websiteURLString, prompt: Text("https://…"))
        }
    }

    private var billingSection: some View {
        Section("Billing") {
            HStack {
                TextField("Amount", value: $draft.amount, format: .number.precision(.fractionLength(0...2)))
                Picker("Currency", selection: $draft.currencyCode) {
                    ForEach(exchangeRates.supportedCurrencyCodes, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }

            Picker("Billing cycle", selection: $draft.billingCycleKind) {
                ForEach(BillingCycleKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if draft.billingCycleKind == .custom {
                HStack {
                    Text("Every")
                    TextField("Value", value: $draft.customCycleValue, format: .number)
                        .frame(width: 60)
                        .labelsHidden()
                    Picker("Unit", selection: $draft.customCycleUnit) {
                        ForEach(BillingUnit.allCases, id: \.self) { unit in
                            Text(unit.pluralName).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
            }

            DatePicker("Next due date", selection: $draft.nextBillingDate, displayedComponents: .date)

            Toggle("Start date", isOn: $draft.hasStartDate)
            if draft.hasStartDate {
                DatePicker("Started", selection: $draft.startDate, displayedComponents: .date)
            }

            Toggle("Contract end date", isOn: $draft.hasContractEndDate)
            if draft.hasContractEndDate {
                DatePicker("Contract ends", selection: $draft.contractEndDate, displayedComponents: .date)
            }
        }
    }

    private var renewalAndPaymentSection: some View {
        Section("Renewal & Payment") {
            Picker("Renews automatically", selection: $draft.autoRenews) {
                Text("Unknown").tag(nil as Bool?)
                Text("Yes").tag(true as Bool?)
                Text("No").tag(false as Bool?)
            }

            Picker(selection: $draft.renewalMethodKind) {
                ForEach(RenewalMethodKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Renewal method")
                    HelpPopoverButton(
                        title: "Renewal method",
                        text: "How the subscription renews — the mechanism that triggers the charge, like a card on file, an App Store subscription, Autogiro, or a manual renewal you make yourself. It tells you where the renewal can be interrupted."
                    )
                }
            }

            if draft.renewalMethodKind == .other {
                TextField("Renewal method name", text: $draft.renewalMethodOtherLabel)
            }

            HStack {
                Picker(selection: $draft.paymentMethod) {
                    Text("None").tag(nil as PaymentMethod?)
                    ForEach(paymentMethods) { paymentMethod in
                        Text(paymentMethod.displayName).tag(paymentMethod as PaymentMethod?)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("Payment method")
                        HelpPopoverButton(
                            title: "Payment method",
                            text: "What actually pays — the card or account the money leaves, like “Visa Debit •••• 1234” or a PayPal account. Payment methods are reusable records shared across subscriptions, so you can see everything charged to one card. Use aliases, never full card numbers."
                        )
                    }
                }
                Button {
                    isCreatingPaymentMethod = true
                } label: {
                    Label("New…", systemImage: "plus")
                        .labelStyle(.titleOnly)
                }
                .help("Create a new payment method and select it")
            }
            if paymentMethods.isEmpty {
                Text("No payment methods yet — create one with “New…”, e.g. “Visa Debit •••• 1234” or “PayPal”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Managed through", selection: $draft.managedThroughKind) {
                ForEach(ManagedThroughKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if draft.managedThroughKind == .other {
                TextField("Managed through name", text: $draft.managedThroughOtherLabel)
            }

            TextField("Account email", text: $draft.accountEmail, prompt: Text("name@example.com"))
        }
    }

    private var cancellationSection: some View {
        Section("Cancellation") {
            TextField("Cancellation URL", text: $draft.cancellationURLString, prompt: Text("https://…"))
            TextField("Cancellation notes", text: $draft.cancellationNotes,
                      prompt: Text("Settings > Account > Cancel"), axis: .vertical)
                .lineLimit(2...4)
            HStack {
                Text("Notice period")
                TextField("Value", value: $draft.noticePeriodValue, format: .number)
                    .frame(width: 60)
                    .labelsHidden()
                Picker("Unit", selection: $draft.noticePeriodUnit) {
                    ForEach(BillingUnit.allCases, id: \.self) { unit in
                        Text(unit.pluralName).tag(unit)
                    }
                }
                .labelsHidden()
                Text("(0 = none)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            Picker("Remind me", selection: $draft.reminderPolicy) {
                ForEach(ReminderPolicy.allCases, id: \.self) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            if draft.reminderPolicy == .custom {
                ReminderOffsetsField(offsets: $draft.reminderDaysBefore)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    // MARK: - Actions

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        if case .edit(let id) = target, let subscription = fetchSubscription(id: id) {
            draft = SubscriptionDraft(subscription: subscription)
        }
    }

    private func save() {
        let subscription: Subscription
        if case .edit(let id) = target, let existing = fetchSubscription(id: id) {
            subscription = existing
        } else {
            subscription = Subscription()
            modelContext.insert(subscription)
        }
        draft.apply(to: subscription)
        try? modelContext.save()

        let remindersActive = subscription.reminderPolicy != .disabled
            && subscription.status.allowsReminders
        Task {
            // Permission is requested lazily, on first actual reminder setup.
            if remindersActive {
                await notifications.requestAuthorizationIfNeeded()
            }
            await notifications.resync()
        }
        dismiss()
    }

    private func deleteSubscription() {
        if case .edit(let id) = target, let subscription = fetchSubscription(id: id) {
            modelContext.delete(subscription)
            try? modelContext.save()
            Task {
                await notifications.resync()
            }
        }
        dismiss()
    }

    private func fetchSubscription(id: UUID) -> Subscription? {
        let descriptor = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

/// Edits a list of "days before" reminder offsets as comma-separated text.
struct ReminderOffsetsField: View {

    @Binding var offsets: [Int]

    @State private var text: String = ""

    var body: some View {
        TextField("Days before (comma-separated)", text: $text, prompt: Text("30, 7, 1"))
            .onAppear {
                text = offsets.map(String.init).joined(separator: ", ")
            }
            .onChange(of: text) {
                offsets = text
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { $0 >= 0 }
            }
    }
}

#Preview {
    SubscriptionEditorView(target: .new)
        .previewEnvironment()
}
