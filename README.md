# DocFloat

A lightweight, always-on-top notes viewer for Mac, with adjustable transparency, quick search, and optional Google Docs integration.

**Auto-adjust runs once per click.** It samples the document and the background, excluding DocFloat itself, then keeps that opacity until you change it. Enable background sampling in Settings and grant macOS Screen Recording permission. Samples are never saved or uploaded. Manual opacity spans **0–100%**; recover a hidden overlay with **Show & Unlock DocFloat** in the menu bar.

## Get started

Click **Auto-adjust** (⇧⌘A) to calculate opacity from the actual background. If Screen Recording permission is missing, it opens setup and leaves your opacity unchanged. A visible status confirms whether background sampling is active. For instant clarity without sampling, choose **Fully readable (100%)** from its right-click menu or the menu-bar icon. Manual opacity spans 0–100%.

1. [Download the latest release](https://github.com/anikethmalipeddi/docfloat/releases/latest), unzip, and move DocFloat to Applications. Requires an Apple silicon Mac running macOS 14+.
2. Choose **Open Notes** to open a PDF—no account needed.
3. Adjust opacity in the toolbar. Use **⇧⌘K** for compact mode, **⌘+ / ⌘−** to zoom, and **⌘O** to open a PDF.

Click-through is available in the menu-bar icon. Choose **Show & Unlock DocFloat** there to interact again. Local PDFs do not sync; reopen them after quitting.

The downloadable app is signed, not Apple-notarized. No analytics or DocFloat server. Background sampling permission may need reapproval when moving from earlier ad-hoc builds to the development-signed version.

## Build and run

Requires macOS 14+ and Xcode Command Line Tools.

```bash
./scripts/build-app.sh
open dist/DocFloat.app
swift test
```

**Find:** press **Control-F** or **⌘F**, type a phrase, then **Return / ⌘G** for the next match or **⇧⌘G** for the previous one. Search wraps around and ignores case. PDFs must contain selectable text (scanned images need OCR first).

## Google Docs integration (optional)

Paste a shared Google Docs link and press **Load**. Edit through the browser button, then click **Load** or press **⌘R** to refresh when you want. DocFloat does not automatically reload your notes. Shared Docs keep Google's native tabs/subtabs in preview.

For private Docs, connect your Google account below, or download through **File → Download → PDF** in Google Docs and open the PDF as local notes.

In [Google Cloud](https://console.cloud.google.com/apis/credentials), enable **Drive API and Google Docs API**, configure OAuth consent with your account as a test user, and create a **Desktop app** client. Paste its client ID in Settings and sign in through your browser.

**Document tabs:** with Google connected and Docs API enabled, a tab picker appears under the toolbar, including nested tabs. Choose a tab to jump straight to its notes; manual reload keeps that tab selected. This reading view supports text, headings, bold/italic, lists, and tables; images and exact page layout are not reproduced. Shared links without a Google connection use Google's own tab navigation instead.

This requests read-only access to Drive, exports the selected Doc as a PDF, and keeps the refresh token in macOS Keychain. Disconnect removes the local token; revoke access in your Google account to remove the grant. Sign-in requires your own Cloud configuration and has not been tested with a live account.

Screen-capture exclusion is requested by default and can be changed in Settings. macOS capture tools may ignore it; invisibility is not guaranteed. Share a specific app/window instead of your whole display to keep DocFloat outside the selected source.

MIT licensed.
