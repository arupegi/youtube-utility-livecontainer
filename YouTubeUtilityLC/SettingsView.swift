import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var browser: BrowserModel

    var body: some View {
        NavigationStack {
            Form {
                Section("ブロック") {
                    Toggle("広告ブロック", isOn:$settings.adBlock)
                    Toggle("音声のみ（映像通信ブロック）", isOn:$settings.audioOnly)
                    Toggle("シーク画像をブロック", isOn:$settings.blockSeekPreview)
                }
                Section("表示") {
                    Toggle("コメント非表示", isOn:$settings.hideComments)
                    Toggle("ライブチャット非表示", isOn:$settings.hideChat)
                    Toggle("関連動画非表示", isOn:$settings.hideRelated)
                    Toggle("サムネイル非表示", isOn:$settings.hideThumbnails)
                }
                Section("ダウンロード") {
                    TextField("自前のダウンロードAPI", text:$settings.downloadEndpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("現在のページをAPIへ送る") { openDownload() }
                    Text("自分のコンテンツや保存が許可されたメディア向けです。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("設定を適用して再読み込み") { browser.reload(); dismiss() }
            }
            .navigationTitle("設定").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func openDownload(){
        guard !settings.downloadEndpoint.isEmpty,
              var c=URLComponents(string:settings.downloadEndpoint) else { return }
        var q=c.queryItems ?? []
        q.append(URLQueryItem(name:"url", value:browser.currentURL)); c.queryItems=q
        if let u=c.url { UIApplication.shared.open(u) }
    }
}
