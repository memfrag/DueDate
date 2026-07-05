//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import Foundation
import SwiftUI

/// Shared navigation state: sidebar selection, selected subscription,
/// and the modal editor target. Owned by `Sidebar` and injected into the
/// environment so the table, inspector, toolbar, and notification
/// deep-links all coordinate through it.
@Observable
final class AppNavigationModel {

    var selection: SidebarPane? = .dashboard

    /// The `Subscription.id` of the currently selected subscription.
    var selectedSubscriptionID: UUID?

    /// When non-nil, the modal subscription editor sheet is presented.
    var editorTarget: EditorTarget?

    /// Selects the subscriptions pane and highlights a specific subscription
    /// (used by notification deep-links).
    func reveal(subscriptionID: UUID) {
        selection = .subscriptions
        selectedSubscriptionID = subscriptionID
    }
}

/// What the modal subscription editor is editing.
enum EditorTarget: Identifiable, Hashable {
    case new
    case edit(UUID)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}
