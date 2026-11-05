# 0002. Build and sign Android releases on GitHub Actions

Date: 2026-11-05
Status: Accepted

## Context

The first APKs were built on the developer's PC and signed with the local debug key. That ties
releases to one machine, and a debug key cannot be relied on: if it changes, a new APK will not
install over the old one. The developer asked for releases to come from GitHub, triggered by a
version tag, with the APK attached to the release.

The repository already has a Windows release, `v0.1.0`, and the README links to "the latest
release" for the Windows download.

## Decision

- A workflow, `.github/workflows/android-release.yml`, runs when a tag `app-vX.Y.Z` is pushed.
  It checks the tag against `version:` in `app/pubspec.yaml`, runs the analyzer and the tests,
  builds the release APK, and publishes it with its SHA-256.
- Android tags use the `app-v` prefix so they never collide with the Windows `vX.Y.Z` tags, and
  Android releases are not marked "latest", so the Windows download link keeps working.
- The APK is signed with a dedicated upload key. The keystore and its passwords are stored as
  repository secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`). The workflow refuses to publish a tagged build without them, and fails
  if the APK turns out to be signed with a debug key.
- The app is called Monitor Remote, with the application id `dev.samirdahal.monitorremote`, since
  it works with any DDC/CI monitor. The PC side keeps the name BenQ Bridge.

## Consequences

- Anyone with push access can cut a release by tagging; nothing depends on one PC.
- The signing key must be backed up outside GitHub. Secrets cannot be read back, and losing the
  key means users have to uninstall before installing the next release.
- A run started by hand from the Actions tab builds and tests but publishes nothing, which is a
  cheap way to check the pipeline.
- Windows releases are still built with `scripts/release.ps1`. Moving them to Actions as well
  would be a separate change.
