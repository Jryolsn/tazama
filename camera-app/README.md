# Tazama Camera (phone app)

Streams the phone's camera to Tazama's **Phone camera** view on the TV, over the local Wi-Fi, with low latency
(hardware H.264, no buffering). The phone waits in the background with the camera off; the TV starts it.

- Install: Obtainium, `https://github.com/Jryolsn/tazama`, include pre-releases, APK filter `camera`.
- Pair: on the TV open Phone camera, in the app tap **Scan TV code** (or **Enter code instead**).
- After a phone restart, open the app once (Android only lets a camera service start from a visible app).
- Start/stop: in the app (or the notification) **Stop streaming** pauses the video while the TV stays connected.
- Cast: **Cast phone screen** shows the screen in the same TV view. On Android 14+ you can share a single app.
  Audio is not sent. When casting ends the camera stays off until you tap **Start streaming**.
- Remote on the TV: Left/Right switch camera, Up/Down zoom, OK menu (light, brightness, quality, frame rate, rotation).

Built by CI (`.github/workflows/build-apk.yml`) with Gradle 8.13; protocol in [PROTOCOL.md](PROTOCOL.md).
