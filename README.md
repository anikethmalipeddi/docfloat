# DocFloat

Keep your notes above other windows on your Mac. Adjust transparency, zoom in, and switch to compact mode when a call starts.

## Get started

1. [Download the latest release](https://github.com/anikethmalipeddi/docfloat/releases/latest), unzip, and move DocFloat to Applications. Requires an Apple silicon Mac running macOS 14+.
2. Paste a shared Google Docs link and press **Load**, or choose **Open PDF**. For private notes, download your Doc through **File → Download → PDF** in Google Docs.
3. Adjust opacity in the toolbar. Use **⇧⌘K** for compact mode, **⌘+ / ⌘−** to zoom, and **⌘O** to open a PDF.

Click-through is available in the menu-bar icon. Choose **Show & Unlock DocFloat** there to interact again. PDFs stay in memory; reopen them after quitting. Private Google exports are snapshots—reload to fetch edits.

The downloadable app is locally signed, not Apple-notarized. Source is available below. No analytics or DocFloat server.

## Build and run

Requires macOS 14+ and Xcode Command Line Tools.

```bash
./scripts/build-app.sh
open dist/DocFloat.app
swift test
```

## Optional Google sign-in

In [Google Cloud](https://console.cloud.google.com/apis/credentials), enable Drive API, configure OAuth consent with your account as a test user, and create a **Desktop app** client. Paste its client ID in Settings and sign in through your browser.

This requests read-only access to Drive, exports the selected Doc as a PDF, and keeps the refresh token in macOS Keychain. Disconnect removes the local token; revoke access in your Google account to remove the grant. Sign-in requires your own Cloud configuration and has not been tested with a live account.

MIT licensed. Notes remain visible to screen sharing.
