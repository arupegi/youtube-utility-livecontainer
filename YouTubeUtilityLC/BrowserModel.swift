import Foundation
import WebKit

@MainActor
final class BrowserModel: ObservableObject {
    @Published var address = "https://m.youtube.com/"
    @Published var currentURL = "https://m.youtube.com/"
    @Published var title = "YouTube"
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var traffic = TrafficSnapshot()

    weak var webView: WKWebView?

    func navigate() {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }

        if !s.contains("://") {
            if s.contains(".") && !s.contains(" ") {
                s = "https://" + s
            } else {
                let q = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                s = "https://m.youtube.com/results?search_query=\(q)"
            }
        }

        guard let u = URL(string: s) else { return }
        currentURL = u.absoluteString
        webView?.load(URLRequest(url: u))
    }

    func reload() { webView?.reload() }
    func goBack() { if webView?.canGoBack == true { webView?.goBack() } }
    func goForward() { if webView?.canGoForward == true { webView?.goForward() } }
    func resetTraffic() { traffic = TrafficSnapshot() }

    func refreshPlaybackState() {
        webView?.evaluateJavaScript("""
        (() => {
          const v = document.querySelector('video');
          return !!(v && !v.paused && !v.ended);
        })()
        """) { result, _ in
            Task { @MainActor in
                self.isPlaying = (result as? Bool) ?? false
            }
        }
    }

    func prepareForBackground() {
        AudioSessionManager.shared.reactivate()

        webView?.evaluateJavaScript("""
        (() => {
          const v = document.querySelector('video');
          if (!v) return false;
          const playing = !v.paused && !v.ended;
          window.__ytuWasPlayingBeforeBackground = playing;
          if (playing) {
            Promise.resolve().then(() => v.play()).catch(() => {});
            setTimeout(() => v.play().catch(() => {}), 80);
            setTimeout(() => v.play().catch(() => {}), 350);
          }
          return playing;
        })()
        """) { result, _ in
            Task { @MainActor in
                self.isPlaying = (result as? Bool) ?? self.isPlaying
            }
        }
    }

    func resumeAfterForeground() {
        AudioSessionManager.shared.reactivate()

        webView?.evaluateJavaScript("""
        (() => {
          const v = document.querySelector('video');
          if (!v) return false;
          if (window.__ytuWasPlayingBeforeBackground && v.paused) {
            v.play().catch(() => {});
          }
          return !v.paused && !v.ended;
        })()
        """) { result, _ in
            Task { @MainActor in
                self.isPlaying = (result as? Bool) ?? false
            }
        }
    }
}

struct TrafficSnapshot: Codable {
    var totalBytes: Int64 = 0
    var audioBytes: Int64 = 0
    var videoBytes: Int64 = 0
    var imageBytes: Int64 = 0
    var otherBytes: Int64 = 0
    var sampledResources: Int = 0
    var updatedAt = Date()
}
