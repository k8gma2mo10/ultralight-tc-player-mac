# macOS版 UltraLight TC Player 開発依頼書

## 目的

Windows版として作成した軽量動画プレーヤーを参考に、macOS版の **UltraLight TC Player** を作成したいです。

このアプリは一般配布や多機能プレーヤーを目的としたものではなく、個人利用向けの **軽量な動画確認・IN / OUT取得ツール** です。

主目的は、動画を見ながらIN / OUT位置の `hh:mm:ss:ff` を取得し、ffmpegで切り出すためのコマンドをコピーすることです。

## 前提

- 対象OSはmacOSです。
- Intel版macOSは非対応で構いません。
- Apple Silicon版macOSを対象とし、古いバージョン互換は無理に追わなくて構いません。
- 開発環境は macOS 26.3.1（25D2128）です。
- 個人利用目的です。
- App Store配布は考えていません。
- 有料ライブラリは使わない方針です。
- 主な再生動画はH.264のmp4です。
- 可能であれば `.mov` も開けると理想です。
- H.265 / HEVC再生はマストではありません。
- UIの完成度より、まずは軽く動いて実用できることを優先します。

## Windows版で実装済みの機能

Windows版では、C# + WPFで以下を実装済みです。

- 動画ファイルを開く
- ドラッグ＆ドロップで動画を開く
- 動画を自動再生する
- `Space` で再生 / 一時停止
- `Right Arrow` で目安の1フレーム送り
- `Left Arrow` で目安の1フレーム戻し
- 現在位置を `hh:mm:ss:ff` で常時表示
- FPSを取得し、タイムコード計算に反映
- FPS取得に失敗した場合は30fps扱い
- `I` で現在位置をINに設定
- `O` で現在位置をOUTに設定
- `Esc` で選択中のINまたはOUTをクリア
- `Delete` でIN / OUTを両方クリア
- `Clear In` / `Clear Out` / `Clear All` ボタン
- シークバー
- 音量スライダー
- ミュートボタン
- IN / OUTが揃った時だけffmpegコマンドを生成
- ffmpegコマンドをコピー
- 出力ファイル名は `source-cut.ext`

## macOS版で目指したいMVP

macOS版でも、まずは以下をMVPとしてください。

- macOSでアプリが起動する
- H.264のmp4動画を開ける
- 可能であれば `.mov` 動画も開ける
- ドラッグ＆ドロップで動画を開ける
- `⌘ + O` で動画を開ける
- 動画を再生できる
- 動画を開いた直後に自動再生される
- `Space` で再生 / 一時停止できる
- `Right Arrow` で目安の1フレーム送りができる
- `Left Arrow` で目安の1フレーム戻しができる
- 現在位置を `hh:mm:ss:ff` で常時表示できる
- FPSを自動取得し、タイムコード計算とフレーム移動に反映できる
- `I` でINを設定できる
- `O` でOUTを設定できる
- `Esc` で選択中のINまたはOUTをクリアできる
- `Delete` でIN / OUTを両方クリアできる
- `fn + Delete` でもIN / OUTを両方クリアできる
- `Clear In` / `Clear Out` / `Clear All` ボタンがある
- シークバーがある
- 音量スライダーがある
- ミュートボタンがある
- IN / OUTが揃った時だけffmpegコマンドを生成できる
- ffmpegコマンドをコピーできる
- 出力ファイル名を再生中のソースファイル名から `source-cut.ext` として動的に生成できる

## 推奨技術

macOS版では、Windows版の制約は引き継がなくて構いません。

以下を優先候補として検討してください。

- Swift
- SwiftUI
- AVFoundation
- AVKit

UI実装の都合で必要であれば、AppKitを部分的に使っても構いません。

ただし、初期版では過剰なアーキテクチャや複雑な設定画面は避けてください。
見た目や操作感はWindows版の完全追従ではなく、macOSらしい自然さを優先してください。

## 避けたい実装

- Electron
- WebView中心の動画プレーヤー
- 重い常駐型アプリ
- プレイリスト機能
- メディアライブラリ
- 動画変換機能
- 字幕編集
- 波形表示
- カラー調整
- 複数動画比較
- クラウド同期
- ネットワーク再生
- アプリ内でのffmpeg実行

## タイムコード仕様

- 表示形式は `hh:mm:ss:ff`
- FPSは動画ファイルから取得してください
- FPS表示は `29.97` のような実値表示にしてください
- 想定FPS:
  - 23.976
  - 24
  - 25
  - 29.97
  - 30
  - 59.94
  - 60
- 29.97 / 59.94 fpsのドロップフレーム表記は初期版では不要です
- VFR動画は初期版では厳密対応不要です
- タイムコードは放送用途の厳密なTCではなく、プレイヤー位置とFPSから算出する確認用表示で構いません

計算方針:

```text
totalFrames = round(currentSeconds * fps)
frameBase = round(fps)

hour = totalFrames / (frameBase * 60 * 60)
minute = (totalFrames % (frameBase * 60 * 60)) / (frameBase * 60)
second = (totalFrames % (frameBase * 60)) / frameBase
frame = totalFrames % frameBase
```

## フレーム送り / 戻し仕様

- 厳密なデコードフレーム単位でなくて構いません
- `1 / fps` 秒ぶんシークする目安操作で構いません
- `Right Arrow`: 現在位置 + `1 / fps`
- `Left Arrow`: 現在位置 - `1 / fps`
- フレーム送り / 戻し時は一時停止して構いません
- ただし、画面表示はコマ送りのように更新されることを重視します

## IN / OUT仕様

- `I`: 現在位置をINに設定
- `O`: 現在位置をOUTに設定
- `I` または `O` で設定した側を選択中として扱う
- `Esc`: 選択中のINまたはOUTだけをクリア
- `Delete`: IN / OUTを両方クリア
- `fn + Delete`: IN / OUTを両方クリア
- `Clear In`: INだけクリア
- `Clear Out`: OUTだけクリア
- `Clear All`: IN / OUTを両方クリア
- 新しい動画を開いた時は、前のIN / OUT、音量などの状態を毎回クリアしてください
- INとOUTが両方設定されていても、`IN >= OUT` の場合は無効な区間として扱ってください

## ffmpegコマンド仕様

アプリ内でffmpegを実行する必要はありません。

IN / OUTが揃った時だけ、以下のようなコマンドを生成してコピーできるようにしてください。

```bash
ffmpeg -ss 00:00:10.000 -to 00:00:25.000 -i "/Users/me/Videos/sample.mp4" -c copy "/Users/me/Videos/sample-cut.mp4"
```

仕様:

- 入力ファイルは現在再生中のソースファイルのフルパスを使う
- 出力ファイルは同じフォルダに作る
- 出力ファイル名は `source-cut.ext`
- 例:
  - `sample.mp4` -> `sample-cut.mp4`
  - `sample.mov` -> `sample-cut.mov`
- ffmpeg用の時間は `hh:mm:ss.fff`
- 画面表示用の時間は `hh:mm:ss:ff`
- IN / OUTが両方設定され、かつ `IN < OUT` の時だけCopyできるようにする
- 初期版では、ファイル名のシェル特殊文字に対する厳密なエスケープは不要です
- `-c copy` は高速・無劣化だが、キーフレーム位置の都合で切り出し位置が表示位置と少しずれる可能性がある
- この制限はREADMEに明記する

## UI方針

- 映像表示領域を主役にする
- コントロールは最小限にする
- タイムコードは視認性を優先する
- タイムコードには等幅数字または等幅フォントを使う
- UIはmacOS標準アプリらしく自然で軽い見た目にする
- ツールバーに「開く」があると自然だが、MVPでは必須ではありません
- QuickTime Playerの完全模倣は不要
- ただし、「体験の軽さ」は重視する

表示したい情報:

- 現在タイムコード
- FPS
- INタイムコード
- OUTタイムコード
- ffmpegコマンド欄
- Copyボタン

## READMEに書いてほしいこと

- ビルド手順
- 実行手順
- 操作方法
- `⌘ + O`、`Space`、矢印キー、`I`、`O`、`Esc`、`Delete`、`fn + Delete` の操作説明
- ffmpegコマンド生成仕様
- 既知の制限事項
- 今後の改善候補

## 既知の制限として扱ってよいこと

- タイムコードは確認用表示であり、放送用途の厳密TCではない
- ドロップフレーム表記には未対応
- VFR動画では誤差が出る可能性がある
- フレーム送り / 戻しは `1 / fps` 秒シークの目安操作
- ファイル名のシェル特殊文字に対する厳密なエスケープは未対応
- `-c copy` 切り出しはキーフレーム位置の影響で切り出し位置がずれる可能性がある

## 作業の進め方

1. macOS向けのプロジェクト構成を確認する
2. SwiftUI + AVFoundation / AVKitでMVPを組めるか判断する
3. 必要ならAppKit併用を検討する
4. まず動画を開いて再生できる状態を作る
5. タイムコード表示を追加する
6. キーボード操作を追加する
7. IN / OUT取得を追加する
8. ffmpegコマンド生成とコピーを追加する
9. READMEに実行方法と制限事項を整理する

## 判断基準

優先順位は以下です。

1. 軽量性
2. H.264 mp4再生の安定性
3. IN / OUT取得とffmpegコマンド生成の実用性
4. タイムコード表示の視認性
5. フレーム送り / 戻しの操作感
6. UIの美しさ

## 実装反映済み内容（2026-06-12）

この依頼書をもとに、現時点では以下の内容まで実装済みです。
今後仕様を更新する場合は、この節を最新状態に合わせて更新してください。

### プロジェクト構成

- XcodeGenベースでプロジェクトを管理する
- `project.yml` を正本とし、`xcodegen generate` で `UltraLightTCPlayer.xcodeproj` を生成する
- 実装技術は `Swift 6`、`SwiftUI`、`AVFoundation`、`AVKit` を採用する
- 対応アーキテクチャは `arm64` のみとする
- deployment target は `macOS 26.0` とする
- アプリのバージョンは `1.0.0`、ビルド番号は `1` とする
- Bundle IDは `io.github.k8gma2mo10.ultralight-tc-player-mac` とする
- コピーライト表記は `Copyright 2026 k8gma2mo10` とする

### 実装済み機能

- `.mp4` を主対象として動画を開ける
- `.mov` もAVFoundationで自然に開ける範囲で対応する
- ツールバーの `動画を開く` ボタンから動画を開ける
- メニューバーの `開く...` と `⌘ + O` から動画を開ける
- ドラッグ＆ドロップで動画を開ける
- 動画を開いた直後に自動再生する
- `Space` で再生 / 一時停止できる
- Play / Pause ボタンは文言が切り替わってもレイアウトが動かない固定幅とする
- `Right Arrow` で `1 / fps` 秒ぶんの目安フレーム送りができる
- `Left Arrow` で `1 / fps` 秒ぶんの目安フレーム戻しができる
- フレーム送り / 戻しはキーボード操作を維持し、専用の `Frame -1` / `Frame +1` ボタンは表示しない
- `I` でINを設定できる
- `O` でOUTを設定できる
- `Esc` で選択中のINまたはOUTだけをクリアできる
- `Delete` と `fn + Delete` の両方でIN / OUTをまとめてクリアできる
- `Clear In`、`Clear Out`、`Clear All` ボタンが使える
- シークバーで再生位置を移動できる
- 音量スライダーとミュートボタンが使える
- IN / OUT が両方設定され、かつ `IN < OUT` の時だけ ffmpeg コマンドを生成できる
- `Copy` ボタンで ffmpeg コマンドをクリップボードへコピーできる
- 新しい動画を開いた時は、前のIN / OUT、選択状態、音量、ミュート状態、コピー表示を毎回リセットする

### タイムコードとFPSの現在仕様

- 表示用タイムコードは `hh:mm:ss:ff`
- 上段の `Time Code` カードは `現在位置 / フル尺` の形式で表示する
- INとOUTはそれぞれ独立したカードでタイムコードを表示する
- ffmpegコマンド用タイムスタンプは `hh:mm:ss.fff`
- FPSは動画ファイルから取得する
- FPS表示は `29.97` のような実値表示にする
- FPSは上段カードには置かず、動画ファイル名の下に `FPS: 29.97` の形式で表示する
- 動画未ロード時のFPS表示は `--` とする
- 動画ロード後にFPS取得が失敗した場合は `30fps` 扱いにフォールバックする
- タイムコード表示は `currentSeconds * fps` をもとに算出する確認用表示とする
- ドロップフレーム表記とVFRの厳密対応は初期版では行わない

### UIの最終方針

- ツールバーは `.windowToolbarStyle(.unifiedCompact(showsTitle: false))` を使い、タイトルバーの表示をコンパクトにする
- ツールバーの主ボタン文言は `動画を開く` とする
- 空状態では中央の補助ボタンを置かず、アプリ名と `Command+O` / ドラッグ＆ドロップの案内だけを表示する
- 上段の読み取り欄は `Time Code`、`IN`、`OUT` の3カード構成とする
- `Time Code` カードには現在位置とフル尺を併記し、IN / OUTカードの表示幅を確保する
- FPSは動画ファイル名の下へ配置する
- Play / Pause ボタンはラベルが切り替わっても幅が変わらないよう固定幅にする
- 画面上の `Frame -1` / `Frame +1` ボタンは削除し、左右矢印キーによる操作だけを残す
- 主要な操作ボタンはアクセントブルー系で統一する
- ミュートボタンは音量スライダー左に配置する
- ミュート解除時アイコンは `speaker.wave.2.fill`、ミュート時アイコンは `speaker.slash.fill` を使う
- アプリアイコンにはルートの `UltraLight-TC-Player-icon.png` を使用する
- 元画像からmacOS用の各サイズを生成し、`Assets.xcassets/AppIcon.appiconset` で管理する

### 実装上の補足

- 動画再生は `AVPlayer` を使用する
- 動画メタデータ取得には `AVFoundation` の async API を使う
- `duration` は `asset.load(.duration)` で取得する
- 動画トラックは `asset.loadTracks(withMediaType: .video)` で取得する
- FPSは `track.load(.nominalFrameRate)` で取得する
- キーボード操作は AppKit のローカルイベント監視で補完する
- ffmpeg はアプリ内で実行せず、コマンド文字列の生成とコピーだけを行う

### ビルド確認済み手順

- `xcodegen generate`
- `xcodebuild -project UltraLightTCPlayer.xcodeproj -scheme UltraLightTCPlayer -configuration Debug -derivedDataPath ./.DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`
- Debugビルド生成物は `./.DerivedData/Build/Products/Debug/UltraLightTCPlayer.app`

### 現在の既知の制限

- タイムコードは確認用表示であり、放送用途の厳密TCではない
- `29.97` / `59.94` fps のドロップフレーム表記には未対応
- VFR動画では表示やフレーム移動に誤差が出る可能性がある
- フレーム送り / 戻しは `1 / fps` 秒シークの目安操作である
- ファイル名のシェル特殊文字に対する厳密なエスケープは未対応
- `-c copy` の切り出しはキーフレーム位置の影響で表示位置と少しずれる可能性がある

### 公開・配布方針

- GitHubアカウント `k8gma2mo10` のPublicリポジトリで公開する
- リポジトリ名は `ultralight-tc-player-mac` とする
- ソースコードとReleaseバイナリの両方を公開する
- ライセンスは Apache License 2.0 とする
- 初回リリースタグは `v1.0.0` とする
- Developer ID署名とApple公証は利用しない
- Releaseアプリには無料のad-hoc署名を付ける
- 配布物は `UltraLightTCPlayer-mac-arm64-v1.0.0.zip` とする
- SHA-256ファイル `UltraLightTCPlayer-mac-arm64-v1.0.0.zip.sha256` をZIPと一緒にGitHub Releaseへ添付する
- READMEに未署名・未公証であることと、macOSの `プライバシーとセキュリティ > このまま開く` を使う初回起動手順を記載する
- 公開リポジトリには `sample.mp4` を含めない
- `UltraLight-TC-Player-icon.png` は作者本人が作成した素材として公開対象に含める
- `project.yml` を正本とし、生成物の `.xcodeproj` はGit管理対象に含めない
- `.DerivedData`、`.DS_Store`、Xcodeユーザー設定、配布生成物もGit管理対象に含めない
- GitHubからダウンロードした配布物は、可能であれば別のApple Silicon MacでGatekeeperを含めて確認する
