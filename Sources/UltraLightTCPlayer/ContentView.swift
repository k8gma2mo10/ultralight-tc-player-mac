import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            playerArea
            Divider()
            inspectorPanel
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.startKeyboardMonitoring()
        }
        .onDisappear {
            viewModel.stopKeyboardMonitoring()
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            viewModel.handleDrop(providers: providers)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("動画を開く", action: viewModel.openFilePanel)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.small)
            }
        }
    }

    private var playerArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.92))

            if viewModel.hasLoadedVideo {
                PlayerSurfaceView(player: viewModel.player)
                    .padding(20)
            } else {
                emptyState
                    .padding(32)
            }

            if isDropTargeted {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                    .padding(24)
                        .overlay {
                        Text("ここに .mp4 または .mov をドロップして開く")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Text("UltraLight TC Player")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Open a video with Command+O or drag a file into the window.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
    }

    private var inspectorPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ReadoutCard(
                    title: "Time Code",
                    value: viewModel.timelineTimecode,
                    tint: .accentColor,
                    isSelected: false,
                    fontSize: 20,
                    minimumScaleFactor: 0.6
                )
                .frame(minWidth: 340, maxWidth: .infinity)
                ReadoutCard(
                    title: "IN",
                    value: viewModel.inPointTimecode,
                    tint: .green,
                    isSelected: viewModel.selectedMark == .inPoint
                )
                .frame(width: 220)
                ReadoutCard(
                    title: "OUT",
                    value: viewModel.outPointTimecode,
                    tint: .pink,
                    isSelected: viewModel.selectedMark == .outPoint
                )
                .frame(width: 220)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.currentFileName)
                            .font(.headline)
                            .lineLimit(1)

                        Text("FPS: \(viewModel.fpsLabel)")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                Slider(
                    value: Binding(
                        get: { viewModel.scrubPosition },
                        set: { viewModel.updateScrubPosition($0) }
                    ),
                    in: 0...max(viewModel.duration, 0.001),
                    onEditingChanged: viewModel.setScrubbing
                )
                .disabled(!viewModel.hasLoadedVideo)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.togglePlayback()
                }
                label: {
                    Text(viewModel.isPlaying ? "Pause" : "Play")
                        .frame(width: 88)
                }
                .disabled(!viewModel.hasLoadedVideo)

                Button("Set IN") {
                    viewModel.setInPoint()
                }
                .disabled(!viewModel.hasLoadedVideo)

                Button("Set OUT") {
                    viewModel.setOutPoint()
                }
                .disabled(!viewModel.hasLoadedVideo)

                Button("Clear In") {
                    viewModel.clearInPoint()
                }
                .disabled(!viewModel.hasInPoint)

                Button("Clear Out") {
                    viewModel.clearOutPoint()
                }
                .disabled(!viewModel.hasOutPoint)

                Button("Clear All") {
                    viewModel.clearAllMarks()
                }
                .disabled(!viewModel.hasInPoint && !viewModel.hasOutPoint)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        viewModel.isMuted.toggle()
                    }
                    label: {
                        Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(minWidth: 18)
                    }
                    .disabled(!viewModel.hasLoadedVideo)

                    Slider(value: $viewModel.volume, in: 0...1)
                        .frame(width: 160)
                        .disabled(!viewModel.hasLoadedVideo)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("ffmpeg Command")
                        .font(.headline)

                    Spacer()

                    if let copyFeedback = viewModel.copyFeedback {
                        Text(copyFeedback)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Copy") {
                        viewModel.copyCommandToPasteboard()
                    }
                    .disabled(!viewModel.canCopyCommand)
                }

                ScrollView {
                    Text(viewModel.ffmpegHint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
                .frame(minHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }
        }
        .padding(18)
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
    }
}

private struct ReadoutCard: View {
    let title: String
    let value: String
    let tint: Color
    let isSelected: Bool
    var fontSize: CGFloat = 24
    var minimumScaleFactor: CGFloat = 0.85

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? tint.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isSelected ? tint.opacity(0.65) : Color.clear, lineWidth: 1.5)
        )
    }
}
