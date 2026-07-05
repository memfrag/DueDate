//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData
import SwiftUIToolbox

struct Sidebar: View {

    @State private var navigation = AppNavigationModel()

    @State private var isInspectorPresented: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(ExchangeRateService.self) private var exchangeRates
    @Environment(NotificationManager.self) private var notifications

    @Query private var allSubscriptions: [Subscription]

    private var smartViewCounts: SmartViewCounts {
        SmartViewEvaluator.counts(for: allSubscriptions)
    }

    private var hasSampleData: Bool {
        allSubscriptions.contains { $0.isSampleData }
    }

    private func smartViewLink(_ smartView: SmartView) -> some View {
        NavigationLink(value: SidebarPane.smartView(smartView)) {
            // The badge must live on the label, not the NavigationLink:
            // wrapping the link in .badge() breaks List selection for it.
            Label(smartView.displayName, systemImage: smartView.symbolName)
                .badge(smartViewCounts[smartView])
        }
    }

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            List(selection: $navigation.selection) {

                Section {

                    NavigationLink(value: SidebarPane.dashboard) {
                        Label("Dashboard", systemImage: "house")
                    }

                    NavigationLink(value: SidebarPane.subscriptions) {
                        Label("Subscriptions", systemImage: "list.bullet.rectangle")
                    }

                    NavigationLink(value: SidebarPane.calendar) {
                        Label("Calendar", systemImage: "calendar")
                    }

                    NavigationLink(value: SidebarPane.reports) {
                        Label("Reports", systemImage: "chart.bar")
                    }

                    NavigationLink(value: SidebarPane.paymentMethods) {
                        Label("Payment Methods", systemImage: "creditcard")
                    }

                    NavigationLink(value: SidebarPane.categories) {
                        Label("Categories", systemImage: "square.grid.2x2")
                    }

                    NavigationLink(value: SidebarPane.archive) {
                        Label("Archive", systemImage: "archivebox")
                    }
                }

                Section(header: Text("Smart Views")) {
                    // Deliberately not a ForEach: ForEach's automatic row
                    // tagging (by its `id`) conflicts with the List's
                    // SidebarPane selection type and breaks selection.
                    smartViewLink(.dueIn7Days)
                    smartViewLink(.dueIn30Days)
                    smartViewLink(.annualRenewals)
                    smartViewLink(.trialsEnding)
                    smartViewLink(.autoRenewing)
                    smartViewLink(.needsAttention)
                }

                if hasSampleData {
                    Section {
                        Button {
                            SampleDataService.removeSamples(context: modelContext)
                        } label: {
                            Label("Remove Sample Data", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 320)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SidebarFooter()
            }
        } detail: {
            switch navigation.selection {
            case .dashboard:
                DashboardPane()
            case .subscriptions:
                SubscriptionsPane()
            case .calendar:
                CalendarPane()
            case .reports:
                ReportsPane()
            case .paymentMethods:
                PaymentMethodsPane()
            case .categories:
                CategoriesPane()
            case .archive:
                ArchivePane()
            case .smartView(let smartView):
                SubscriptionsPane(smartView: smartView)
            default:
                EmptyPane()
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            SubscriptionInspector()
                .inspectorColumnWidth(min: 240, ideal: 280, max: 400)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isInspectorPresented.toggle()
                } label: {
                    Label("Toggle Inspector", systemImage: "sidebar.trailing")
                }
            }
        }
        .sheet(item: $navigation.editorTarget) { target in
            SubscriptionEditorView(target: target)
        }
        .environment(navigation)
        .task {
            BuiltInSeeder.seedIfNeeded(context: modelContext)
            RenewalScheduler.performRollover(context: modelContext)
            await notifications.resync()
            await exchangeRates.refreshIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification
        )) { _ in
            // Keep due dates correct even if the app sits open across midnight.
            RenewalScheduler.performRollover(context: modelContext)
        }
        .onChange(of: notifications.pendingOpenSubscriptionID) {
            // Deep-link from an activated notification.
            if let subscriptionID = notifications.pendingOpenSubscriptionID {
                navigation.reveal(subscriptionID: subscriptionID)
                notifications.pendingOpenSubscriptionID = nil
            }
        }
    }
}

#Preview {
    Sidebar()
        .previewEnvironment()
}
