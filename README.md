# UltraLight TC Player

UltraLight TC Playerは、動画を確認しながらIN / OUT位置を取得し、切り出し用の`ffmpeg`コマンドをコピーできる軽量なmacOSアプリです。

機能を絞り、軽快に使えることを重視しています。

- Apple Silicon Mac専用
- macOS 26.0以降
- SwiftUI + AVFoundation / AVKit
- H.264の`.mp4`を主対象とする
- AVFoundationで再生可能な`.mov`にも対応
- アプリ内では`ffmpeg`を実行しない
- アプリアイコンは`UltraLight-TC-Player-icon.png`から生成

現在のリリース:

- バージョン: `1.0.0`
- ビルド: `1`
- Bundle ID: `io.github.k8gma2mo10.ultralight-tc-player-mac`

## 動作・開発環境

- macOS 26以降
- Apple Silicon Mac
- Xcode 26.5以降
- `xcodegen` 2.45.4以降

## ビルド

Xcodeプロジェクトを生成します。

```bash
xcodegen generate
```

コマンドラインからDebugビルドを実行します。

```bash
xcodebuild -project UltraLightTCPlayer.xcodeproj -scheme UltraLightTCPlayer -configuration Debug -derivedDataPath ./.DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

または、生成したプロジェクトをXcodeで開きます。

```bash
open UltraLightTCPlayer.xcodeproj
```

## 実行

Debugビルド後のアプリは次の場所に生成されます。

```text
./.DerivedData/Build/Products/Debug/UltraLightTCPlayer.app
```

FinderやXcodeから起動するか、次のコマンドを使用します。

```bash
open ./.DerivedData/Build/Products/Debug/UltraLightTCPlayer.app
```

## GitHub Release版のインストール

GitHub Release版は、Developer ID署名およびApple公証を行わず、無料で配布しています。アプリの整合性を保つためad-hoc署名を付けていますが、macOS Gatekeeperでは確認済みの開発元として認識されません。

1. GitHub Releasesから`UltraLightTCPlayer-mac-arm64-v1.0.0.zip`をダウンロードします。
2. 必要に応じて、同梱の`.sha256`ファイルを使ってZIPのチェックサムを確認します。
3. ZIPを展開し、`UltraLightTCPlayer.app`を`Applications`フォルダへ移動します。
4. アプリを一度開きます。初回はmacOSによって起動がブロックされます。
5. `システム設定 > プライバシーとセキュリティ`を開きます。
6. UltraLight TC Playerに関するメッセージの`このまま開く`を選択します。
7. 確認画面で`開く`を選択します。

組織によって管理されているMacでは、セキュリティ設定の上書きが許可されていない場合があります。また、ローカルでビルドしたアプリではダウンロード時の隔離状態を再現できないため、可能であればGitHubからダウンロードした配布物を別のApple Silicon Macでも確認してください。

ターミナルからチェックサムを確認する場合:

```bash
shasum -a 256 -c UltraLightTCPlayer-mac-arm64-v1.0.0.zip.sha256
```

## Releaseビルド

プロジェクトを生成し、Release構成でビルドします。

```bash
xcodegen generate
xcodebuild -project UltraLightTCPlayer.xcodeproj -scheme UltraLightTCPlayer -configuration Release -derivedDataPath ./.DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

無料のad-hoc署名を適用し、アプリバンドルを検証します。

```bash
codesign --force --sign - --options runtime --timestamp=none ./.DerivedData/Build/Products/Release/UltraLightTCPlayer.app
codesign --verify --deep --strict --verbose=2 ./.DerivedData/Build/Products/Release/UltraLightTCPlayer.app
```

公開リポジトリには、`sample.mp4`、生成された`.xcodeproj`、`.DerivedData`、Release配布物を含めていません。ソースコードからビルドするにはXcodeGenが必要です。

## 操作方法

- `⌘ + O`: 動画を開く
- ドラッグ＆ドロップ: ウインドウへ動画をドロップして開く
- 自動再生: 動画を開いた直後に再生を開始
- `Space`: 再生 / 一時停止
- `Right Arrow`: 約`1 / fps`秒ぶん進む
- `Left Arrow`: 約`1 / fps`秒ぶん戻る
- `I`: 現在位置をINに設定
- `O`: 現在位置をOUTに設定
- `Esc`: 選択中のINまたはOUTだけをクリア
- `Delete`: IN / OUTを両方クリア
- `fn + Delete`: IN / OUTを両方クリア
- `Clear In`: INだけをクリア
- `Clear Out`: OUTだけをクリア
- `Clear All`: IN / OUTを両方クリア

新しい動画を開くと、以前のIN / OUTと音量状態はリセットされます。

## 画面表示

- `Time Code`には`現在位置 / フル尺`を表示
- INとOUTは独立したカードにタイムコードを表示
- FPSは読み込んだファイル名の下に`FPS: 29.97`形式で表示
- 動画未ロード時のFPSは`--`と表示
- Play / Pauseボタンは、文言が切り替わっても操作部分が動かない固定幅
- フレーム送り / 戻しは矢印キーで操作し、専用の`Frame -1` / `Frame +1`ボタンは表示しない
- ツールバーはコンパクト表示とし、`動画を開く`ボタンを配置

## ffmpegコマンド生成

次の条件をすべて満たした場合のみ、コマンドを生成します。

- 動画ファイルが読み込まれている
- INが設定されている
- OUTが設定されている
- `IN < OUT`である

生成されるコマンド例:

```bash
ffmpeg -ss 00:00:10.000 -to 00:00:25.000 -i "/Users/me/Videos/sample.mp4" -c copy "/Users/me/Videos/sample-cut.mp4"
```

生成規則:

- 入力には現在読み込んでいるファイルのフルパスを使用
- 出力先は入力ファイルと同じフォルダ
- 出力ファイル名は`source-cut.ext`
- 画面表示用タイムコードは`hh:mm:ss:ff`
- ffmpeg用タイムスタンプは`hh:mm:ss.fff`

例:

- `sample.mp4` -> `sample-cut.mp4`
- `sample.mov` -> `sample-cut.mov`

## 既知の制限

- タイムコードは確認用であり、放送用途の厳密なタイムコードではない
- `29.97` / `59.94` fpsのドロップフレーム表記には未対応
- VFR素材では表示に小さな誤差が出る可能性がある
- フレーム送り / 戻しは`1 / fps`秒単位の目安シーク
- `-c copy`による切り出しは、キーフレーム位置の影響で開始・終了位置が少しずれる可能性がある
- ファイル名に含まれるシェル特殊文字の厳密なエスケープには未対応

## 今後の改善候補

- `IN >= OUT`の場合に、無効な区間であることをより明確に表示
- 軽量な「最近使った項目」機能
- 必要性が明確になった場合のみ、最小限の設定画面を追加

## ライセンス

Copyright 2026 k8gma2mo10

Apache License 2.0で提供します。詳細は`LICENSE`を参照してください。
