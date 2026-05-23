import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingsVM = SettingsViewModel()
    @State private var personaVM = PersonaSettingsViewModel()
    @State private var cycleVM = CycleProfileViewModel()
    @State private var showCycleOverlay: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Form {
                    PersonaSettingsSection(viewModel: personaVM) {
                        startCycle()
                    }
                    cookiesSection
                    privacyResetSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "#14B8A6"))
                }
            }
            .alert(
                "Privacy Reset Complete",
                isPresented: Binding(
                    get: { settingsVM.resetMessage != nil },
                    set: { if !$0 { settingsVM.resetMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { settingsVM.resetMessage = nil }
            } message: {
                Text(settingsVM.resetMessage ?? "")
            }
            .fullScreenCover(isPresented: $showCycleOverlay) {
                CycleOverlayView(viewModel: cycleVM)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startCycle() {
        showCycleOverlay = true
        Task { await cycleVM.startCycle() }
    }

    private var cookiesSection: some View {
        Section {
            HStack {
                Label("Accept All Cookies", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.white)
                Spacer()
                Text("Always On")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#22C55E").opacity(0.25)))
                    .foregroundStyle(Color(hex: "#22C55E"))
            }
            HStack {
                Label("Third-Party Cookies", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.white)
                Spacer()
                Text("Always On")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#22C55E").opacity(0.25)))
                    .foregroundStyle(Color(hex: "#22C55E"))
            }
        } header: {
            Text("Cookies")
        } footer: {
            Text("CookieSajookie always accepts all cookies, including third-party cookies, so imported sessions work reliably.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var privacyResetSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await settingsVM.resetPrivacyState() }
            } label: {
                HStack {
                    Label("Reset Browser State", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(Color(hex: "#EF4444"))
                    Spacer()
                    if settingsVM.isResettingPrivacyState {
                        ProgressView().tint(Color(hex: "#EF4444"))
                    }
                }
            }
            .disabled(settingsVM.isResettingPrivacyState)
        } header: {
            Text("Privacy Reset")
        } footer: {
            Text("Clears cookies, website data, URL cache, and temporary files without changing the active persona.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
                .foregroundStyle(.white)
            LabeledContent("Build", value: buildNumber)
                .foregroundStyle(.white)
        } header: {
            Text("About")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
