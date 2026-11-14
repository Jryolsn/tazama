# AGENT.md

Context for AI coding agents working in this repository.

## What this is
Tazama: a Flutter launcher for Android TV / Google TV (GPL-3), forked from Arc Launcher.
Targets Chromecast with Google TV (HD "boreal" and 4K "sabrina"), armeabi-v7a.

## Layout
- `lib/` Flutter app. `lib/quick_panel.dart` is a second entry point (`quickPanelMain`).
- `android/app/src/main/java/` native side. The Java package is still `com.omeda.arc`
  (upstream); the application id is `com.jryolsn.tazama`. Do not rename the package without need.
- `camera-app/` Tazama Camera, the phone app for Phone camera (plain Gradle project, Java). Protocol: `camera-app/PROTOCOL.md`.
  TV side: `android/.../PhoneCameraActivity.java`.
- `tools/tv/` adb setup/restore scripts for TVs.
- `.github/workflows/build-apk.yml` builds, signs with `android/app/sideload.keystore` and publishes releases.

## Rules
- User-visible text in English. Commits, PRs and comments in English.
- No AI attribution in commits or PR descriptions.
- Keep upstream copyright headers and LICENSE; note changes in NOTICE.
- No local Flutter toolchain is assumed: CI is the build check.
- Key/accessibility features cannot be tested with `adb input keyevent`; test on a TV with the remote.

## Branches and releases
- `dev` -> pre-release `vX.Y.N-dev` (test TV), `main` -> release (main TV), both via Obtainium.
- Remote `upstream` = meddouribadis/arclauncher for cherry-picking fixes.

See STATUS.md for current state.
