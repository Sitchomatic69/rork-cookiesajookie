import SwiftUI

/// Settings row that summarises the active locale and pushes the editor.
struct LocaleSettingsSection: View {
    private var override: LocaleOverride { ProfileManager.shared.localeOverride }
    private var persona: BrowsingPersona { ProfileManager.shared.activePersona }

    var body: some View {
        Section {
            NavigationLink {
                LocaleSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.title2)
                        .foregroundStyle(Color(hex: "#14B8A6"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(hex: "#14B8A6").opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Locale")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(summary)
                            .font(.caption.monospaced())
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(override.mode == .custom ? "CUSTOM" : "AUTO")
                        .font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(badgeColor.opacity(0.2)))
                        .foregroundStyle(badgeColor)
                }
            }
        } header: {
            Text("Locale")
        } footer: {
            Text("Choose the language and timezone every web view and request reports. A custom locale persists across profile cycles.")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    private var summary: String {
        "\(LocaleCatalog.languageLabel(persona.language)) · \(LocaleCatalog.timezoneCity(persona.timezone))"
    }

    private var badgeColor: Color {
        override.mode == .custom ? Color(hex: "#14B8A6") : Color(hex: "#22C55E")
    }
}
