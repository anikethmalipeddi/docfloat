import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var oauth: GoogleOAuth

  var body: some View {
    Form {
      Section("Window") {
        Toggle("Adaptive contrast", isOn: $model.adaptiveContrast)
        Text(
          "A frosted backdrop, visible edge, and at least 88% opacity keep notes readable over light or busy windows. Turn off for unrestricted transparency."
        )
        .font(.caption).foregroundStyle(.secondary)
        HStack {
          Text("Opacity")
          Slider(value: $model.opacity, in: 0.2...1.0)
          Text("\(Int(model.opacity * 100))%")
            .monospacedDigit()
            .frame(width: 44, alignment: .trailing)
        }
        Toggle("Click-through mode", isOn: $model.clickThrough)
        Toggle("Request screen-capture exclusion", isOn: $model.requestCaptureExclusion)
        Text(
          "On by default. Some capture apps ignore this macOS setting; notes may still appear in screen shares and recordings."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Toggle("Refresh Google Docs every 15 seconds", isOn: $model.autoRefresh)
        Text(
          "When click-through is on, use the DocFloat menu-bar icon to turn interaction back on."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section("Google Docs integration · optional") {
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
              .disabled(
                model.isLoading
                  || oauth.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
        Text(
          "Create a Desktop app OAuth client and enable Google Drive API and Google Docs API. Paste the client ID here. Read-only access; tokens stay in your Mac Keychain. Docs API enables the document tab picker."
        )
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
    .frame(width: 560, height: 560)
  }
}
