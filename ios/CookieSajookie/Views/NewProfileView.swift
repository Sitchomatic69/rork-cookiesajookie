import SwiftUI
import SwiftData

struct NewProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = NewProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        preview
                            .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Name")
                            TextField("My profile", text: $viewModel.name)
                                .textFieldStyle(.plain)
                                .padding(14)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Color")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 14)], spacing: 14) {
                                ForEach(ProfilePalette.colors, id: \.self) { hex in
                                    Button {
                                        viewModel.colorHex = hex
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Circle()
                                                    .stroke(.white, lineWidth: viewModel.colorHex == hex ? 3 : 0)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Icon")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 10)], spacing: 10) {
                                ForEach(ProfilePalette.icons, id: \.self) { symbol in
                                    Button {
                                        viewModel.iconName = symbol
                                    } label: {
                                        Image(systemName: symbol)
                                            .font(.title3)
                                            .foregroundStyle(viewModel.iconName == symbol ? .black : .white)
                                            .frame(width: 46, height: 46)
                                            .background(
                                                Circle().fill(viewModel.iconName == symbol ? Color(hex: viewModel.colorHex) : Color.white.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Toggle(isOn: $viewModel.isLocked) {
                            Label("Require Face ID / Passcode", systemImage: "lock.fill")
                                .foregroundStyle(.white)
                        }
                        .tint(Color(hex: viewModel.colorHex))
                        .padding(14)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: viewModel.colorHex))
                        .disabled(!viewModel.canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var preview: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(hex: viewModel.colorHex), Color(hex: viewModel.colorHex).opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: Color(hex: viewModel.colorHex).opacity(0.5), radius: 16, y: 8)
                Image(systemName: viewModel.iconName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(viewModel.name.isEmpty ? "Profile Name" : viewModel.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.5))
    }

    private func save() {
        if viewModel.createProfile(context: modelContext) {
            dismiss()
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: BrowsingProfile
    @State private var viewModel = EditProfileViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5))
                            TextField("Name", text: $profile.name)
                                .padding(14)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("COLOR").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 14)], spacing: 14) {
                                ForEach(ProfilePalette.colors, id: \.self) { hex in
                                    Button {
                                        profile.colorHex = hex
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 40, height: 40)
                                            .overlay(Circle().stroke(.white, lineWidth: profile.colorHex == hex ? 3 : 0))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("ICON").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.5))
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50), spacing: 10)], spacing: 10) {
                                ForEach(ProfilePalette.icons, id: \.self) { symbol in
                                    Button { profile.iconName = symbol } label: {
                                        Image(systemName: symbol)
                                            .font(.title3)
                                            .foregroundStyle(profile.iconName == symbol ? .black : .white)
                                            .frame(width: 46, height: 46)
                                            .background(Circle().fill(profile.iconName == symbol ? profile.color : Color.white.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Toggle(isOn: $profile.isLocked) {
                            Label("Require Face ID / Passcode", systemImage: "lock.fill")
                                .foregroundStyle(.white)
                        }
                        .tint(profile.color)
                        .padding(14)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.save(context: modelContext)
                        dismiss()
                    }.fontWeight(.bold).foregroundStyle(profile.color)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
