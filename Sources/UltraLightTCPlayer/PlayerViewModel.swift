import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

@MainActor
final class PlayerViewModel: ObservableObject {
    enum MarkSelection {
        case inPoint
        case outPoint
    }

    enum CommandMode: String, CaseIterable, Identifiable, Hashable {
        case cut = "Cut"
        case gif = "GIF"

        var id: Self { self }
    }

    static let gifFPSRange = 1...30
    static let gifWidthOptions = [320, 480, 640, 960, 1280, 1920]

    @Published private(set) var currentURL: URL?
    @Published private(set) var currentTime = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var fps = 30.0
    @Published private(set) var isPlaying = false
    @Published var scrubPosition = 0.0
    @Published private(set) var inPoint: Double?
    @Published private(set) var outPoint: Double?
    @Published private(set) var selectedMark: MarkSelection?
    @Published var volume = 1.0 {
        didSet {
            player.volume = Float(volume)
            if volume > 0, isMuted {
                isMuted = false
            }
        }
    }
    @Published var isMuted = false {
        didSet {
            player.isMuted = isMuted
        }
    }
    @Published var commandMode = CommandMode.cut {
        didSet {
            copyFeedback = nil
        }
    }
    @Published var gifFPS = 12 {
        didSet {
            let clampedFPS = Self.clampedGIFFPS(gifFPS)
            if gifFPS != clampedFPS {
                gifFPS = clampedFPS
            }
        }
    }
    @Published var gifWidth = 640 {
        didSet {
            if !Self.gifWidthOptions.contains(gifWidth) {
                gifWidth = 640
            }
        }
    }
    @Published private(set) var errorMessage: String?
    @Published private(set) var copyFeedback: String?

    let player = AVPlayer()

    private var timeObserver: Any?
    private var playbackEndObserver: NSObjectProtocol?
    private var keyboardMonitor: Any?
    private var copyFeedbackTask: Task<Void, Never>?
    private var assetLoadTask: Task<Void, Never>?
    private var isScrubbing = false

    init() {
        player.volume = Float(volume)
        attachTimeObserver()
    }

    var hasLoadedVideo: Bool {
        currentURL != nil
    }

    var currentFileName: String {
        currentURL?.lastPathComponent ?? "No video loaded"
    }

    var currentTimecode: String {
        TimecodeFormatter.displayTimecode(seconds: currentTime, fps: fps)
    }

    var durationTimecode: String {
        TimecodeFormatter.displayTimecode(seconds: duration, fps: fps)
    }

    var timelineTimecode: String {
        "\(currentTimecode) / \(durationTimecode)"
    }

    var inPointTimecode: String {
        guard let inPoint else { return "--:--:--:--" }
        return TimecodeFormatter.displayTimecode(seconds: inPoint, fps: fps)
    }

    var outPointTimecode: String {
        guard let outPoint else { return "--:--:--:--" }
        return TimecodeFormatter.displayTimecode(seconds: outPoint, fps: fps)
    }

    var fpsLabel: String {
        guard hasLoadedVideo else { return "--" }
        return TimecodeFormatter.fpsText(fps)
    }

    var hasInPoint: Bool {
        inPoint != nil
    }

    var hasOutPoint: Bool {
        outPoint != nil
    }

    var canCopyCommand: Bool {
        ffmpegCommand != nil
    }

    var ffmpegCommand: String? {
        switch commandMode {
        case .cut:
            return cutFFmpegCommand
        case .gif:
            return gifFFmpegCommand
        }
    }

    var cutFFmpegCommand: String? {
        guard let inputs = commandInputs else { return nil }

        let outputURL = makeCutOutputURL(for: inputs.currentURL)
        return """
        ffmpeg -ss \(TimecodeFormatter.ffmpegTimestamp(seconds: inputs.inPoint)) -to \(TimecodeFormatter.ffmpegTimestamp(seconds: inputs.outPoint)) -i "\(inputs.currentURL.path)" -c copy "\(outputURL.path)"
        """
    }

    var gifFFmpegCommand: String? {
        guard let inputs = commandInputs else { return nil }

        let outputURL = makeGIFOutputURL(for: inputs.currentURL)
        let filter = "[0:v]fps=\(gifFPS),scale=\(gifWidth):-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse"
        return """
        ffmpeg -ss \(TimecodeFormatter.ffmpegTimestamp(seconds: inputs.inPoint)) -to \(TimecodeFormatter.ffmpegTimestamp(seconds: inputs.outPoint)) -i "\(inputs.currentURL.path)" -filter_complex "\(filter)" -an -loop 0 "\(outputURL.path)"
        """
    }

    var ffmpegHint: String {
        guard currentURL != nil else {
            return "Open a video to start setting IN and OUT points."
        }

        guard let inPoint, let outPoint else {
            return "Set both IN and OUT to generate the selected ffmpeg command."
        }

        guard inPoint < outPoint else {
            return "IN must be earlier than OUT."
        }

        return ffmpegCommand ?? ""
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(from: url)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            var droppedURL: URL?

            if let data = item as? Data {
                droppedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                droppedURL = url
            } else if let nsURL = item as? NSURL {
                droppedURL = nsURL as URL
            }

            guard let droppedURL else { return }

            Task { @MainActor [weak self] in
                self?.loadVideo(from: droppedURL)
            }
        }

        return true
    }

    func togglePlayback() {
        guard hasLoadedVideo else { return }

        if isPlaying {
            pause()
        } else {
            player.play()
            isPlaying = true
        }
    }

    func stepFrame(forward: Bool) {
        guard hasLoadedVideo else { return }

        pause()

        let delta = 1.0 / max(fps, 1)
        let target = currentTime + (forward ? delta : -delta)
        seek(to: target)
    }

    func updateScrubPosition(_ value: Double) {
        scrubPosition = value

        if isScrubbing {
            currentTime = value
        }
    }

    func setScrubbing(_ editing: Bool) {
        isScrubbing = editing

        if editing {
            pause()
        } else {
            seek(to: scrubPosition)
        }
    }

    func setInPoint() {
        guard hasLoadedVideo else { return }
        inPoint = currentTime
        selectedMark = .inPoint
    }

    func setOutPoint() {
        guard hasLoadedVideo else { return }
        outPoint = currentTime
        selectedMark = .outPoint
    }

    func clearSelectedMark() {
        switch selectedMark {
        case .inPoint:
            clearInPoint()
        case .outPoint:
            clearOutPoint()
        case .none:
            break
        }
    }

    func clearInPoint() {
        inPoint = nil
        if selectedMark == .inPoint {
            selectedMark = nil
        }
    }

    func clearOutPoint() {
        outPoint = nil
        if selectedMark == .outPoint {
            selectedMark = nil
        }
    }

    func clearAllMarks() {
        inPoint = nil
        outPoint = nil
        selectedMark = nil
    }

    func copyCommandToPasteboard() {
        guard let ffmpegCommand else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ffmpegCommand, forType: .string)
        copyFeedback = "Copied"

        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copyFeedback = nil
        }
    }

    func startKeyboardMonitoring() {
        guard keyboardMonitor == nil else { return }

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
                return event
            }

            let action: (@MainActor () -> Void)?
            switch event.keyCode {
            case 49:
                action = { self.togglePlayback() }
            case 123:
                action = { self.stepFrame(forward: false) }
            case 124:
                action = { self.stepFrame(forward: true) }
            case 51, 117:
                action = { self.clearAllMarks() }
            case 53:
                action = { self.clearSelectedMark() }
            default:
                let characters = event.charactersIgnoringModifiers?.lowercased()
                switch characters {
                case "i":
                    action = { self.setInPoint() }
                case "o":
                    action = { self.setOutPoint() }
                default:
                    action = nil
                }
            }

            guard let action else { return event }

            Task { @MainActor in
                action()
            }
            return nil
        }
    }

    func stopKeyboardMonitoring() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func loadVideo(from url: URL) {
        guard isSupportedVideoURL(url) else {
            errorMessage = "This MVP focuses on .mp4 and .mov files."
            return
        }

        errorMessage = nil
        assetLoadTask?.cancel()
        resetPlaybackState(for: url)

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = false
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true

        assetLoadTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let resolvedDuration: Double
            do {
                let loadedDuration = try await asset.load(.duration)
                let durationSeconds = loadedDuration.seconds
                resolvedDuration = durationSeconds.isFinite ? durationSeconds : 0
            } catch is CancellationError {
                return
            } catch {
                resolvedDuration = 0
            }

            var resolvedFPS = 30.0
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                if let videoTrack = videoTracks.first {
                    let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                    let frameRate = Double(nominalFrameRate)
                    if frameRate > 0 {
                        resolvedFPS = frameRate
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                resolvedFPS = 30
            }

            guard !Task.isCancelled, currentURL == url else { return }
            duration = resolvedDuration
            fps = resolvedFPS
        }
    }

    private func resetPlaybackState(for url: URL) {
        currentURL = url
        currentTime = 0
        duration = 0
        fps = 30
        scrubPosition = 0
        inPoint = nil
        outPoint = nil
        selectedMark = nil
        volume = 1.0
        isMuted = false
        copyFeedback = nil
        copyFeedbackTask?.cancel()
    }

    private func attachTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = time.seconds
            guard seconds.isFinite else { return }

            let currentItemDuration = self?.player.currentItem?.duration.seconds

            Task { @MainActor [weak self] in
                guard let self else { return }

                currentTime = seconds

                if !isScrubbing {
                    scrubPosition = seconds
                }

                if let currentItemDuration, currentItemDuration.isFinite {
                    duration = currentItemDuration
                }
            }
        }
    }

    private func pause() {
        player.pause()
        isPlaying = false
    }

    private func seek(to seconds: Double) {
        let upperBound = duration > 0 ? duration : max(seconds, 0)
        let clamped = min(max(seconds, 0), upperBound)
        let target = CMTime(seconds: clamped, preferredTimescale: 600)

        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = clamped
                self?.scrubPosition = clamped
            }
        }
    }

    private var commandInputs: (currentURL: URL, inPoint: Double, outPoint: Double)? {
        guard let currentURL, let inPoint, let outPoint, inPoint < outPoint else {
            return nil
        }

        return (currentURL, inPoint, outPoint)
    }

    private static func clampedGIFFPS(_ value: Int) -> Int {
        min(max(value, gifFPSRange.lowerBound), gifFPSRange.upperBound)
    }

    private func makeCutOutputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let fileName = ext.isEmpty ? "\(stem)-cut" : "\(stem)-cut.\(ext)"
        return directory.appendingPathComponent(fileName)
    }

    private func makeGIFOutputURL(for sourceURL: URL) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let stem = sourceURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(stem).gif")
    }

    private func isSupportedVideoURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "mp4" || ext == "mov"
    }

}
