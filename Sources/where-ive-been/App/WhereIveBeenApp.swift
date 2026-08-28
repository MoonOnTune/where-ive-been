import SwiftUI

@main
struct WhereIveBeenApp: App {
    @State private var store = JourneyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .defaultSize(width: 1380, height: 900)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Location History…") { store.showingImporter = true }
                    .keyboardShortcut("o")
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .frame(width: 560, height: 420)
        }
    }
}
