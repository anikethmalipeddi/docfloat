# DocFloat

DocFloat is a small, open-source macOS app that keeps a Google Doc in a translucent, always-on-top window. It is designed for permitted reference notes during calls, presentations, and focused work.

## Features

- Adjustable window opacity
- Always on top, including full-screen Spaces
- Optional click-through mode (recoverable from the menu-bar icon)
- Public/shared Google Docs work by pasting a link
- Private Google Docs use Google's supported system-browser OAuth flow
- Read-only Drive permission; refresh tokens are stored in macOS Keychain
- No analytics, ads, or server

## Build and run

Requirements: macOS 14+ and Xcode Command Line Tools.

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/DocFloat.app
```

Or run directly during development:

```bash
swift run DocFloat
```

## Private Google Docs setup

Google does not permit OAuth authorization inside embedded webviews. DocFloat follows Google's desktop-app flow and opens sign-in in your normal browser.

1. Create or select a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the **Google Drive API**.
3. Configure the OAuth consent screen. For a personal/testing app, add your Google account as a test user.
4. Create an OAuth client with application type **Desktop app**.
5. Copy the client ID into DocFloat Settings, then choose **Sign in with Google**.

DocFloat requests only `https://www.googleapis.com/auth/drive.readonly`. The private document is exported to PDF in memory and rendered locally. Editing stays in your normal browser.

## Privacy and interview use

DocFloat does not hide itself from screen sharing or recording. If you use it during an interview, presentation, class, or assessment, confirm that reference notes are allowed.

## Development

```bash
swift test
```

## License

MIT
