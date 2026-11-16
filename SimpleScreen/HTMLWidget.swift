import SwiftUI
import WebKit

struct HTMLWidget: NSViewRepresentable {
    let html: String
    let networkAllowed: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        let key = "\(networkAllowed):\(html)"
        guard context.coordinator.loaded != key else { return }
        context.coordinator.loaded = key
        let network = networkAllowed ? "https:" : ""
        // The policy precedes author markup: additional meta policies can only restrict it.
        let policy = "default-src 'none'; script-src 'unsafe-inline' \(network); style-src 'unsafe-inline' \(network); img-src data: \(network); font-src data: \(network); connect-src \(network.isEmpty ? "'none'" : network); media-src data: \(network); frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'"
        view.loadHTMLString("<!doctype html><html><head><meta http-equiv=\"Content-Security-Policy\" content=\"\(policy)\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head><body>\(html)</body></html>", baseURL: nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded = ""
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            if navigationAction.navigationType == .other && url?.absoluteString == "about:blank" { decisionHandler(.allow) }
            else { decisionHandler(.cancel) }
        }
    }
}
