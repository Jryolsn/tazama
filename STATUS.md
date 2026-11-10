# Status

_Last updated: 2026-11-09_

## Now
- Split off from the Arc Launcher fork (Jryolsn/arclauncher) into this repository as **Tazama**.
- New application id `com.jryolsn.tazama`: TVs need a one-time install of Tazama and removal of the old
  `com.jryolsn.arc` (settings, PIN, home and accessibility setup must be redone).
- Icon and banner are a first placeholder (amber eye on dark).
- TV tuning pass at 960x540 dp (the real TV canvas): 48 dp side margins, rows scroll to the screen edge,
  focus glow no longer clipped, Orbit/Aurora clocks shrink to fit, Watch Next sizes S/M/L = 0.6/0.78/1.0.

## Next
- Nebula style (PR): night-blue/violet nebula default background, lavender accent, Nunito font,
  rounded cards with focus glow. All existing customization stays.
- Settings redesign (same PR): floating panel, pill rows, rounded icons, groups Home screen /
  Appearance / TV and system, Quick panel page removed (feature kept). Categories get size S-XL,
  live preview, per-category title and app-name switches; "Edit <category>" in the app menu.
- Home layout setting (Settings > Home layout) with thumbnails: Rows (default), Orbit (big centered
  clock, floating cards), Aurora (clock column left, sections right).
- Watch next: sharper images and more card sizes.
- Home Assistant module (lib/home_assistant/): full-screen settings (Connection, Controls grouped by
  area with search/type filter, Arrange, Dashboard, Panel), opened from Settings or the HA panel.
  Camera tiles stream live (HLS via video_player) once focused; full-size view has sound if the stream carries AAC.
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
