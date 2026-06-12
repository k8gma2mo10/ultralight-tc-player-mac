import Foundation

enum TimecodeFormatter {
    static func displayTimecode(seconds: Double, fps: Double) -> String {
        let safeFPS = fps > 0 ? fps : 30
        let totalFrames = max(Int((seconds * safeFPS).rounded()), 0)
        let frameBase = max(Int(safeFPS.rounded()), 1)

        let hours = totalFrames / (frameBase * 60 * 60)
        let minutes = (totalFrames % (frameBase * 60 * 60)) / (frameBase * 60)
        let secs = (totalFrames % (frameBase * 60)) / frameBase
        let frames = totalFrames % frameBase

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, secs, frames)
    }

    static func ffmpegTimestamp(seconds: Double) -> String {
        let clampedSeconds = max(seconds, 0)
        let totalMilliseconds = Int((clampedSeconds * 1000).rounded())
        let hours = totalMilliseconds / 3_600_000
        let minutes = (totalMilliseconds % 3_600_000) / 60_000
        let secs = (totalMilliseconds % 60_000) / 1000
        let milliseconds = totalMilliseconds % 1000

        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, milliseconds)
    }

    static func fpsText(_ fps: Double) -> String {
        if fps.rounded() == fps {
            return String(format: "%.0f", fps)
        }

        return String(format: "%.3f", fps)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
