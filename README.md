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
