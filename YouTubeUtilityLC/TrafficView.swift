import SwiftUI

struct TrafficView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var browser: BrowserModel
    @State private var csvURL: URL?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 5) {
                        Text("現在の通信量")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(format(browser.traffic.totalBytes))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text("Safari / WKWebViewから観測できる範囲の概算")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

                    LazyVGrid(columns: columns, spacing: 10) {
                        statCard("音声", icon: "waveform", bytes: browser.traffic.audioBytes)
                        statCard("映像", icon: "film", bytes: browser.traffic.videoBytes)
                        statCard("画像", icon: "photo", bytes: browser.traffic.imageBytes)
                        statCard("その他", icon: "ellipsis.circle", bytes: browser.traffic.otherBytes)
                    }

                    VStack(spacing: 10) {
                        Button {
                            csvURL = exportCSV()
                        } label: {
                            Label("CSVを作成", systemImage: "doc.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if let csvURL {
                            ShareLink(item: csvURL) {
                                Label("CSVを共有 / ファイルに保存", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(role: .destructive) {
                            browser.resetTraffic()
                        } label: {
                            Label("計測をリセット", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(15)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("通信量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func statCard(_ title: String, icon: String, bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(settings.themeColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(format(bytes))
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func exportCSV() -> URL? {
        let t = browser.traffic

        func e(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        let rows = [
            ["datetime","title","url","total_bytes","audio_bytes","video_bytes","image_bytes","other_bytes","sampled_resources"],
            [
                ISO8601DateFormatter().string(from: t.updatedAt),
                browser.title,
                browser.currentURL,
                String(t.totalBytes),
                String(t.audioBytes),
                String(t.videoBytes),
                String(t.imageBytes),
                String(t.otherBytes),
                String(t.sampledResources)
            ]
        ]

        let csv = "\u{FEFF}" + rows
            .map { $0.map(e).joined(separator: ",") }
            .joined(separator: "\r\n")

        let u = FileManager.default.temporaryDirectory
            .appendingPathComponent("youtube-utility-livecontainer-traffic.csv")

        try? csv.data(using: .utf8)?.write(to: u)
        return u
    }
}
