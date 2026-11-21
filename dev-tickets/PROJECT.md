# Project facts — Tazama

Read this before `README.md`'s generic method; these are the local details.

## Repo

- This workspace lives inside the Tazama repository at `dev-tickets/`. There is
  no second ticket folder; never create one.
- The workspace is committed with the repo (not gitignored), so plans are part
  of the project history and are reviewed like any other file. Changes to
  `*.md` files do not trigger an APK build.
- Stack: Flutter (version in `../.fvmrc`) with a Java Android side for the TV
  launcher, and a plain Gradle/Java phone app (Tazama Link) in `../camera-app/`.
- Repo rules that apply to all ticket work live in `../AGENT.md` (layout,
  commands, CI, release flow, rules). Read it before touching code.
  `../STATUS.md` describes the current state of the project; `dev-tickets/`
  holds plans for work being done. Keep the two separate: when a ticket lands,
  move the outcome into `STATUS.md`.
- Ideas and things to fix live in `../BACKLOG.md`, the single backlog. A ticket
  is created from a backlog item when it needs a plan; the backlog line then
  points to the ticket folder. Findings that are not worth a ticket go back to
  the backlog.
- Work alternates between Claude app sessions and local work (IDE, Claude Code,
  by hand), so the plan must be enough to continue from either.

## Language

- Plans, decisions and findings are written in **Swedish**, since that is the
  working language for this project.
- Everything else that lands in the repo stays in English: code, comments,
  commit messages, PR texts, and the structural files in this folder
  (`README.md`, `CLAUDE.md`, this file, `INDEX.md`).
- Ticket folder names are English kebab-case.

## Naming

- Ticket folder: kebab-case after the work, not the branch
  (`media-panel-phone-camera`, not `feat/panel-2`).
- Original ticket text, when there is any (for example an item from
  `../BACKLOG.md`), goes in `original-tickets/`.
- Mockups and screenshots go in `mockups/` with descriptive names
  (`desktop-weather-widget.png`).

## Verification

- `flutter analyze` and `flutter test` (see `../AGENT.md` for FVM) when a local
  toolchain is available; otherwise the green "Build APK" check on the PR is the
  build check.
- Behaviour is verified on the **test TV** with the remote, after installing
  the `dev` pre-release through Obtainium. Never on the main TV first.
- Remote keys and accessibility features cannot be tested with
  `adb input keyevent`. "How to verify" lists the exact keys to press and what
  should happen.
- Tazama Link changes are verified on a phone together with the TV.
