import SwiftUI

struct ImportExportView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: BrowsingProfile
    var store: ProfileStore

    @State private var viewModel = ImportExportViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Picker("", selection: $viewModel.mode) {
                        ForEach(ImportExportViewModel.Mode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if viewModel.mode == .importMode {
                        importPanel
                    } else {
                        exportPanel
                    }

                    Spacer()
                }
                .overlay(alignment: .top) {
                    if viewModel.showCopied {
                        Text("Copied")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(profile.color))
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(viewModel.mode == .importMode ? "Import" : "Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(profile.color)
                }
            }
            .sheet(isPresented: $viewModel.showAnalyzer) {
                CookieImportAnalyzerView(profile: profile, store: store, rawText: viewModel.rawText) {
                    dismiss()
                }
            }
            .task(id: viewModel.mode) {
                await viewModel.refreshExport(profile: profile, store: store)
            }
            .task(id: viewModel.exportFormat) {
                await viewModel.refreshExport(profile: profile, store: store)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste Cookies")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05))
                if viewModel.rawText.isEmpty {
                    Text("Netscape, JSON, cURL, or Cookie header…")
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(14)
                }
                TextEditor(text: $viewModel.rawText)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .foregroundStyle(.white)
                    .font(.system(.caption, design: .monospaced))
            }
            .frame(minHeight: 220)
            .padding(.horizontal, 16)

            HStack {
                Label("Detected: \(viewModel.detectedFormat.label)", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button {
                    viewModel.pasteFromClipboard()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                }
                .tint(.white)
            }
            .padding(.horizontal, 16)

            Button {
                viewModel.showAnalyzer = true
            } label: {
                Text("Analyze & Import")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(profile.color))
                    .foregroundStyle(.black)
            }
            .disabled(!viewModel.canAnalyzeImport)
            .opacity(viewModel.canAnalyzeImport ? 1 : 0.4)
            .padding(.horizontal, 16)
        }
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Format")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)

            Picker("", selection: $viewModel.exportFormat) {
                ForEach(CookieExportFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollView {
                Text(viewModel.exportOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
            .frame(minHeight: 220)
            .padding(.horizontal, 16)

            Button {
                Task {
                    await viewModel.copyExportOutput()
                }
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(profile.color))
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 16)
        }
    }
}

struct CookieImportAnalyzerView: View {
    @Environment(\.dismiss) private var dismiss
    let profile: BrowsingProfile
    var store: ProfileStore
    let rawText: String
    let onComplete: () -> Void

    @State private var viewModel = CookieImportAnalyzerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let result = viewModel.result {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            summaryCard(result: result)
                            warningsCard(result: result)
                            cookiePreviewList(result: result)
                            importButton(result: result)
                        }
                        .padding(20)
                    }
                } else {
                    ProgressView().tint(profile.color)
                }
            }
            .navigationTitle("Analyze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .task {
                viewModel.analyze(rawText)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func summaryCard(result: CookieParseResult) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(result.cookies.count)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Cookies")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Divider().frame(height: 50).overlay(Color.white.opacity(0.1))
            VStack(alignment: .leading, spacing: 4) {
                Text(result.format.label)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(profile.color)
                Text("Format")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
    }

    @ViewBuilder
    private func warningsCard(result: CookieParseResult) -> some View {
        if !result.warnings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("WARNINGS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(result.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#F59E0B"))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#F59E0B").opacity(0.1)))
        }
    }

    private func cookiePreviewList(result: CookieParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(result.cookies) { cookie in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(profile.color).frame(width: 6, height: 6).padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cookie.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(cookie.domain)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                Divider().overlay(Color.white.opacity(0.08))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
    }

    private func importButton(result: CookieParseResult) -> some View {
        Button {
            Task { await performImport() }
        } label: {
            HStack {
                if viewModel.isImporting { ProgressView().tint(.black) }
                Text(viewModel.importedCount == nil
                     ? "Import \(result.cookies.count) Cookies"
                     : "Imported \(viewModel.importedCount ?? 0) ✓")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(profile.color))
            .foregroundStyle(.black)
        }
        .disabled(result.cookies.isEmpty || viewModel.isImporting)
        .opacity(result.cookies.isEmpty ? 0.4 : 1)
    }

    private func performImport() async {
        guard await viewModel.importCookies(profile: profile, store: store) else { return }
        dismiss()
        onComplete()
    }
}
