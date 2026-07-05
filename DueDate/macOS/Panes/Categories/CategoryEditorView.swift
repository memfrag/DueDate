//
//  Copyright © 2026 Apparata AB. All rights reserved.
//

import SwiftUI
import SwiftData

/// Modal sheet for adding or editing a category, with color and symbol.
struct CategoryEditorView: View {

    let target: CategoryEditorTarget

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var colorHex: String = "3498DB"
    @State private var symbolName: String = "square.grid.2x2"
    @State private var isLoaded = false

    private static let colorChoices: [String] = [
        "E74C3C", "E91E63", "9B59B6", "8E44AD", "3498DB", "2980B9",
        "5DADE2", "1ABC9C", "16A085", "2ECC71", "27AE60", "F39C12",
        "D35400", "34495E", "7F8C8D", "95A5A6"
    ]

    private static let symbolChoices: [String] = [
        "square.grid.2x2", "play.tv", "wifi", "iphone", "app.badge",
        "icloud", "globe", "server.rack", "bolt", "gamecontroller",
        "newspaper", "music.note", "figure.run", "banknote", "shield",
        "person.2", "house", "car", "book", "fork.knife", "pawprint"
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Name", text: $name, prompt: Text("Streaming"))

                LabeledContent("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(24)), count: 8), spacing: 6) {
                        ForEach(Self.colorChoices, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 18, height: 18)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Picker("Symbol", selection: $symbolName) {
                    ForEach(Self.symbolChoices, id: \.self) { symbol in
                        Label {
                            Text(symbol)
                        } icon: {
                            Image(systemName: symbol)
                        }
                        .tag(symbol)
                    }
                }

                LabeledContent("Preview") {
                    HStack(spacing: 6) {
                        Image(systemName: symbolName)
                            .foregroundStyle(Color(hex: colorHex) ?? .gray)
                        Text(name.isEmpty ? "Category" : name)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
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
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 420, height: 320)
        .onAppear(perform: load)
    }

    private func load() {
        guard !isLoaded else { return }
        isLoaded = true
        if case .edit(let id) = target, let category = fetch(id: id) {
            name = category.name
            colorHex = category.colorHex.isEmpty ? "3498DB" : category.colorHex
            symbolName = category.symbolName.isEmpty ? "square.grid.2x2" : category.symbolName
        }
    }

    private func save() {
        let category: SubscriptionCategory
        if case .edit(let id) = target, let existing = fetch(id: id) {
            category = existing
        } else {
            category = SubscriptionCategory()
            category.sortOrder = (try? modelContext.fetchCount(
                FetchDescriptor<SubscriptionCategory>()
            )) ?? 0
            modelContext.insert(category)
        }
        category.name = name.trimmingCharacters(in: .whitespaces)
        category.colorHex = colorHex
        category.symbolName = symbolName
        try? modelContext.save()
        dismiss()
    }

    private func fetch(id: UUID) -> SubscriptionCategory? {
        let descriptor = FetchDescriptor<SubscriptionCategory>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    CategoryEditorView(target: .new)
        .previewEnvironment()
}
