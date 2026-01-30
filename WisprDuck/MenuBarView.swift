import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var duckController: DuckController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Enable toggle
            Toggle("Enable Monitoring", isOn: $settings.isEnabled)

            Divider()

            // Duck level slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Duck Level: \(settings.duckLevel)%")
                    .font(.subheadline)
                Slider(
                    value: Binding(
                        get: { Double(settings.duckLevel) },
                        set: {
                            settings.duckLevel = Int($0)
                            duckController.updateDuckLevel(Int($0))
                        }
                    ),
                    in: 0...100,
                    step: 5
                )
            }

            Divider()

            // Duck mode selection
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Duck All Audio", isOn: $settings.duckAllAudio)
                if settings.duckAllAudio {
                    Text("Ducks every app producing audio — browsers, music, games, everything")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Only selected apps below will be ducked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Audio apps list
            Text("Audio Apps (\(duckController.audioApps.count))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if duckController.audioApps.isEmpty {
                Text("No apps are currently producing audio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(duckController.audioApps) { app in
                            AudioAppRow(
                                app: app,
                                settings: settings
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .opacity(settings.duckAllAudio ? 0.4 : 1.0)
                .disabled(settings.duckAllAudio)
            }

            Divider()

            // Quit
            Button("Quit WisprDuck") {
                duckController.restoreAndStop()
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private var statusColor: Color {
        if !settings.isEnabled { return .gray }
        if duckController.isDucked { return .orange }
        return .green
    }

    private var statusText: String {
        if !settings.isEnabled { return "Disabled" }
        if duckController.isDucked { return "Ducked" }
        if duckController.micMonitor.isMicActive { return "Mic Active" }
        return "Monitoring"
    }
}

private struct AudioAppRow: View {
    let app: AudioApp
    @ObservedObject var settings: AppSettings

    var body: some View {
        Toggle(isOn: Binding(
            get: { settings.isBundleIDEnabled(app.bundleID) },
            set: { _ in settings.toggleBundleID(app.bundleID) }
        )) {
            Text(app.name)
        }
    }
}
