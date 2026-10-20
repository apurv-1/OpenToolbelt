import AppKit
import SwiftUI

struct OpenToolbeltApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store: Store = {
        let store = Store()
        store.refresh()
        return store
    }()

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environment(store)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)

        Window("OpenToolbelt", id: WindowID.main) {
            MainWindow().environment(store)
        }
        .defaultSize(width: 1080, height: 740)
        // Custom chrome: no title bar or toolbar, only the window controls.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let main = "main"
}

/// Keeps the app out of the Dock: it lives in the menu bar and opens its
/// window on demand.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
