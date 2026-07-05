//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Category management: edit, merge, and blocked delete (spec Section 20).
struct CategoriesPane: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\SubscriptionCategory.sortOrder),
        SortDescriptor(\SubscriptionCategory.name)
    ]) private var categories: [SubscriptionCategory]

    @State private var editorTarget: CategoryEditorTarget?
    @State private var reassignmentSource: SubscriptionCategory?

    var body: some View {
        List {
            ForEach(categories) { category in
                row(category)
            }
        }
        .listStyle(.inset)
        .navigationSubtitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorTarget = .new
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
                .help("Add a new category")
            }
        }
        .sheet(item: $editorTarget) { target in
            CategoryEditorView(target: target)
        }
        .sheet(item: $reassignmentSource) { source in
            reassignmentDialog(for: source)
        }
    }

    private func row(_ category: SubscriptionCategory) -> some View {
        HStack {
            Image(systemName: category.symbolName.isEmpty ? "square.grid.2x2" : category.symbolName)
                .foregroundStyle(category.color)
                .frame(width: 24)
            Text(category.name)
                .fontWeight(.medium)
            Spacer()
            Text("\(category.subscriptions?.count ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contextMenu {
            Button("Edit…") {
                editorTarget = .edit(category.id)
            }
            Divider()
            Button("Delete", role: .destructive) {
                requestDelete(category)
            }
        }
    }

    private func reassignmentDialog(for source: SubscriptionCategory) -> some View {
        let count = source.subscriptions?.count ?? 0
        return ReassignmentDialog(
            title: "Category In Use",
            message: "\"\(source.name)\" is used by \(count) subscription\(count == 1 ? "" : "s"). Choose another category for them (merging into it), or remove the category from them, before deleting.",
            options: categories
                .filter { $0.id != source.id }
                .map { ReassignmentDialog.Option(id: $0.id, name: $0.name) },
            onReassign: { option in
                reassignAndDelete(source, to: option)
            }
        )
    }

    private func requestDelete(_ category: SubscriptionCategory) {
        if category.subscriptions?.isEmpty ?? true {
            modelContext.delete(category)
            try? modelContext.save()
        } else {
            // Blocked: in use. Require reassignment first (spec Section 20).
            reassignmentSource = category
        }
    }

    private func reassignAndDelete(_ source: SubscriptionCategory, to option: ReassignmentDialog.Option?) {
        let destination = option.flatMap { chosen in
            categories.first { $0.id == chosen.id }
        }
        for subscription in source.subscriptions ?? [] {
            subscription.category = destination
        }
        modelContext.delete(source)
        try? modelContext.save()
    }
}

/// What the category editor is editing.
enum CategoryEditorTarget: Identifiable, Hashable {
    case new
    case edit(UUID)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

#Preview {
    CategoriesPane()
        .previewEnvironment()
}
