import SwiftUI
import AVFoundation

struct WelcomeView: View {
    @Bindable var settings: AppSettings
    @ObservedObject var duckController: DuckController
    @Environment(\.dismiss) private var dismiss
    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var systemAudioMessage: String?
    @State private var isRequestingSystemAudio = false

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            Text("Welcome to WisprDuck")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Automatically lowers background audio when your mic is active so you can speak coherently.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image("DuckFoot")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text("Look for the duck foot in your menu bar")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    requestMicrophoneAccess()
                } label: {
                    HStack {
                        Text(microphoneButtonTitle)
                        Spacer()
                        Text(microphoneStatusLabel)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mallardGreen)
                .controlSize(.small)
                .disabled(microphoneStatus == .authorized)

                Button {
                    requestSystemAudioAccess()
                } label: {
                    HStack {
                        Text(isRequestingSystemAudio ? "Requesting System Audio..." : "Allow System Audio Recording")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mallardGreen)
                .controlSize(.small)
                .disabled(isRequestingSystemAudio)

                Button {
                    NSWorkspace.shared.open(privacySettingsURL)
                } label: {
                    Text("Open System Audio Settings")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let systemAudioMessage {
                    Text(systemAudioMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Button {
                settings.hasCompletedOnboarding = true
                dismiss()
            } label: {
                Text("Get Quacking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.mallardGreen)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 420, height: 520)
        .onAppear {
            microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }

    private var microphoneButtonTitle: String {
        switch microphoneStatus {
        case .authorized:
            return "Microphone Allowed"
        case .denied, .restricted:
            return "Open Microphone Settings"
        case .notDetermined:
            return "Allow Microphone"
        @unknown default:
            return "Allow Microphone"
        }
    }

    private var microphoneStatusLabel: String {
        switch microphoneStatus {
        case .authorized:
            return "Allowed"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Required"
        @unknown default:
            return "Unknown"
        }
    }

    private func requestMicrophoneAccess() {
        switch microphoneStatus {
        case .authorized:
            return
        case .denied, .restricted:
            NSWorkspace.shared.open(microphonePrivacySettingsURL)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                }
            }
        @unknown default:
            NSWorkspace.shared.open(microphonePrivacySettingsURL)
        }
    }

    private func requestSystemAudioAccess() {
        isRequestingSystemAudio = true
        systemAudioMessage = nil

        if let errorMessage = duckController.requestSystemAudioPermissionPrompt() {
            systemAudioMessage = errorMessage
            NSWorkspace.shared.open(privacySettingsURL)
            isRequestingSystemAudio = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isRequestingSystemAudio = false
            systemAudioMessage = "If no prompt appeared, enable WisprDuck in System Settings."
        }
    }
}
