import SwiftUI
import WebKit
import SwiftData

struct BrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let profile: BrowsingProfile

    @State private var viewModel = BrowserViewModel()
    @State private var store = ProfileStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    addressBar
                    progressBar
                    BrowserWebView(
                        profile: profile,
                        url: viewModel.currentURL,
                        loadTrigger: viewModel.loadTrigger,
                        navAction: $viewModel.navAction,
                        canGoBack: $viewModel.canGoBack,
                        canGoForward: $viewModel.canGoForward,
                        isLoading: $viewModel.isLoading,
                        progress: $viewModel.progress,
                        pageTitle: $viewModel.pageTitle,
                        onNavigate: { url, title in
                            viewModel.didNavigate(to: url, title: title, profile: profile, context: modelContext)
                        }
                    )
                    toolbar
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $viewModel.showCookies) {
                CookieManagerView(profile: profile, store: store, currentHost: viewModel.currentURL?.host)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var addressBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            HStack(spacing: 8) {
                Image(systemName: viewModel.isLoading ? "arrow.triangle.2.circlepath" : "lock.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.5))
                TextField("URL or search", text: $viewModel.addressText)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
                    .onSubmit { viewModel.go() }
                if !viewModel.addressText.isEmpty {
                    Button {
                        viewModel.clearAddress()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(0.08)))

            Button {
                viewModel.showCookies = true
            } label: {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title3)
                    .foregroundStyle(profile.color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black)
    }

    @ViewBuilder
    private var progressBar: some View {
        if viewModel.isLoading {
            GeometryReader { geo in
                Rectangle()
                    .fill(profile.color)
                    .frame(width: geo.size.width * viewModel.progress, height: 2)
                    .animation(.easeOut, value: viewModel.progress)
            }
            .frame(height: 2)
        } else {
            Color.clear.frame(height: 2)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 28) {
            toolbarButton(systemImage: "chevron.left", enabled: viewModel.canGoBack) { viewModel.navAction = .back }
            toolbarButton(systemImage: "chevron.right", enabled: viewModel.canGoForward) { viewModel.navAction = .forward }
            Spacer()
            toolbarButton(systemImage: viewModel.isLoading ? "xmark" : "arrow.clockwise", enabled: true) {
                viewModel.navAction = viewModel.isLoading ? .stop : .reload
            }
            toolbarButton(systemImage: "house.fill", enabled: true) {
                viewModel.goHome()
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(Color.black)
    }

    private func toolbarButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.3))
                .frame(width: 42, height: 42)
        }
        .disabled(!enabled)
    }

}

struct BrowserWebView: UIViewRepresentable {
    let profile: BrowsingProfile
    let url: URL?
    let loadTrigger: Int
    @Binding var navAction: BrowserNavigationAction
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var pageTitle: String
    let onNavigate: (URL, String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        // Every webview is built through ProfileManager — single source of truth
        // for persona identity, user scripts, and cookie policy.
        let dataStore = CookieService.shared.dataStore(for: profile)
        let config = ProfileManager.shared.makeWebViewConfiguration(websiteDataStore: dataStore)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        ProfileManager.shared.apply(to: webView)
        context.coordinator.currentPersona = ProfileManager.shared.activePersona

        context.coordinator.webView = webView
        context.coordinator.observeProgress()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let persona = ProfileManager.shared.activePersona
        if webView.customUserAgent != persona.userAgent {
            webView.customUserAgent = persona.userAgent
        }
        context.coordinator.currentPersona = persona

        switch navAction {
        case .back: webView.goBack()
        case .forward: webView.goForward()
        case .reload: webView.reload()
        case .stop: webView.stopLoading()
        case .none: break
        }
        if navAction != .none {
            DispatchQueue.main.async { navAction = .none }
        }

        if context.coordinator.lastLoadTrigger != loadTrigger, let url = url {
            context.coordinator.lastLoadTrigger = loadTrigger
            let request = BrowserRequestFactory().makeRequest(url: url, profile: profile, persona: persona)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: BrowserWebView
        weak var webView: WKWebView?
        var lastLoadTrigger: Int = -1
        var currentPersona: BrowsingPersona?
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: BrowserWebView) {
            self.parent = parent
        }

        func observeProgress() {
            guard let webView else { return }
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    self?.parent.progress = wv.estimatedProgress
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = true
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                self.parent.pageTitle = webView.title ?? ""
                if let url = webView.url {
                    self.parent.onNavigate(url, webView.title ?? "")
                }
                // Re-inject non-HTTPOnly cookies via JS as safety net.
                let js = self.parent.profile.cachedCookies
                    .filter { !$0.isHTTPOnly && $0.matchesDomain(webView.url?.host ?? "") }
                    .map { $0.toJavaScript }
                    .joined(separator: "\n")
                if !js.isEmpty {
                    webView.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.parent.isLoading = false }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in self.parent.isLoading = false }
        }
    }
}
