# 0001. Build the mobile app with Flutter

Date: 2026-11-05
Status: Accepted

## Context

The web page that ships with BenQ Bridge works, but it cannot be installed as an app from a
phone: installable web apps need HTTPS, and BenQ Bridge serves plain HTTP on the local network.
The web page also feels like a settings dump, with 33 controls and no sense of which matter most.

The server already exposes everything an app needs over HTTP and a WebSocket, so the question
was only what to build the app with. The developer works on Windows and tests on an Android
emulator. The options were Flutter, native Kotlin with Jetpack Compose, and staying with the PWA
behind a self-signed HTTPS certificate.

## Decision

Build the app with **Flutter**, in the `app/` folder of this repository, and leave the server
unchanged.

## Consequences

- One Dart codebase with hot reload. The custom pieces (large brightness readout, hold-to-confirm
  reset, scene cards) are quick to build and polish.
- The Flutter and Android SDKs were already installed, so there is no new tooling to set up.
- Android is the only target for now. Flutter could also build for iOS, but that needs a Mac.
- Home-screen widgets and a Quick Settings tile are harder in Flutter than in Kotlin. If they are
  wanted later, a small native Kotlin piece can sit beside the Flutter app.
- Android refuses plain HTTP by default, so the app allows cleartext traffic for the whole app.
  The token therefore travels unencrypted on the local network, as it does with the web page.
  Moving the server to HTTPS, with the app pinning its certificate, would close that gap and is
  a separate decision.
- `app/` must stay out of the Windows release. The .NET project excludes it from its default
  items so `dotnet publish` cannot pick up Flutter files.

## Alternatives considered

- **Kotlin with Jetpack Compose.** Best fit for Android-only integrations and widgets, but slower
  to build the custom UI, and it only ever runs on Android.
- **PWA over HTTPS.** Would reuse the existing page, but needs a certificate the phone trusts,
  which is awkward on a home network, and still would not feel like a native app.
