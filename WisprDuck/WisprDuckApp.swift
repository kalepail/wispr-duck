import SwiftUI

@main
struct WisprDuckApp: App {
    @State private var settings: AppSettings
    @StateObject private var duckController: DuckController
    @Environment(\.openWindow) private var openWindow

    init() {
        let s = AppSettings()
        _settings = State(wrappedValue: s)
        _duckController = StateObject(wrappedValue: DuckController(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(settings: settings, duckController: duckController)
        } label: {
            Image(settings.isEnabled ? "DuckFoot" : "DuckFootDimmed")
                .id(settings.isEnabled)
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
