//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// The window's root. Owns the navigation model and hosts the first-launch
/// welcome.
///
/// The welcome sheet lives here rather than in ``Sidebar`` on purpose: Sidebar
/// already presents the subscription editor, and two `.sheet` modifiers stacked
/// on one view collapse to a single presentation. Hosting it a level up keeps
/// the two nested rather than competing.
struct RootView: View {

    @State private var navigation = AppNavigationModel()
    @State private var isShowingWelcome = false

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Sidebar()
            .environment(navigation)
            .sheet(isPresented: $isShowingWelcome) {
                OnboardingView(
                    onAddFirstSubscription: {
                        completeWelcome()
                        navigation.selection = .subscriptions
                        navigation.editorTarget = .new
                    },
                    onExploreSampleData: {
                        completeWelcome()
                        SampleDataService.seedSamples(context: modelContext)
                        navigation.selection = .subscriptions
                    },
                    onSkip: { completeWelcome() }
                )
                .interactiveDismissDisabled()
            }
            .task {
                evaluateWelcome()
            }
    }

    /// Shows the welcome only to a genuinely new store. Anyone who already has
    /// subscriptions — an existing install picking up this build — is marked
    /// done silently rather than greeted as a newcomer.
    private func evaluateWelcome() {
        guard !settings.hasCompletedOnboarding else { return }

        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<Subscription>())) ?? 0
        if existingCount > 0 {
            settings.hasCompletedOnboarding = true
        } else {
            isShowingWelcome = true
        }
    }

    private func completeWelcome() {
        settings.hasCompletedOnboarding = true
        isShowingWelcome = false
    }
}

#if DEBUG
#Preview {
    RootView()
        .previewEnvironment()
}
#endif
