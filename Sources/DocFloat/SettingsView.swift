import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var oauth: GoogleOAuth

  var body: some View {
    Form {
      Section("Window") {
        Toggle("Automatic opacity", isOn: $model.adaptiveContrast)
        Text(
          "Finds a readable opacity from your document and the background every 3 seconds. Requires Screen Recording permission. Samples stay in memory and are never saved or uploaded. Moving the slider switches to manual mode."
        )
        .font(.caption).foregroundStyle(.secondary)
        HStack {
          Text("Opacity")
          Slider(
            value: Binding(get: { model.opacity }, set: { model.setManualOpacity($0) }), in: 0...1)
          Text("\(Int(model.opacity * 100))%")
            .monospacedDigit()
            .frame(width: 44, alignment: .trailing)
        }
        Text(model.contrastStatus).font(.caption).foregroundStyle(.secondary)
        Button("Allow Screen Recording for Auto-adjust…") { model.requestContrastPermission() }
        if model.contrastPermissionNeeded {
          Text(
            "Enable DocFloat in macOS Privacy & Security → Screen & System Audio Recording. macOS may require reopening the app. Until then, Auto-adjust cannot see the background."
          )
          .font(.caption).foregroundStyle(.orange)
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
