import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    enum Content: Equatable {
        case url(URL)
        case html(String)
    }

    let content: Content

    init(url: URL) { content = .url(url) }
    init(html: String) { content = .html(html) }

    final class Coordinator {
        var loaded: Content?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.loaded != content {
            load(into: nsView, coordinator: context.coordinator)
        }
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        coordinator.loaded = content
        switch content {
        case .url(let url): webView.load(URLRequest(url: url))
        case .html(let html): webView.loadHTMLString(html, baseURL: nil)
        }
    }
}
