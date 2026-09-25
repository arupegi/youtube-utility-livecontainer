import Foundation
import WebKit

@MainActor
final class BrowserModel: ObservableObject {
    @Published var address = "https://m.youtube.com/"
    @Published var currentURL = "https://m.youtube.com/"
    @Published var title = ""
    @Published var traffic = TrafficSnapshot()
    weak var webView: WKWebView?

    func navigate() {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return }
        if !s.contains("://") {
            if s.contains(".") && !s.contains(" ") { s = "https://" + s }
            else {
                let q=s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
                s="https://m.youtube.com/results?search_query=\(q)"
            }
        }
        guard let u=URL(string:s) else { return }
        currentURL=u.absoluteString
        webView?.load(URLRequest(url:u))
    }
    func reload(){ webView?.reload() }
    func goBack(){ if webView?.canGoBack == true { webView?.goBack() } }
    func goForward(){ if webView?.canGoForward == true { webView?.goForward() } }
    func resetTraffic(){ traffic = TrafficSnapshot() }
}

struct TrafficSnapshot: Codable {
    var totalBytes:Int64=0
    var audioBytes:Int64=0
    var videoBytes:Int64=0
    var imageBytes:Int64=0
    var otherBytes:Int64=0
    var sampledResources:Int=0
    var updatedAt=Date()
}
