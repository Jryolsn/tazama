# Status

_Last updated: 2026-11-21_

Project state at a glance. Work in progress is planned in `dev-tickets/` (map: `dev-tickets/INDEX.md`);
ideas and things to fix: `BACKLOG.md`; how to work in this repo: `AGENT.md`.

## Now
- One home layout (2026-11-21): the Rows/Orbit/Aurora layouts, the Watch Next row and the dock are gone.
  Bottom: taskbar with one category row at a time (button on the left picks the category, saved as
  `taskbar_category_id`). Above: desktop with pages of widgets (`lib/desktop/`, stored as JSON in
  `desktop_pages`), 4x2 grid per page, sizes 1x1, 2x1, 2x2, 4x1, 4x2. Widgets: clock, camera (media panel camera
  cards), Home Assistant entity (from the chosen panel entities), app shortcut, Continue watching (latest item).
  Hold OK on a widget: move, size, add widget, add page, remove widget/page. Left/Right at a page edge turns the page.
  Removed settings: home layout, Watch Next show/card size, hide status bar in grid, category row/grid choice.
  Ideas for later: more widget types (Now playing, weather, HA groups), Watch Next as a multi-item widget.
- Cleanup of unused Arc/FLauncher leftovers (2026-11-20): removed the duplicate `me.efesser.flauncher` Java
  sources, upstream screenshots and store listings, Spanish/Turkish, Back-on-home actions, Watch Next
  "Immersive mode" and "Hide programs without image", and the old look options (accent color, focus border,
  highlight animation, blur and dock toggles, date/time format, Wi-Fi usage). These are now fixed defaults.
  Background and screensaver settings share one page; "Screen and sleep" is now just "Brightness".
  Kept for later decisions: Unsplash/Reddit wallpapers, self-updater (compiled out).
- Media panel (hold Home) replaces the HA-only panel: user-added cards (RTSP camera without HA, Home Assistant),
  order/rename/remove, side and width (Settings > Media panel, `lib/media_panel/`). Existing HA users get an HA card
  automatically. Next: move Phone camera here, "Now playing" card, more card types.
- Phone camera: Tazama Link phone app (camera-app/) streams the phone camera to the TV over Wi-Fi
  (H.264, low latency), paired by QR code; remote controls camera, zoom, light, quality. Replaces the adb prototype.
  Not yet tested on the TV.
- Split off from the Arc Launcher fork (Jryolsn/arclauncher) into this repository as **Tazama**.
- New application id `com.jryolsn.tazama`: TVs need a one-time install of Tazama and removal of the old
  `com.jryolsn.arc` (settings, PIN, home and accessibility setup must be redone).
- Icon and banner are a first placeholder (amber eye on dark).
- TV tuning pass at 960x540 dp (the real TV canvas): 48 dp side margins, rows scroll to the screen edge,
  focus glow no longer clipped, Orbit/Aurora clocks shrink to fit, Watch Next sizes S/M/L = 0.6/0.78/1.0.

## Next
- Clean style (2026-11-16, replaces the earlier space look): graphite default background, white accent,
  Inter font, 10 dp card corners, compact settings rows, subtle focus glow. All customization stays.
- TV notices: compact card with a Material icon per sensor type (no emoji); automations can pass `icon`.
- Settings redesign (same PR): floating panel, pill rows, rounded icons, groups Home screen /
  Appearance / TV and system, Quick panel page removed (feature kept). Categories get size S-XL,
  live preview, per-category title and app-name switches; "Edit <category>" in the app menu.
- Watch next: sharper images and more card sizes.
- Home Assistant module (lib/home_assistant/): full-screen settings (Connection, Controls grouped by
  area with search/type filter, Arrange, Dashboard, Panel), opened from Settings or the HA panel.
  Camera tiles stream live as soon as the panel opens (setting: or only the focused one). Per camera an optional
  direct RTSP address (encrypted, Settings > Home Assistant > Cameras) is played first via video_player (ExoPlayer RTSP,
  low delay, G.711/AAC sound); HA's HLS stream is the fallback.
  Notices: Settings > Home Assistant > Notices. The quick panel engine (always loaded) keeps a websocket to HA and
  shows an emoji+text overlay (accessibility service) when chosen binary sensors turn on, or on a `tazama_notify`
  event fired from an HA automation (message, title, emoji, seconds).
  Media players show cover, title, progress, volume (Left/Right).
  Plan for next phases: /mnt project file tazama/home-assistant-plan.md (PR B camera+media, PR C notices).
- Home Assistant: URL + long-lived token in encrypted storage.
  Hold Home = HA panel over any app (chosen entities: toggle, scenes, sensors, camera snapshots,
  Left/Right dims lights, optional own dashboard in a WebView signed in with the token).
  Hold Back = quick panel (short Back unchanged). Customizable: order, names, side, width,
  hold Home opens dashboard, camera refresh. Not yet tested on a TV.
- Migration on the test TV, then the main TV.
- Point Obtainium at Jryolsn/tazama.

## Known
- Feature details and TV setup: README and `tools/tv/`.
