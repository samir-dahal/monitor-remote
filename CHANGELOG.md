# Changelog

Versions follow [Semantic Versioning](https://semver.org/).

## Monitor Remote for Android 0.1.0 (tag `app-v0.1.0`)

First release of the phone app, in `app/`.

- One screen that fits without scrolling: a tall brightness fader that follows the finger and ticks every 5%, − and + for single steps, tiles for blue light, input and picture mode, and scene pills along the bottom.
- Switching input offers Undo. Picking the current option again sends nothing.
- Scenes: tap to apply, long-press to rename, update or delete, + to save the current settings. Starts with Work, Night, Movie and Game.
- Names for options such as picture modes that the monitor only reports as codes.
- QR pairing, with manual entry as a fallback. The token is kept in the Android Keystore.
- Opens on the last known values and enables the controls once the PC answers.
- Factory and colour reset behind a hold-to-confirm button.
- Built, tested and signed by GitHub Actions when an `app-v*` tag is pushed.
- The Windows release is unchanged; `app/` is excluded from its build.
- The GitHub repository is now `samir-dahal/monitor-remote` (the old `benq-bridge` address redirects). The Windows app keeps the name BenQ Bridge.

## 0.1.0

First release.

- Controls any monitor that answers DDC/CI, building its controls from the monitor's own capability string.
- Mobile web UI with live updates over WebSocket and a monitor picker.
- Daily controls up top: brightness, input source, picture mode, low blue light. Sliders only respond to a touch that grabs the handle, so scrolling the page does not change settings.
- Hold-to-confirm factory and colour reset, shown only when the monitor advertises them.
- Pair a phone by scanning a QR code. The first run opens a pairing page in the browser; the token travels in the link fragment and is removed from the address bar once stored. Paired phones stay paired across restarts.
- Runs from a tray icon with no console window: Pair a phone, Open controls, Start with Windows and Quit. Launching the exe again while it runs opens the pairing page instead of starting a second server.
- Start with Windows, from the tray menu, the pairing page or `--install` / `--uninstall`. It uses the per-user startup list, so no admin rights are needed and the app runs in your desktop session, which monitor control requires.
- Options: `--port`, `--token`, `--pair`, `--no-browser`, `--install`, `--uninstall`, `--stop`.
- The token lives in `%LOCALAPPDATA%\BenqBridge`, so it survives a read-only install folder, an update or a re-extracted zip.
- Self-contained `win-x64` build, so the .NET runtime does not need to be installed.
- `scripts/release.ps1` builds the release from a clean clone and verifies the zip contents.
- One dependency, QRCoder (MIT), draws the QR code.
