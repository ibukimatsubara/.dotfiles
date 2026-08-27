---
name: flutter-release
description: Prepare, diagnose, or execute Flutter app builds and releases for iOS and Android, including flavors, signing, versioning, store metadata, screenshots, and release validation. Use for Flutter release, TestFlight, App Store, Play Console, ASO, or mobile build tasks.
---

# Flutter Release

Treat a release as a reproducible set of code, configuration, assets, metadata, and evidence.

## Discover the release contract

- Read repository instructions and inspect `pubspec.yaml`, FVM configuration, flavors, entrypoints, environment loading, CI, native iOS and Android settings, and existing release documentation.
- Use the repository's pinned Flutter version. Prefer `fvm flutter` and `fvm dart` when FVM is configured.
- Determine the target platform, flavor, environment, version, build number, distribution channel, signing setup, locale set, and rollout scope before building.
- Never print, commit, or replace signing keys, credentials, API secrets, provisioning data, or store tokens.

## Validate before distribution

- Confirm dependency resolution and generated code are current without performing unrelated bulk upgrades.
- Run the repository's formatting, analysis, tests, and relevant integration or golden tests. Build the exact requested flavor and release mode.
- Verify native identifiers, entitlements, permissions, minimum OS versions, deep links, notification configuration, privacy declarations, icons, launch assets, and localized app names where relevant.
- Exercise the critical user journey on the appropriate simulator, emulator, or device. Capture screenshots and logs for failures and release-critical visual checks.
- Check store metadata, release notes, screenshots, age or privacy declarations, and locale coverage against the actual build.

## Publish with an explicit boundary

- Distinguish a local build, upload, internal testing, staged rollout, review submission, and production release. They are separate actions.
- Do not upload, submit for review, change rollout percentage, or release to production unless the user explicitly authorizes that stage.
- After an authorized external action, verify the store or distribution state and report the version, build number, channel, and remaining manual gates.
