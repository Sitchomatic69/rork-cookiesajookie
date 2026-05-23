import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    let profile: BrowsingProfile
    @State private var store = ProfileStore()
    @State private var viewModel = ProfileDetailViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [profile.color.opacity(0.55), Color(hex: "#0A0A0F")],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    header
                        .padding(.top, 12)

                    statsRow
                        .padding(.horizontal, 20)

                    actionGrid
                        .padding(.horizontal, 20)

                    recentHistory
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("")
        .task { await store.loadCookies(for: profile) }
        .sheet(isPresented: $viewModel.showBrowser) {
            BrowserView(profile: profile)
        }
        .sheet(isPresented: $viewModel.showCookies) {
            CookieManagerView(profile: profile, store: store)
        }
        .sheet(isPresented: $viewModel.showHistory) {
            HistoryView(profile: profile)
        }
        .sheet(isPresented: $viewModel.showImportExport) {
            ImportExportView(profile: profile, store: store)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [profile.color.opacity(0.6), .clear],
                                       center: .center, startRadius: 10, endRadius: 120)
                    )
                    .frame(width: 180, height: 180)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(LinearGradient(colors: [profile.color, profile.color.opacity(0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                    .overlay(
                        Image(systemName: profile.iconName)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: profile.color.opacity(0.6), radius: 18, y: 8)
            }
            Text(profile.name)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if profile.isLocked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.15)))
                    .foregroundStyle(.white)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatPill(value: store.totalCookies, label: "Total", color: .white)
            StatPill(value: store.validCount, label: "Valid", color: Color(hex: "#22C55E"))
            StatPill(value: store.expiringSoonCount, label: "Expiring", color: Color(hex: "#F59E0B"))
            StatPill(value: store.expiredCount, label: "Expired", color: Color(hex: "#EF4444"))
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            actionCard(title: "Browse", systemImage: "safari.fill", tint: profile.color) { viewModel.showBrowser = true }
            actionCard(title: "Cookies", systemImage: "circle.hexagongrid.fill", tint: Color(hex: "#F59E0B")) { viewModel.showCookies = true }
            actionCard(title: "History", systemImage: "clock.arrow.circlepath", tint: Color(hex: "#3B82F6")) { viewModel.showHistory = true }
            actionCard(title: "Import / Export", systemImage: "square.and.arrow.up.on.square.fill", tint: Color(hex: "#A855F7")) { viewModel.showImportExport = true }
        }
    }

    private func actionCard(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.opacity(0.18)))
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var recentHistory: some View {
        let recent = viewModel.recentHistory(for: profile)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if !recent.isEmpty {
                    Button("See All") { viewModel.showHistory = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(profile.color)
                }
            }
            if recent.isEmpty {
                Text("No browsing history yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, entry in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(profile.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title.isEmpty ? entry.urlString : entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(entry.urlString)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        if idx < recent.count - 1 {
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.25), lineWidth: 1))
        )
    }
}
