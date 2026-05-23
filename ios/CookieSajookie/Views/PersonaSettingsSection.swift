import SwiftUI

/// Settings section showing the active persona and the Cycle button.
struct PersonaSettingsSection: View {
    @Bindable var viewModel: PersonaSettingsViewModel
    var onCycle: () -> Void

    var body: some View {
        Section {
            personaCard
            cycleButton
            advancedDisclosure
        } header: {
            Text("Browsing Profile")
        } footer: {
            Text("One internally-consistent device persona for the entire app. Cycling wipes all web data and cold-starts the app under a new persona.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var personaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: deviceSymbol)
                    .font(.title2)
                    .foregroundStyle(Color(hex: "#14B8A6"))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: "#14B8A6").opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.persona.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("iOS \(viewModel.persona.iosVersion.dotted)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Text("ACTIVE")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#22C55E").opacity(0.2)))
                    .foregroundStyle(Color(hex: "#22C55E"))
            }
            VStack(alignment: .leading, spacing: 6) {
                statRow(label: "Screen", value: viewModel.screenLine)
                statRow(label: "GPU", value: viewModel.gpuLine)
                statRow(label: "Locale", value: viewModel.localeLine)
                statRow(label: "Hardware", value: viewModel.hardwareLine)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }

    private var deviceSymbol: String {
        switch viewModel.persona.deviceFamily {
        case .iPadPro11M4, .iPadPro13M4, .iPadAirM2, .iPadMini7: return "ipad"
        default: return "iphone"
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
        }
    }

    private var cycleButton: some View {
        Button(action: onCycle) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.semibold))
                Text("Cycle Profile")
                    .font(.body.weight(.semibold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
    }

    private var advancedDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                advancedRow(title: "User-Agent", value: viewModel.persona.userAgent)
                advancedRow(title: "Accept-Language", value: viewModel.persona.acceptLanguageHeader)
                advancedRow(title: "Platform", value: viewModel.persona.platform)
                advancedRow(title: "Persona ID", value: viewModel.persona.id)
            }
            .padding(.top, 6)
        } label: {
            Label("Advanced", systemImage: "wrench.adjustable")
                .foregroundStyle(.white.opacity(0.8))
        }
        .tint(.white.opacity(0.6))
    }

    private func advancedRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .textSelection(.enabled)
        }
    }
}
