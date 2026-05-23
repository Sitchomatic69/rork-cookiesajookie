import SwiftUI
import SwiftData

enum CookieManagerTab: String, CaseIterable {
    case cookies = "Cookies"
    case snapshots = "Snapshots"
}

struct CookieManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let profile: BrowsingProfile
    var store: ProfileStore
    var currentHost: String? = nil

    @State private var viewModel = CookieManagerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $viewModel.selectedTab) {
                        ForEach(CookieManagerTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if viewModel.selectedTab == .cookies {
                        statsBar
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        filterBar
                            .padding(.top, 8)
                        cookiesContent
                    } else {
                        SnapshotListView(profile: profile, store: store, profileColor: profile.color)
                    }
                }
                .overlay(alignment: .top) {
                    if viewModel.showCleanedBanner {
                        Text("Removed \(viewModel.cleanedCount) expired \(viewModel.cleanedCount == 1 ? "cookie" : "cookies")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(hex: "#22C55E")))
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(viewModel.selectedTab.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(profile.color)
                }
                if viewModel.selectedTab == .cookies {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Sort", selection: $viewModel.sortMode) {
                                ForEach(CookieSetSort.allCases, id: \.self) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                            Divider()
                            Button {
                                viewModel.showImportExport = true
                            } label: {
                                Label("Import / Export", systemImage: "square.and.arrow.up.on.square")
                            }
                            Button {
                                viewModel.showCleanAlert = true
                            } label: {
                                Label("Clean Expired", systemImage: "sparkles")
                            }
                            Button {
                                viewModel.prepareSnapshot()
                            } label: {
                                Label("Save Snapshot", systemImage: "camera.viewfinder")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(profile.color)
                        }
                    }
                }
            }
            .task { await store.loadCookies(for: profile) }
            .alert("Clean expired cookies?", isPresented: $viewModel.showCleanAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clean", role: .destructive) { Task { await clean() } }
            } message: {
                Text("This will remove \(store.expiredCount) expired cookies.")
            }
            .alert("Save Snapshot", isPresented: $viewModel.showSaveSnapshot) {
                TextField("Label", text: $viewModel.newSnapshotLabel)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    Task {
                        _ = await store.saveSnapshot(for: profile, label: viewModel.newSnapshotLabel, in: modelContext)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showImportExport) {
                ImportExportView(profile: profile, store: store)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    private var statsBar: some View {
        HStack(spacing: 8) {
            statPill("\(allSets.count)", label: "Sets", color: profile.color)
            statPill("\(store.totalCookies)", label: "Total", color: .white)
            statPill("\(store.validCount)", label: "Valid", color: Color(hex: "#22C55E"))
            statPill("\(store.expiredCount)", label: "Expired", color: Color(hex: "#EF4444"))
        }
    }

    private func statPill(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(color)
            Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
            TextField("Search sets, domains, or cookies", text: $viewModel.searchText)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(CookiePartyFilter.allCases, id: \.self) { f in
                    filterChip(label: f.label, isActive: viewModel.partyFilter == f, color: f == .third ? Color(hex: "#F59E0B") : Color(hex: "#3B82F6")) {
                        viewModel.partyFilter = f
                    }
                }
                Divider().frame(height: 16).background(Color.white.opacity(0.15)).padding(.horizontal, 4)
                filterChip(label: "All purposes", isActive: viewModel.purposeFilter == nil, color: .white) {
                    viewModel.purposeFilter = nil
                }
                ForEach(CookiePurpose.allCases, id: \.self) { p in
                    filterChip(label: p.label, isActive: viewModel.purposeFilter == p, color: Color(hex: p.colorHex), icon: p.systemImage) {
                        viewModel.purposeFilter = (viewModel.purposeFilter == p) ? nil : p
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(label: String, isActive: Bool, color: Color, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
                Text(label).font(.system(size: 11, weight: .bold))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(isActive ? color.opacity(0.3) : Color.white.opacity(0.06)))
            .overlay(Capsule().stroke(isActive ? color.opacity(0.6) : Color.clear, lineWidth: 1))
            .foregroundStyle(isActive ? color : .white.opacity(0.65))
        }
        .buttonStyle(.plain)
    }

    private var effectiveHost: String? {
        viewModel.effectiveHost(from: currentHost)
    }

    private var allSets: [CookieSet] {
        viewModel.allSets(cookies: store.cookies, currentHost: currentHost)
    }

    private var filteredSets: [CookieSet] {
        viewModel.filteredSets(cookies: store.cookies, currentHost: currentHost)
    }

    @ViewBuilder
    private var cookiesContent: some View {
        if store.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).tint(profile.color)
        } else if filteredSets.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.3))
                Text(viewModel.searchText.isEmpty && viewModel.partyFilter == .all && viewModel.purposeFilter == nil ? "No cookies yet" : "No matches")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
                if viewModel.searchText.isEmpty && viewModel.partyFilter == .all && viewModel.purposeFilter == nil {
                    Button("Import Cookies") { viewModel.showImportExport = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Capsule().fill(profile.color))
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredSets) { set in
                        CookieSetCard(
                            set: set,
                            isExpanded: viewModel.expanded.contains(set.id),
                            profileColor: profile.color,
                            onToggle: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.toggleSet(set.id)
                                }
                            },
                            onDeleteSet: {
                                Task {
                                    for c in set.cookies { await store.deleteCookie(c, from: profile) }
                                }
                            },
                            onDeleteCookie: { c in
                                Task { await store.deleteCookie(c, from: profile) }
                            },
                            onCopySet: {
                                viewModel.copySet(set)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private func clean() async {
        await viewModel.cleanExpiredCookies(from: profile, store: store)
    }
}

private struct CookieSetCard: View {
    let set: CookieSet
    let isExpanded: Bool
    let profileColor: Color
    let onToggle: () -> Void
    let onDeleteSet: () -> Void
    let onDeleteCookie: (CookieData) -> Void
    let onCopySet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AsyncImage(url: faviconURL) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFit()
                            } else {
                                Image(systemName: "globe")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.rootDomain)
                                .font(.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text("\(set.cookies.count) cookies")
                                Text("·")
                                Text(byteString)
                                if set.domainsCount > 1 {
                                    Text("·")
                                    Text("\(set.domainsCount) subdomains")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        partyBadge
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if !set.purposes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(set.purposes, id: \.self) { p in
                                    HStack(spacing: 3) {
                                        Image(systemName: p.systemImage).font(.system(size: 8, weight: .bold))
                                        Text(p.label).font(.system(size: 10, weight: .bold))
                                    }
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Color(hex: p.colorHex).opacity(0.22)))
                                    .foregroundStyle(Color(hex: p.colorHex))
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider().overlay(Color.white.opacity(0.08))
                    ForEach(set.cookies) { cookie in
                        CookieDetailRow(cookie: cookie)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .swipeActions {
                                Button(role: .destructive) {
                                    onDeleteCookie(cookie)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        Divider().overlay(Color.white.opacity(0.05))
                    }
                    HStack(spacing: 10) {
                        Button {
                            onCopySet()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(profileColor)
                        Spacer()
                        Button(role: .destructive) {
                            onDeleteSet()
                        } label: {
                            Label("Delete Set", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var faviconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(set.rootDomain)&sz=64")
    }

    private var byteString: String {
        let b = set.totalBytes
        if b < 1024 { return "\(b) B" }
        let kb = Double(b) / 1024.0
        return String(format: "%.1f KB", kb)
    }

    @ViewBuilder
    private var partyBadge: some View {
        let color: Color = set.isFirstParty ? Color(hex: "#3B82F6") : Color(hex: "#F59E0B")
        Text(set.isFirstParty ? "1st" : "3rd")
            .font(.system(size: 10, weight: .heavy))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.22)))
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 0.5))
            .foregroundStyle(color)
    }
}

private struct CookieDetailRow: View {
    let cookie: CookieData

    var statusColor: Color {
        switch cookie.status {
        case .valid: return Color(hex: "#22C55E")
        case .expiringSoon: return Color(hex: "#F59E0B")
        case .expired: return Color(hex: "#EF4444")
        case .session: return Color(hex: "#3B82F6")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(statusColor).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(cookie.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(purposeOfCookie.label)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: purposeOfCookie.colorHex).opacity(0.22)))
                        .foregroundStyle(Color(hex: purposeOfCookie.colorHex))
                }
                Text(cookie.value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(cookie.domain)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    if cookie.isSecure { tag("Secure", color: Color(hex: "#22C55E")) }
                    if cookie.isHTTPOnly { tag("HttpOnly", color: Color(hex: "#A855F7")) }
                    if cookie.sameSite != .unspecified {
                        tag("SS=\(cookie.sameSite.rawValue.capitalized)", color: Color(hex: "#3B82F6"))
                    }
                    if cookie.isSessionOnly { tag("Session", color: Color(hex: "#F59E0B")) }
                }
            }
        }
    }

    private var purposeOfCookie: CookiePurpose {
        CookiePurposeClassifier.classify(cookie)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundStyle(color)
    }
}

struct SnapshotListView: View {
    @Environment(\.modelContext) private var modelContext
    let profile: BrowsingProfile
    var store: ProfileStore
    let profileColor: Color
    @State private var viewModel = SnapshotListViewModel()

    var body: some View {
        let snaps = viewModel.snapshots(for: profile)
        Group {
            if snaps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No snapshots yet").font(.headline).foregroundStyle(.white.opacity(0.6))
                    Text("Save the current cookie jar to restore it later.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(snaps) { snap in
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundStyle(profileColor)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(profileColor.opacity(0.2)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.label).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text("\(snap.cookies.count) cookies • \(snap.createdAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Button("Restore") {
                                Task { await store.restoreSnapshot(snap, to: profile) }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(profileColor)
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.delete(snap, context: modelContext)
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
    }
}
