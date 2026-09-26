import Foundation
import WebKit

@MainActor
final class BrowserModel: ObservableObject {
    @Published var address = "https://m.youtube.com/"
    @Published var currentURL = "https://m.youtube.com/"
    @Published var title = "YouTube"
    @Published var isLoading = false
    @Published var isPlaying = false
    @Published var isMiniPlayer = false
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


    func setMiniPlayer(_ enabled: Bool) {
        isMiniPlayer = enabled
        let value = enabled ? "true" : "false"
        webView?.evaluateJavaScript("""
        (() => {
          if (window.__ytuSetMiniPlayer) {
            return window.__ytuSetMiniPlayer(\(value));
          }
          return false;
        })()
        """)
    }

    func toggleMiniPlayer() {
        setMiniPlayer(!isMiniPlayer)
    }



    func requestPictureInPicture() {
        webView?.evaluateJavaScript("""
        (() => {
          const v = document.querySelector('video');
          if (!v || v.paused || v.ended) return false;

          try {
            if (typeof v.webkitSetPresentationMode === 'function') {
              v.webkitSetPresentationMode('picture-in-picture');
              return true;
            }
          } catch {}

          try {
            if (document.pictureInPictureElement) return true;
            if (typeof v.requestPictureInPicture === 'function') {
              v.requestPictureInPicture().catch(() => {});
              return true;
            }
          } catch {}

          return false;
        })()
        """)
    }

    func recoverAfterForeground() {
        AudioSessionManager.shared.reactivate()

        guard let webView else { return }

        webView.evaluateJavaScript("""
        (() => {
          const body = document.body;
          const app = document.querySelector('ytd-app');
          const player = document.querySelector('video');
          const text = (body?.innerText || '').trim();
          return {
            ready: document.readyState,
            hasBody: !!body,
            hasApp: !!app,
            hasPlayer: !!player,
            bodyTextLength: text.length
          };
        })()
        """) { result, _ in
            Task { @MainActor in
                let d = result as? [String: Any]
                let hasBody = d?["hasBody"] as? Bool ?? false
                let hasApp = d?["hasApp"] as? Bool ?? false
                let textLength = d?["bodyTextLength"] as? Int ?? 0

                // Do not blindly reload after every foreground transition.
                // Reload only when WebKit genuinely resumed into an empty page.
                if !hasBody || (!hasApp && textLength == 0) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        webView.reload()
                    }
                } else {
                    self.resumeAfterForeground()
                }
            }
        }
    }

    func refreshPlaybackState() {
        webView?.evaluateJavaScript("""
        (() => {
          const v = document.querySelector('video');
          return !!(v && !v.paused && !v.ended);
        })()
        """) { result, _ in
            let playing = (result as? Bool) ?? false
            Task { @MainActor in
                // Positive state can be reflected immediately.
                // Negative state is handled more conservatively by the
                // WebView playerState debounce to avoid UI flicker.
                if playing {
                    self.isPlaying = true
                }
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
