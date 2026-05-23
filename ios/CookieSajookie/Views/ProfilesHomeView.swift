import SwiftUI
import SwiftData

struct ProfilesHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrowsingProfile.createdAt, order: .forward) private var profiles: [BrowsingProfile]

    @State private var viewModel = ProfilesHomeViewModel()

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: "#0A0A0F"), Color(hex: "#111122")],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        if profiles.isEmpty {
                            emptyState
                                .padding(.top, 80)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(profiles) { profile in
                                    ProfileCard(profile: profile) {
                                        Task { await viewModel.open(profile) }
                                    }
                                    .contextMenu {
                                            Button { viewModel.profileToEdit = profile } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button {
                                                Task { await viewModel.clone(profile, context: modelContext) }
                                            } label: {
                                                Label("Clone", systemImage: "doc.on.doc")
                                            }
                                            Button(role: .destructive) {
                                                Task { await viewModel.delete(profile, context: modelContext) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }

                                NewProfileCard {
                                    viewModel.showNewProfile = true
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showNewProfile) {
                NewProfileView()
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .sheet(item: $viewModel.profileToEdit) { profile in
                EditProfileView(profile: profile)
            }
            .navigationDestination(item: $viewModel.pendingProfile) { profile in
                ProfileDetailView(profile: profile)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CookieSajookie")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(profiles.count) \(profiles.count == 1 ? "profile" : "profiles")")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button {
                viewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(hex: "#14B8A6").opacity(0.3), .clear],
                                       center: .center, startRadius: 0, endRadius: 120)
                    )
                    .frame(width: 240, height: 240)
                Image(systemName: "person.2.crop.square.stack.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(hex: "#14B8A6"))
            }
            Text("No profiles yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Create a profile to keep its cookies\nand browsing data separate.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                viewModel.showNewProfile = true
            } label: {
                Text("Create Profile")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: "#14B8A6")))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

}

private struct ProfileCard: View {
    let profile: BrowsingProfile
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: [profile.color, profile.color.opacity(0.55)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                    Image(systemName: profile.iconName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    if profile.isLocked {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Circle().fill(.black.opacity(0.35)))
                                    .padding(6)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 110)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(profile.cachedCookies.count) cookies")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NewProfileCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text("New Profile")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 174)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundStyle(.white.opacity(0.18))
            )
        }
        .buttonStyle(.plain)
    }
}

