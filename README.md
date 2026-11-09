# Tazama

<img src="android/app/src/main/res/drawable-xhdpi/banner.png" alt="Tazama" width="320">

**Tazama** (Swahili for "look, watch") is an open-source home screen for Android TV and Google TV, tuned for the Chromecast with Google TV.

It is based on [Arc Launcher](https://github.com/meddouribadis/arclauncher) and keeps its grid layout, wallpapers and remote-friendly navigation, and adds:

- **App lock** with PIN or remote pattern, also when an app is opened by casting.
- **Dim screen** on top of every app, on a schedule or on demand.
- **Quick panel**: hold Back (or the YouTube button) for brightness and quick settings over whatever is playing.
- **Home Assistant**: connect your server (Settings > Smart home), then hold Home for lights, scenes, sensors and cameras over whatever is playing.
- **VPN guard**: chosen apps only run while a VPN is up.
- **Replace current launcher**: Home opens Tazama without disabling the stock launcher.

## Install

Every push to `dev` publishes a pre-release and every push to `main` a release on [GitHub Releases](https://github.com/Jryolsn/tazama/releases). The easiest way to stay updated on a TV is [Obtainium](https://github.com/ImranR98/Obtainium) pointed at this repository.

Several features need the **Tazama** accessibility service and a few adb grants. `tools/tv/setup-tv.sh` sets up a new TV.

## Build

```sh
flutter pub get
flutter build apk --release --flavor github
```

CI (`.github/workflows/build-apk.yml`) builds and signs with the sideload key, so every release installs over the previous one.

## License and credits

Tazama is free software under the [GNU General Public License v3](LICENSE). It is a modified version of the projects below; the copyright notices in the source files belong to their authors. See [NOTICE](NOTICE) for what was changed.

- [Arc Launcher](https://github.com/meddouribadis/arclauncher) by Meddouri Badis
- [LTvLauncher](https://github.com/LeanBitLab/LtvLauncher) by LeanBitLab
- [FLauncher (fork)](https://github.com/osrosal/flauncher) by Oscar Rojas
- [FLauncher](https://gitlab.com/flauncher/flauncher) by Étienne Fesser
