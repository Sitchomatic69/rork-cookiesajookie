import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let profile: BrowsingProfile
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                let entries = viewModel.entries(for: profile)
                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No history yet").font(.headline).foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title.isEmpty ? entry.urlString : entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(entry.urlString)
                                    .font(.caption).foregroundStyle(profile.color)
                                    .lineLimit(1)
                                Text(entry.visitedAt.formatted(.relative(presentation: .named)))
                                    .font(.caption2).foregroundStyle(.white.opacity(0.5))
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.delete(entry, context: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(profile.color)
                }
                if !profile.historyEntries.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button(role: .destructive) {
                                viewModel.clearHistory(for: profile, context: modelContext)
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").foregroundStyle(profile.color)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
