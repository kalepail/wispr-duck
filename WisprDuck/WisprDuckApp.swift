import SwiftUI

@main
struct WisprDuckApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var duckController: DuckController
    @Environment(\.openWindow) private var openWindow

    init() {
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        _duckController = StateObject(wrappedValue: DuckController(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(settings: settings, duckController: duckController)
        } label: {
            Image("DuckFoot")
                .opacity(settings.isEnabled ? 1.0 : 0.5)
                .task {
                    if !settings.hasCompletedOnboarding {
                        NSApp.setActivationPolicy(.regular)
                        openWindow(id: "welcome")
                    }
                }
        }
        .menuBarExtraStyle(.window)

        Window("Welcome", id: "welcome") {
            WelcomeView(settings: settings)
                .onDisappear {
                    NSApp.setActivationPolicy(.accessory)
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
    }
}
