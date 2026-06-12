# UltraLight TC Player

UltraLight TC Player is a lightweight macOS tool for checking video, grabbing IN / OUT positions, and copying an `ffmpeg` cut command.

This version is intentionally small and focused:

- Apple Silicon macOS only
- macOS 26.0 or later
- SwiftUI + AVFoundation / AVKit
- H.264 `.mp4` is the main target
- `.mov` is supported when AVFoundation can open it naturally
- The app does not run `ffmpeg` itself
- The app icon is generated from `UltraLight-TC-Player-icon.png`

Current release:

- Version: `1.0.0`
- Build: `1`
- Bundle ID: `io.github.k8gma2mo10.ultralight-tc-player-mac`

## Requirements

- macOS 26 or later
- Apple Silicon Mac
- Xcode 26.5 or later
- `xcodegen` 2.45.4 or later

## Build

Generate the Xcode project:

```bash
xcodegen generate
```

Build from the command line:

```bash
xcodebuild -project UltraLightTCPlayer.xcodeproj -scheme UltraLightTCPlayer -configuration Debug -derivedDataPath ./.DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Or open the project in Xcode:

```bash
open UltraLightTCPlayer.xcodeproj
```

## Run

The built app is created here after a Debug build:

```text
./.DerivedData/Build/Products/Debug/UltraLightTCPlayer.app
```

You can run it from Finder, from Xcode, or with:

```bash
open ./.DerivedData/Build/Products/Debug/UltraLightTCPlayer.app
```

## Install a GitHub Release

The GitHub Release build is distributed free of charge without a Developer ID signature or Apple notarization. It has an ad-hoc signature for bundle integrity, but macOS Gatekeeper will not identify it as software from a verified developer.

1. Download `UltraLightTCPlayer-mac-arm64-v1.0.0.zip` from GitHub Releases.
2. Optionally verify the ZIP against the accompanying `.sha256` file.
3. Extract the ZIP and move `UltraLightTCPlayer.app` to the Applications folder.
4. Try to open the app once. macOS will block the first launch.
5. Open `System Settings > Privacy & Security`.
6. Find the message for UltraLight TC Player and select `Open Anyway`.
7. Confirm by selecting `Open`.

The security override may be unavailable on a Mac managed by an organization. Test the downloaded GitHub asset on another Apple Silicon Mac when possible, because a locally built app does not reproduce the same download quarantine behavior.

Verify the archive checksum from Terminal:

```bash
shasum -a 256 -c UltraLightTCPlayer-mac-arm64-v1.0.0.zip.sha256
```

## Release Build

Generate the project and build the Release configuration:

```bash
xcodegen generate
xcodebuild -project UltraLightTCPlayer.xcodeproj -scheme UltraLightTCPlayer -configuration Release -derivedDataPath ./.DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Apply a free ad-hoc signature and verify the bundle:

```bash
codesign --force --sign - --options runtime --timestamp=none ./.DerivedData/Build/Products/Release/UltraLightTCPlayer.app
codesign --verify --deep --strict --verbose=2 ./.DerivedData/Build/Products/Release/UltraLightTCPlayer.app
```

The public repository intentionally excludes `sample.mp4`, generated `.xcodeproj` files, `.DerivedData`, and release archives. Building from source requires XcodeGen.

## Usage

- `⌘ + O`: Open a video
- Drag and drop: Open a video by dropping it into the window
- Auto play: The app starts playback right after a file is opened
- `Space`: Play / pause
- `Right Arrow`: Step forward by about `1 / fps`
- `Left Arrow`: Step backward by about `1 / fps`
- `I`: Set IN at the current position
- `O`: Set OUT at the current position
- `Esc`: Clear only the currently selected IN or OUT
- `Delete`: Clear IN / OUT
- `fn + Delete`: Clear IN / OUT
- `Clear In`: Clear only IN
- `Clear Out`: Clear only OUT
- `Clear All`: Clear both IN and OUT

Opening a new video clears the previous IN / OUT points and resets audio state.

## Interface

- The `Time Code` readout displays `current position / full duration`
- IN and OUT timecodes remain visible in separate readout cards
- FPS is displayed below the loaded file name as `FPS: 29.97`
- FPS is displayed as `--` before a video is loaded
- The Play / Pause button uses a fixed width so the controls do not shift when its label changes
- Frame stepping remains available through the arrow keys; dedicated `Frame -1` / `Frame +1` buttons are not shown
- The toolbar uses a compact style with a `動画を開く` button

## ffmpeg Command Generation

The app generates a command only when all of the following are true:

- A source file is loaded
- IN is set
- OUT is set
- `IN < OUT`

Generated command format:

```bash
ffmpeg -ss 00:00:10.000 -to 00:00:25.000 -i "/Users/me/Videos/sample.mp4" -c copy "/Users/me/Videos/sample-cut.mp4"
```

Rules:

- Input path uses the currently loaded source file
- Output path is created in the same folder
- Output file name is `source-cut.ext`
- Display timecode uses `hh:mm:ss:ff`
- ffmpeg timestamps use `hh:mm:ss.fff`

Examples:

- `sample.mp4` -> `sample-cut.mp4`
- `sample.mov` -> `sample-cut.mov`

## Known Limitations

- Timecode is a practical confirmation display, not broadcast-accurate timecode
- Drop-frame notation for `29.97` / `59.94` is not implemented
- VFR material can show small timing differences
- Frame stepping is an approximate seek by `1 / fps`
- `-c copy` cuts can drift slightly because of keyframe boundaries
- Shell-special-character escaping in file names is not handled strictly

## Future Ideas

- Add a clearer invalid-range state when `IN >= OUT`
- Add a small "Open Recent" flow
- Add a lightweight preferences screen only if a real need appears

## License

Copyright 2026 k8gma2mo10

Licensed under the Apache License, Version 2.0. See `LICENSE` for details.
