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

            // Trigger source
            AppFilterSection(
                title: "Trigger All Apps",
                isAll: $settings.triggerAllApps,
                allCaption: "Any mic use triggers ducking",
                selectedLabel: "Triggering",
                unselectedLabel: "Not triggering",
                emptySelected: "No trigger apps selected yet",
                emptyUnselected: "No apps using audio",
                apps: duckController.triggerEligibleApps,
                isEnabled: { settings.isTriggerBundleIDEnabled($0) },
                toggle: { settings.toggleTriggerBundleID($0) }
            )

            Divider()

            // Duck target
            AppFilterSection(
                title: "Duck All Apps",
                isAll: $settings.duckAllApps,
                allCaption: "All audio apps are ducked",
                selectedLabel: "Ducking",
                unselectedLabel: "Not ducking",
                emptySelected: "No duck targets selected yet",
                emptyUnselected: "No apps playing audio",
                apps: duckController.audioApps,
                isEnabled: { settings.isBundleIDEnabled($0) },
                toggle: { settings.toggleBundleID($0) }
            )

            Divider()

            HStack {
                Link("WisprDuck v\(Bundle.shortVersion)", destination: URL(string: "https://wisprduck.com")!)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .underline()
                Spacer()
                Button("Permissions") {
                    NSWorkspace.shared.open(privacySettingsURL)
                }
                .footerButtonStyle()
                Button("Quit") {
                    duckController.restoreAndStop()
                    NSApplication.shared.terminate(nil)
                }
                .footerButtonStyle()
            }
        }
        .padding(16)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusColor: Color {
        if !settings.isEnabled { return .gray }
        if duckController.isDucked { return .orange }
        return .mallardGreen
    }

    private var statusText: String {
        if !settings.isEnabled { return "Disabled" }
        if duckController.isDucked { return "Ducked" }
        if duckController.micMonitor.isMicActive { return "Mic Active" }
        return "Monitoring"
    }
}

// MARK: - Color Extension

extension Color {
    static let mallardGreen = Color(red: 0.075, green: 0.42, blue: 0.227)
}

// MARK: - Bundle Extension

extension Bundle {
    static var shortVersion: String {
        main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Footer Button Style

private extension View {
    func footerButtonStyle() -> some View {
        self
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Shared Components

private struct AppFilterSection: View {
    let title: String
    @Binding var isAll: Bool
    let allCaption: String
    let selectedLabel: String
    let unselectedLabel: String
    let emptySelected: String
    let emptyUnselected: String
    let apps: [AudioApp]
    let isEnabled: (String) -> Bool
    let toggle: (String) -> Void

    private var selected: [AudioApp] {
        apps.filter { isEnabled($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var unselected: [AudioApp] {
        apps.filter { !isEnabled($0.bundleID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: $isAll)
            Text(allCaption)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !isAll {
                // Selected apps
                AppSublist(
                    label: selectedLabel,
                    apps: selected,
                    emptyText: emptySelected,
                    isEnabled: isEnabled,
                    toggle: toggle
                )

                // Unselected apps
                AppSublist(
                    label: unselectedLabel,
                    apps: unselected,
                    emptyText: emptyUnselected,
                    isEnabled: isEnabled,
                    toggle: toggle
                )
            }
        }
    }
}

private struct AppSublist: View {
    let label: String
    let apps: [AudioApp]
    let emptyText: String
    let isEnabled: (String) -> Bool
    let toggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("(\(apps.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            if apps.isEmpty {
                Text(emptyText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(apps) { app in
                            Toggle(isOn: Binding(
                                get: { isEnabled(app.bundleID) },
                                set: { _ in toggle(app.bundleID) }
                            )) {
                                Text(app.name)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 90)
            }
        }
    }
}
