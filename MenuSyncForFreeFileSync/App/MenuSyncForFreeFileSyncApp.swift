import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct MenuSyncForFreeFileSyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: SettingsStore
    @StateObject private var model: AppModel

    init() {
        let settings = SettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _model = StateObject(wrappedValue: AppModel(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            CompanionMenuView(model: model)
                .environmentObject(settings)
        } label: {
            Image(nsImage: model.menuBarImage)
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityLabel(model.menuBarStatusText)
        }
        .menuBarExtraStyle(.window)
    }
}
