# Status

_Last updated: 2026-11-09_

## Now
- Split off from the Arc Launcher fork (Jryolsn/arclauncher) into this repository as **Tazama**.
- New application id `com.jryolsn.tazama`: TVs need a one-time install of Tazama and removal of the old
  `com.jryolsn.arc` (settings, PIN, home and accessibility setup must be redone).
- Icon and banner are a first placeholder (amber eye on dark).

## Next
- Nebula style (PR): night-blue/violet nebula default background, lavender accent, Nunito font,
  rounded cards with focus glow. All existing customization stays.
- Settings redesign (same PR): floating panel, pill rows, rounded icons, groups Home screen /
  Appearance / TV and system, Quick panel page removed (feature kept). Categories get size S-XL,
  live preview, per-category title and app-name switches; "Edit <category>" in the app menu.
- Home layout setting (Settings > Home layout) with thumbnails: Rows (default), Orbit (big centered
  clock, floating cards), Aurora (clock column left, sections right).
- Watch next: sharper images and more card sizes.
- Migration on the test TV, then the main TV.
- Point Obtainium at Jryolsn/tazama.

## Known
- Feature details and TV setup: README and `tools/tv/`.
