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
            Image(duckController.isDucked ? "DuckFootFill" : "DuckFoot")
                .opacity(settings.isEnabled ? 1.0 : 0.5)
        }
        .menuBarExtraStyle(.window)
    }
}
