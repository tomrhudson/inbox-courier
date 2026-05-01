import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct InboxCourierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var statusStore = StatusStore()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(store: statusStore)
                .onAppear {
                    statusStore.refresh()
                }
        } label: {
            Label(statusStore.menuTitle, systemImage: statusStore.systemImage)
        }
        .menuBarExtraStyle(.menu)
    }
}
