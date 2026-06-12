import SwiftUI

@main
struct UltraLightTCPlayerApp: App {
    @StateObject private var viewModel = PlayerViewModel()

    var body: some Scene {
        WindowGroup("UltraLight TC Player") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 960, minHeight: 720)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("開く...") {
                    viewModel.openFilePanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
