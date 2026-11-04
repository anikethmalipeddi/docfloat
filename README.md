# DocFloat

A lightweight, always-on-top notes viewer for Mac, with adjustable transparency, quick search, and optional Google Docs integration.

**Automatic opacity** is on by default. In Settings, choose **Enable background sampling** and grant macOS Screen Recording permission. DocFloat samples the document and the area behind it every 3 seconds, excludes itself from background capture, and estimates an opacity targeting readable text contrast. Samples stay in memory—never saved or uploaded. Without permission, the app shows that automatic sampling is unavailable. The slider switches to manual mode with a full **0–100%** range; recover a fully hidden overlay with **Show & Unlock DocFloat** in the menu bar.

## Get started

1. [Download the latest release](https://github.com/anikethmalipeddi/docfloat/releases/latest), unzip, and move DocFloat to Applications. Requires an Apple silicon Mac running macOS 14+.
2. Choose **Open Notes** to open a PDF—no account needed.
3. Adjust opacity in the toolbar. Use **⇧⌘K** for compact mode, **⌘+ / ⌘−** to zoom, and **⌘O** to open a PDF.

Click-through is available in the menu-bar icon. Choose **Show & Unlock DocFloat** there to interact again. Local PDFs do not sync; reopen them after quitting.

The downloadable app is locally signed, not Apple-notarized. Source is available below. No analytics or DocFloat server.

## Build and run

Requires macOS 14+ and Xcode Command Line Tools.

```bash
./scripts/build-app.sh
open dist/DocFloat.app
swift test
```

**Find:** press **Control-F** or **⌘F**, type a phrase, then **Return / ⌘G** for the next match or **⇧⌘G** for the previous one. Search wraps around and ignores case. PDFs must contain selectable text (scanned images need OCR first).

## Google Docs integration (optional)

Paste a shared Google Docs link and press **Load**. Edit through the browser button; saved changes refresh here every **15 seconds**. Shared Docs keep Google's native tabs/subtabs in preview; preview refresh pauses while the overlay has focus. You can disable automatic refresh in Settings.

For private Docs, connect your Google account below, or download through **File → Download → PDF** in Google Docs and open the PDF as local notes.

In [Google Cloud](https://console.cloud.google.com/apis/credentials), enable **Drive API and Google Docs API**, configure OAuth consent with your account as a test user, and create a **Desktop app** client. Paste its client ID in Settings and sign in through your browser.

**Document tabs:** with Google connected and Docs API enabled, a tab picker appears under the toolbar, including nested tabs. Choose a tab to jump straight to its notes; auto-refresh keeps that tab selected. This reading view supports text, headings, bold/italic, lists, and tables; images and exact page layout are not reproduced. Shared links without a Google connection use Google's own tab navigation instead.

This requests read-only access to Drive, exports the selected Doc as a PDF, and keeps the refresh token in macOS Keychain. Disconnect removes the local token; revoke access in your Google account to remove the grant. Sign-in requires your own Cloud configuration and has not been tested with a live account.

Screen-capture exclusion is requested by default and can be changed in Settings. macOS capture tools may ignore it; invisibility is not guaranteed. Share a specific app/window instead of your whole display to keep DocFloat outside the selected source.

MIT licensed.
