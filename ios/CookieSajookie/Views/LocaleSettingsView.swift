import SwiftUI

/// Editor for the custom locale that the whole app reports. Pushed from the
/// Locale row in Settings. Every change applies live to the active persona.
struct LocaleSettingsView: View {
    @State private var vm = LocaleSettingsViewModel()

    private let accent = Color(hex: "#14B8A6")

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Form {
                modeSection
                if vm.isCustom {
                    languageSection
                    timezoneSection
                    quickFillSection
                }
                previewSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Locale")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    // MARK: - Mode

    private var modeSection: some View {
        Section {
            Picker("Locale Source", selection: modeBinding) {
                ForEach(LocaleMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.white.opacity(0.05))
        } footer: {
            Text(vm.isCustom
                 ? "Every web view and request reports the language and timezone you choose below."
                 : "Uses the active persona's built-in locale (English – United States, Pacific time).")
        }
    }

    private var modeBinding: Binding<LocaleMode> {
        Binding(get: { vm.mode }, set: { vm.mode = $0 })
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            NavigationLink {
                LocaleListPicker(
                    title: "Language",
                    items: vm.languageItems,
                    selected: vm.draft.primaryLanguage,
                    onSelect: { vm.setPrimaryLanguage($0) }
                )
            } label: {
                row(label: "Primary", value: vm.primaryLanguageLabel, mono: vm.draft.primaryLanguage)
            }
            .listRowBackground(Color.white.opacity(0.05))

            ForEach(vm.additionalLanguages, id: \.self) { code in
                HStack {
                    Label(LocaleCatalog.languageLabel(code), systemImage: "globe")
                        .foregroundStyle(.white)
                    Spacer()
                    Text(code)
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.5))
                    Button {
                        vm.removeAdditionalLanguage(code)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Color(hex: "#EF4444"))
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }

            if !vm.addableLanguages.isEmpty {
                Menu {
                    ForEach(vm.addableLanguages) { lang in
                        Button("\(lang.label) · \(lang.code)") { vm.addLanguage(lang.code) }
                    }
                } label: {
                    Label("Add Fallback Language", systemImage: "plus.circle.fill")
                        .foregroundStyle(accent)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
        } header: {
            Text("Language")
        } footer: {
            Text("Primary is reported first; fallbacks fill out navigator.languages and the Accept-Language header.")
        }
    }

    // MARK: - Timezone

    private var timezoneSection: some View {
        Section {
            NavigationLink {
                LocaleListPicker(
                    title: "Timezone",
                    items: vm.timezoneItems,
                    selected: vm.draft.timezone,
                    onSelect: { vm.setTimezone($0) }
                )
            } label: {
                row(label: vm.timezoneCity, value: vm.timezoneOffset, mono: vm.draft.timezone)
            }
            .listRowBackground(Color.white.opacity(0.05))
        } header: {
            Text("Timezone")
        } footer: {
            Text("Drives Intl.DateTimeFormat and Date.getTimezoneOffset. Match it to the language's region to stay believable.")
        }
    }

    // MARK: - Quick fill

    private var quickFillSection: some View {
        Section {
            Button {
                vm.matchDevice()
            } label: {
                Label("Match This Device", systemImage: "wand.and.stars")
                    .foregroundStyle(accent)
            }
            .listRowBackground(Color.white.opacity(0.05))

            Button(role: .destructive) {
                vm.resetToDefault()
            } label: {
                Label("Reset to Persona Default", systemImage: "arrow.uturn.backward")
            }
            .listRowBackground(Color.white.opacity(0.05))
        } footer: {
            Text("Matching this device aligns the locale with your real region — the lowest-suspicion option when it agrees with your IP.")
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section {
            previewRow("navigator.language", vm.previewLanguage)
            previewRow("navigator.languages", vm.previewLanguages)
            previewRow("Intl timeZone", vm.previewTimezone)
            previewRow("Accept-Language", vm.previewAcceptLanguage)
        } header: {
            Text("What sites see")
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    // MARK: - Building blocks

    private func row(label: String, value: String, mono: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(mono)
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func previewRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(accent.opacity(0.9))
                .textSelection(.enabled)
        }
    }
}
