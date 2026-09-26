# YouTube Utility LC v0.1

LiveContainer向けの単体iOSアプリです。Safari Web Extensionではありません。

## 機能
- 広告系通信のContent Blocker
- 音声のみ（video用googlevideo通信をブロック）
- PiP無効化
- シークプレビュー画像ブロック
- コメント/ライブチャット/関連動画/サムネイル非表示
- 通信量の概算表示
- CSVエクスポート
- 自前ダウンロードAPIへの送信UI

## Codemagic
GitHubへpushし、`YouTube Utility LC - Unsigned IPA` workflowを実行してください。
生成物は `YouTubeUtilityLC-unsigned.ipa` です。

## LiveContainer
LiveContainer右上の `+` からIPAを選択して追加します。JIT-Less利用時はAltStore/SideStore証明書をLiveContainerへインポートしてください。

## 注意
LiveContainerではApp Extensionsが使えないため、この版はWKWebView内で機能を完結させています。通信量はWebKitが公開するResource Timingからの概算で、キャリア計測と完全一致しません。ダウンロード機能はDRM回避を含まず、自分のコンテンツや保存許可のあるメディア向けのAPI接続口です。


## v0.2 修正
Codemagic/Xcode 26.6でのSwiftコンパイルエラーを修正しました。

このアプリは `NavigationStack` / `ShareLink` / `Transferable` を使用するため、
最低対応OSを iOS 15.0 から **iOS 16.0** に変更しています。

`project.yml`:
- `IPHONEOS_DEPLOYMENT_TARGET: 16.0`
- `deploymentTarget: "16.0"`


## v0.3 UI / Background Audio

### UI
- iPad向けにURLバーを再設計
- 戻る / 進む / 再読み込みをコンパクト化
- 現在の再生モードと再生状態を表示
- 画面下に音声モード / 通信量 / 設定の固定バーを追加
- 設定画面をカード型UIに変更
- 通信量画面をダッシュボード型に変更

### バックグラウンド再生
- `AVAudioSession.Category.playback` をアプリ起動時から有効化
- `UIBackgroundModes` に `audio` を追加
- バックグラウンドへ移る直前に再生状態を保存
- 再生中だった場合のみWebViewへ再生継続を指示
- フォアグラウンド復帰時も必要なら自動再開

LiveContainer側のホスト設定やiPadOSの制御によっては、
OS側がWebViewを停止するケースを完全には排除できません。


## v0.4 自由なテーマカラー

設定画面に「テーマカラー」を追加しました。

- iPadOS標準のColorPickerで自由に色を選択
- 9色のプリセット
- HEX値を保存
- アプリ再起動後も保持
- 音声のみ表示
- ボタン
- Toggle
- ステータス
- 通信量画面のアイコン
などへテーマカラーを反映

標準色は `#FF3B30` です。


## v0.5 テキスト一覧モード

検索結果やチャンネルページで、動画一覧は残しつつ画像を出さない
「テキスト一覧モード」を追加しました。

### できること
- 動画タイトル / チャンネル名 / メタ情報は表示
- サムネイル画像は非表示
- 画像通信もできるだけブロック
- 下バーから一覧モードをすぐ切替
- 検索 / チャンネル巡回をしやすい軽量UI

### 想定表示
- 検索結果: 縦並びのテキストカード
- チャンネルページ: 動画カードをテキスト主体に圧縮


## v0.6 下バー中央寄せ / ダークモード

### 下バー
- 4つの操作ボタンを画面端まで広げず、中央寄せのカプセル型トレイへ変更
- ボタン同士の間隔を詰めて、見た目をすっきり整理
- 片手でも押しやすいようにコンパクト化

### ダークモード
- 設定画面に「表示テーマ」を追加
- `自動 / ライト / ダーク` を切替可能
- `preferredColorScheme` でアプリ全体へ反映


## v0.7 Desktop channel list / Mix / Shorts

### デスクトップ版チャンネルページ
- `ytd-rich-grid-renderer`
- `ytd-rich-grid-row`
- `ytd-rich-grid-media`
- `ytd-rich-item-renderer`

を対象に追加し、チャンネルの「動画」タブでもテキスト一覧モードが効くように強化しました。

### Mix / ミックスリスト
- Mix
- ミックス
- `list=RD`
- `start_radio=1`

を含む自動生成Mixカードを非表示にします。

### Shorts
- Shorts棚
- Shortsカード
- Shortsタブ
- `/shorts/` リンク

を非表示にします。

YouTubeはDOMを動的に再生成するため、2秒ごとに軽量な再チェックも行います。


## v0.8 YouTubeページ ダークモード

アプリ本体の表示テーマだけでなく、WKWebView内のYouTubeサイト側も
同じテーマへ変換できるようにしました。

### 対応箇所
- YouTube全体の背景
- 上部ヘッダー
- 検索欄
- チャンネルページ
- 検索結果
- 動画一覧
- テキスト一覧モードのカード
- フィルター / チップ
- 動画ページ周辺
- 一部メニュー / ダイアログ
- スクロールバー

### テーマ
- 自動: iPadOSのライト / ダークに追従
- ライト: YouTubeもライト表示へ
- ダーク: YouTubeもダーク表示へ

設定の「YouTube画面にも反映」でON/OFFできます。


## v0.9 ミニプレイヤー / YouTubeダークモード修正版

### 修正
v0.8ではWebViewへ渡す設定JSONに `appearanceMode` / `syncYouTubeTheme`
などが含まれていない経路が残っていたため、YouTube側のダークモードが
実際には適用されない場合がありました。v0.9で全設定を正しく送るよう修正しました。

### YouTubeダークモード
- documentStartからダーク属性を付与
- YouTubeのCSSカスタムプロパティを直接上書き
- YouTubeがDOM/テーマを再生成しても定期的に再適用
- `自動 / ライト / ダーク` に対応
- 白い読み込み画面を減らすためWKWebView背景も透明化

### ミニプレイヤー
- 下バーに「ミニ」ボタンを追加
- YouTube標準ミニプレイヤーがある場合は標準機能を優先
- 標準機能がないレイアウトでは右下固定プレイヤーへフォールバック
- 検索結果やチャンネル一覧を見ながら動画を継続表示
- 「戻す」で通常表示へ復帰
- ミニプレイヤー開始時は映像が必要なため音声のみモードを自動解除


## v0.10 PiP / 全画面表示 切替

設定 → プレイヤー機能 から以下を個別に切り替えられます。

- PiPを許可
- 全画面表示を許可

### PiP OFF
- YouTubeのPiPボタンを非表示
- `video.disablePictureInPicture = true`
- PiPボタン操作もブロック

### 全画面 OFF
- YouTubeの全画面ボタンを非表示
- 全画面ボタンのクリックをブロック
- プレイヤー上のダブルクリックによる全画面化もブロック
- 通常のインライン再生は維持

設定はAppStorageで保存されます。


## v0.11 再生状態表示のちらつき修正

YouTubeがストリーム切替やDOM更新時に、一瞬だけ `paused = true`
を返すケースがあるため、右上の再生状態表示にデバウンス処理を追加しました。

- `再生中` は即時反映
- `停止中` は約0.9秒待ってから再確認
- その間に再生へ戻れば `停止中` への切替をキャンセル
- 本当に停止している場合だけ表示を変更

これにより「再生中 → 一瞬停止中 → 再生中」のちらつきを抑えます。


## v0.12 WebView 黒画面修正

v0.9以降のダークテーマ初期化処理で、`document.documentElement` の
`style` 属性を `MutationObserver` で監視しながら同じ `style` を更新していたため、
自己再発火ループになる可能性がありました。

### 修正
- documentStartのMutationObserverを削除
- ダークテーマは読み込み開始時に1回適用
- DOMContentLoaded後にも1回適用
- 通常表示後のテーマ補正は2.5秒間隔へ軽量化
- WKWebViewの読み込み失敗ログを追加
- WebContent processが終了した場合は自動reload

PiP / 全画面 / ミニプレイヤー / テキスト一覧 / Shorts・Mix非表示など
v0.11までの機能は維持しています。


## v0.13 動作安定化

画面録画で確認できた不安定な挙動をまとめて修正しました。

### 1. バックグラウンド復帰後の黒/空白画面
- 復帰時に毎回reloadしない
- DOMが本当に空になっている場合のみ遅延reload
- 正常なページなら再生状態だけ復帰

### 2. PiP
- `scenePhase == .inactive` の段階でPiP移行を試行
- `webkitSetPresentationMode("picture-in-picture")` を優先
- 対応環境では標準Picture-in-Picture APIもフォールバック
- WebKitの `allowsPictureInPictureMediaPlayback` は維持

### 3. 設定変更時のちらつき/再読み込み
- 下バー操作からの明示reloadを削除
- 設定画面の「設定を適用して再読み込み」を「設定を適用」に変更
- Content Rule変更が必要な場合だけ1回だけ制御reload
- Content Ruleの並行compileを防止

### 4. Shorts非表示
- `/shorts/` のdocument自体をContent Ruleでblockする処理を削除
- DOM上で非表示に統一
- Shortsリンク遷移時に空白ページになる可能性を低減

### 5. テーマ表示
- WKWebViewのネイティブ背景色もライト/ダークに同期
- YouTube描画前後の白/黒フラッシュを低減
- 強制テーマ補正の間隔を4秒へ緩和


## v0.14 軽量化 / PiP・全画面修正

### 大幅な軽量化
v0.13までの定期的なDOM全体走査を廃止しました。

- 4秒ごとのDOM全体チェックを削除
- `MutationObserver` は「新しく追加された要素」がある時だけ使用
- DOM処理は180msのスロットリング付き
- 通信量計測を `performance.getEntriesByType()` の繰り返し走査から
  `PerformanceObserver` による差分取得へ変更
- 再生状態もvideo要素のイベントで更新
- テーマ補正はページ遷移 / DOM更新時だけ実施

### PiP
- YouTubeプレイヤーに専用PiPボタンを追加
- Webページ上の実際のクリックとしてPiPを開始
- `webkitSetPresentationMode("picture-in-picture")` を優先
- 標準 `requestPictureInPicture()` もフォールバック
- 下バー「表示」メニューからも開始可能

### 全画面
- YouTubeプレイヤーに専用全画面ボタンを追加
- `requestFullscreen()` を優先
- iOS向け `webkitEnterFullscreen()` をフォールバック
- 下バー「表示」メニューからも開始可能

LiveContainer / iPadOS側がPiPや全画面API自体を制限している場合は、
WebKit側の許可だけでは利用できないケースがあります。その場合でも
プレイヤー上の専用ボタン経由を最優先で試せる構成にしています。


## v0.15 ミニプレイヤー削除 / PiP・全画面ボタン独立化

- 独自ミニプレイヤー機能を削除
- 設定画面のミニプレイヤー項目を削除
- 下バーの「表示」メニューを廃止
- 下バーに `PiP` ボタンを直接表示
- 下バーに `全画面` ボタンを直接表示
- PiP / 全画面が設定でOFFの場合は該当ボタンを無効化

下バー:
`音声のみ / 一覧 / PiP / 全画面 / 通信量 / 設定`

YouTubeプレイヤー内に追加するPiP / 全画面ボタンは維持しています。
