import Foundation

@MainActor
@Observable
final class ImportExportViewModel {
    enum Mode: String, CaseIterable {
        case importMode = "Import"
        case exportMode = "Export"
    }

    var mode: Mode = .importMode
    var rawText: String = "" {
        didSet { detectedFormat = CookieParser.detectFormat(rawText) }
    }
    var detectedFormat: CookieImportFormat = .unknown
    var exportFormat: CookieExportFormat = .json
    var showAnalyzer: Bool = false
    var exportOutput: String = ""
    var showCopied: Bool = false

    var trimmedImportText: String {
        rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canAnalyzeImport: Bool {
        !trimmedImportText.isEmpty
    }

    func pasteFromClipboard() {
        rawText = ClipboardService.readString() ?? rawText
    }

    func refreshExport(profile: BrowsingProfile, store: ProfileStore) async {
        guard mode == .exportMode else { return }
        exportOutput = await store.exportCookies(for: profile, format: exportFormat)
    }

    func copyExportOutput() async {
        ClipboardService.writeString(exportOutput)
        showCopied = true
        try? await Task.sleep(for: .seconds(1.5))
        showCopied = false
    }
}

@MainActor
@Observable
final class CookieImportAnalyzerViewModel {
    var result: CookieParseResult?
    var isImporting: Bool = false
    var importedCount: Int?

    func analyze(_ rawText: String) {
        result = CookieParser.parse(rawText)
    }

    func importCookies(profile: BrowsingProfile, store: ProfileStore) async -> Bool {
        guard let result else { return false }
        isImporting = true
        let importedResult = await store.importCookies(result.cookies, into: profile)
        importedCount = importedResult.imported
        isImporting = false
        try? await Task.sleep(for: .seconds(0.8))
        return true
    }
}
