import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var oauth: GoogleOAuth

    var body: some View {
        Form {
            Section("Window") {
                HStack {
                    Text("Opacity")
                    Slider(value: $model.opacity, in: 0.2...1.0)
                    Text("\(Int(model.opacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Toggle("Click-through mode", isOn: $model.clickThrough)
                Text("When click-through is on, use the DocFloat menu-bar icon to turn interaction back on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Private Google Docs") {
                TextField("OAuth desktop client ID", text: $oauth.clientID)
                HStack {
                    Button("Google Cloud credentials") {
                        if let url = URL(string: "https://console.cloud.google.com/apis/credentials") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Spacer()
                    if oauth.isAuthenticated {
                        Button("Disconnect", role: .destructive) { model.disconnect() }
                    } else {
                        Button("Sign in with Google") { model.signIn() }
                            .disabled(oauth.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Text("Create a Desktop app OAuth client, enable the Google Drive API, then paste its client ID here. DocFloat requests read-only Drive access and stores the refresh token in your Mac Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 390)
    }
}
