import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var duckController: DuckController
    @State private var refreshID = UUID()

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
                        set: { settings.duckLevel = Int($0) }
                    ),
                    in: 0...100,
                    step: 5
                )
            }

            // Debounce delay
            VStack(alignment: .leading, spacing: 4) {
                Text("Restore Delay: \(String(format: "%.1f", settings.debounceDelay))s")
                    .font(.subheadline)
                Slider(
                    value: $settings.debounceDelay,
                    in: 0.5...10.0,
                    step: 0.5
                )
            }

            Divider()

            // System volume duck mode
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Duck System Volume", isOn: $settings.duckSystemVolume)
                    .disabled(!duckController.isSystemVolumeAvailable)
                if !duckController.isSystemVolumeAvailable {
                    Text("Not available — \(duckController.outputDeviceName) doesn't support software volume control")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if settings.duckSystemVolume {
                    Text("Ducks all audio output — browsers, music apps, everything")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Off — only selected music apps below will be ducked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // App list
            HStack {
                Text("Music Apps")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                if systemVolumeModeActive {
                    Text("(system volume active)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        refreshID = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh app list")
                }
            }

            ForEach(settings.configuredApps) { app in
                AppRow(app: app, settings: settings)
            }
            .id(refreshID)
            .opacity(systemVolumeModeActive ? 0.4 : 1.0)
            .disabled(systemVolumeModeActive)

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

    private var systemVolumeModeActive: Bool {
        settings.duckSystemVolume && duckController.isSystemVolumeAvailable
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

private struct AppRow: View {
    let app: MusicApp
    @ObservedObject var settings: AppSettings

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { settings.isAppEnabled(app) },
                set: { _ in settings.toggleApp(app) }
            )) {
                HStack(spacing: 6) {
                    Text(app.displayName)
                    if app.isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}
