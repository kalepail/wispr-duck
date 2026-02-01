import SwiftUI

struct WelcomeView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            Text("Welcome to WisprDuck")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Automatically lowers background audio when your mic is active so you can speak coherently.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
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
                    NSWorkspace.shared.open(privacySettingsURL)
                } label: {
                    Text("Enable System Audio Recording")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mallardGreen)
                .controlSize(.small)
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
        .frame(width: 400, height: 440)
    }
}
