import SwiftUI

@main
struct WisprDuckApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var duckController: DuckController

    init() {
        let s = AppSettings()
        _settings = StateObject(wrappedValue: s)
        _duckController = StateObject(wrappedValue: DuckController(settings: s))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(settings: settings, duckController: duckController)
        } label: {
            Image(systemName: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        if !settings.isEnabled {
            return "speaker.slash"
        }
        if duckController.isDucked {
            return "speaker.wave.1"
        }
        return "speaker.wave.3"
    }
}
