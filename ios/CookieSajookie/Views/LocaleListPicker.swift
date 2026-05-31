import SwiftUI

/// One selectable row in a `LocaleListPicker`.
struct LocalePickItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
}

/// Reusable searchable single-select list used for both the language and
/// timezone pickers. Pushed onto the existing settings `NavigationStack`.
struct LocaleListPicker: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let items: [LocalePickItem]
    let selected: String
    let onSelect: (String) -> Void

    @State private var query: String = ""

    private var filtered: [LocalePickItem] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
                || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                ForEach(filtered) { item in
                    Button {
                        onSelect(item.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .foregroundStyle(.white)
                                Text(item.subtitle)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            if item.id == selected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(Color(hex: "#14B8A6"))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }
}
