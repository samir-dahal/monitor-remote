# BenQ Bridge for Android

A phone remote for [BenQ Bridge](../README.md). Pair it once with your PC, then control your
monitor's brightness, input, picture mode and eye-care settings from the couch. It talks to the
same HTTP and WebSocket API as the web page, so the PC side needs no changes.

## What it does

- **Control:** brightness with a big readout and − / + buttons, scenes, input source, low blue
  light and picture mode. Everything else the monitor reports is under **All controls**.
- **Scenes:** Work, Night, Movie and Game to start with. Save your own from the current settings.
  Scenes live on the phone and never touch the input source.
- **Name your options:** some picture modes only show up as codes such as `0x0F`. Give them names
  you recognise. Names are saved on the phone.
- **Pairing:** scan the QR code on the PC's pairing page, or type the address and token.
- **Reset:** factory and colour resets sit behind a hold-to-confirm button in Settings.
- **Live:** changes made on the PC or the monitor's own buttons show up on the phone.

## Requirements

- Flutter 3.41 or newer (Dart 3.11)
- Android SDK 36 and a device or emulator running Android 7.0 (API 24) or newer
- BenQ Bridge 0.1.0 or newer running on a PC on the same network

## Run it

```powershell
cd app
flutter pub get
flutter run
```

## Build an APK

```powershell
flutter build apk --release
```

The APK is written to `build\app\outputs\flutter-apk\app-release.apk`. It is signed with the
debug key, which is fine for installing on your own devices; sign it properly before sharing it.

## Test

```powershell
flutter analyze
flutter test --coverage
```

The tests use an in-memory fake of the PC, so no monitor or network is needed.

## How it is organised

```
lib/
  core/    theme, app version, BridgeScope (makes the controller available to screens)
  data/    models, the HTTP/WebSocket client, pairing-link parsing, local storage
  state/   BridgeController (connection, writes, scenes, names, theme) and Scene
  ui/      screens and the widgets they share
```

- `BridgeController` is the single source of truth. Screens read it through `BridgeScope`.
- Writes show immediately, collapse to the newest value while a request is in flight, and go out
  in order per control. A control being dragged is not moved by updates from the PC.
- The connection retries with a growing delay. A rejected token stops the retrying and asks to
  pair again.
- The access token is kept in the Android Keystore through `flutter_secure_storage`.

## Plain HTTP

BenQ Bridge serves plain HTTP on the local network, and Android blocks that by default. Its
network security config can only allow cleartext per domain name, not per IP range, so
`android/app/src/main/res/xml/network_security_config.xml` allows it for the whole app. Everything
the app talks to is a PC you paired with by QR code. The token travels unencrypted on your
Wi-Fi, the same as with the web page.

## Not in this version

- Home-screen widgets and a Quick Settings tile
- Finding the PC automatically (you pair by QR code or address)
- More than one saved PC
- iOS (building for iPhone needs a Mac)
