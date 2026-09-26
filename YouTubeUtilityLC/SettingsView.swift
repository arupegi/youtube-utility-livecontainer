import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var browser: BrowserModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {


                    card("表示テーマ", icon: "circle.lefthalf.filled") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("画面の明るさ")
                                .font(.body.weight(.medium))

                            Picker("表示テーマ", selection: $settings.appearanceMode) {
                                Text("自動").tag("system")
                                Text("ライト").tag("light")
                                Text("ダーク").tag("dark")
                            }
                            .pickerStyle(.segmented)

                            Text("iPadOSに合わせるか、ライト / ダークを固定できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Divider()

                            settingToggle(
                                "YouTube画面にも反映",
                                detail: "YouTubeサイト側の背景・検索欄・一覧・チャンネル画面も同じテーマにする",
                                isOn: $settings.syncYouTubeTheme
                            )
                        }
                    }

                    card("テーマカラー", icon: "paintpalette.fill") {
                        ColorPicker(
                            "カラーを選択",
                            selection: settings.themeColorBinding,
                            supportsOpacity: false
                        )
                        .font(.body.weight(.medium))

                        HStack(spacing: 10) {
                            ForEach([
                                "#FF3B30",
                                "#FF9500",
                                "#FFD60A",
                                "#34C759",
                                "#00C7BE",
                                "#007AFF",
                                "#5856D6",
                                "#AF52DE",
                                "#FF2D55"
                            ], id: \.self) { hex in
                                Button {
                                    settings.themeColorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            if settings.themeColorHex.uppercased() == hex {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack {
                            Text(settings.themeColorHex.uppercased())
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("標準に戻す") {
                                settings.themeColorHex = "#FF3B30"
                            }
                            .font(.caption)
                        }
                    }




                    card("プレイヤー機能", icon: "rectangle.on.rectangle") {
                        settingToggle(
                            "PiPを許可",
                            detail: "YouTubeのピクチャ・イン・ピクチャを使用できるようにする",
                            isOn: $settings.allowPiP
                        )

                        Divider()

                        settingToggle(
                            "全画面表示を許可",
                            detail: "YouTubeプレイヤーの全画面表示を使用できるようにする",
                            isOn: $settings.allowFullscreen
                        )

                        Text("OFFにすると、対応するYouTubeプレイヤーの操作ボタンも非表示になります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    card("ミニプレイヤー", icon: "pip") {
                        HStack(spacing: 12) {
                            Image(systemName: browser.isMiniPlayer ? "pip.exit" : "pip.enter")
                                .font(.title2)
                                .foregroundStyle(settings.themeColor)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(browser.isMiniPlayer ? "ミニプレイヤー使用中" : "ミニプレイヤー")
                                    .font(.body.weight(.medium))
                                Text("動画を右下に残したまま検索やチャンネル一覧を操作できます。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(browser.isMiniPlayer ? "戻す" : "開始") {
                                if !browser.isMiniPlayer {
                                    settings.audioOnly = false
                                }
                                browser.toggleMiniPlayer()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    card("一覧表示", icon: "text.justify") {
                        settingToggle(
                            "テキスト一覧モード",
                            detail: "検索結果やチャンネルページの動画一覧を、画像なしの見やすい縦リストにする",
                            isOn: $settings.textListMode
                        )
                        Divider()
                        settingToggle(
                            "画像を完全に隠す",
                            detail: "サムネイルやその他の画像を表示しない",
                            isOn: $settings.hideThumbnails
                        )
                        Divider()
                        settingToggle(
                            "画像通信をブロック",
                            detail: "ytimg.comなどへの画像取得を抑えて通信量を減らす",
                            isOn: $settings.blockImages
                        )
                        Divider()
                        settingToggle(
                            "Mix / ミックスリストを隠す",
                            detail: "自動生成Mixやミックス再生リストを一覧から除外",
                            isOn: $settings.hideMixes
                        )
                        Divider()
                        settingToggle(
                            "Shortsを隠す",
                            detail: "Shorts棚・Shortsカード・Shortsタブを非表示",
                            isOn: $settings.hideShorts
                        )
                    }

                    card("再生", icon: "play.circle.fill") {
                        settingToggle(
                            "音声のみ",
                            detail: "映像通信をブロックして音声中心で再生",
                            isOn: $settings.audioOnly
                        )
                        Divider()
                        settingToggle(
                            "広告ブロック",
                            detail: "広告系リクエストを遮断",
                            isOn: $settings.adBlock
                        )
                        Divider()
                        settingToggle(
                            "シーク画像をブロック",
                            detail: "シーク時のプレビュー画像を取得しない",
                            isOn: $settings.blockSeekPreview
                        )
                    }

                    card("表示を軽くする", icon: "rectangle.compress.vertical") {
                        settingToggle("コメントを隠す", detail: nil, isOn: $settings.hideComments)
                        Divider()
                        settingToggle("ライブチャットを隠す", detail: nil, isOn: $settings.hideChat)
                        Divider()
                        settingToggle("関連動画を隠す", detail: nil, isOn: $settings.hideRelated)
                        Divider()
                        settingToggle("サムネイルを隠す", detail: nil, isOn: $settings.hideThumbnails)
                    }

                    card("ダウンロードAPI", icon: "arrow.down.circle.fill") {
                        TextField("https://example.com/api", text: $settings.downloadEndpoint)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                            .padding(11)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))

                        Button {
                            openDownload()
                        } label: {
                            Label("現在のページをAPIへ送る", systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(settings.downloadEndpoint.isEmpty)

                        Text("自分のコンテンツ、または保存が許可されているメディア向けです。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Label("設定を適用", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func card<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)

            content()
        }
        .padding(15)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func settingToggle(
        _ title: String,
        detail: String?,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(settings.themeColor)
    }

    private func openDownload() {
        guard !settings.downloadEndpoint.isEmpty,
              var c = URLComponents(string: settings.downloadEndpoint) else { return }

        var q = c.queryItems ?? []
        q.append(URLQueryItem(name: "url", value: browser.currentURL))
        c.queryItems = q

        if let u = c.url {
            UIApplication.shared.open(u)
        }
    }
}
