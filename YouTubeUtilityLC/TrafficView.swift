import SwiftUI

struct TrafficView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var browser: BrowserModel
    @State private var csvURL: URL?

    var body: some View {
        NavigationStack {
            List {
                row("合計", browser.traffic.totalBytes)
                row("音声", browser.traffic.audioBytes)
                row("映像", browser.traffic.videoBytes)
                row("画像", browser.traffic.imageBytes)
                row("その他", browser.traffic.otherBytes)
                Section {
                    Button("CSVを作成") { csvURL=exportCSV() }
                    if let csvURL { ShareLink(item:csvURL) { Label("CSVを共有 / 保存", systemImage:"square.and.arrow.up") } }
                    Button("計測をリセット", role:.destructive) { browser.resetTraffic() }
                }
            }
            .navigationTitle("通信量（概算）")
            .toolbar { ToolbarItem(placement:.topBarTrailing){ Button("閉じる"){ dismiss() } } }
        }
    }
    @ViewBuilder private func row(_ name:String,_ n:Int64)->some View {
        HStack { Text(name); Spacer(); Text(ByteCountFormatter.string(fromByteCount:n,countStyle:.file)).monospacedDigit() }
    }
    private func exportCSV()->URL? {
        let t=browser.traffic
        func e(_ s:String)->String { "\"" + s.replacingOccurrences(of:"\"", with:"\"\"") + "\"" }
        let rows=[
            ["datetime","title","url","total_bytes","audio_bytes","video_bytes","image_bytes","other_bytes","sampled_resources"],
            [ISO8601DateFormatter().string(from:t.updatedAt),browser.title,browser.currentURL,String(t.totalBytes),String(t.audioBytes),String(t.videoBytes),String(t.imageBytes),String(t.otherBytes),String(t.sampledResources)]
        ]
        let csv="\u{FEFF}"+rows.map{$0.map(e).joined(separator:",")}.joined(separator:"\r\n")
        let u=FileManager.default.temporaryDirectory.appendingPathComponent("youtube-utility-livecontainer-traffic.csv")
        try? csv.data(using:.utf8)?.write(to:u); return u
    }
}
