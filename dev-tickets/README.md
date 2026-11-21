# Ticket Workspace

This folder is a planning workspace for AI-assisted development work. Each
subfolder is one ticket (or epic) and holds everything needed to resume work
on it in a fresh AI session: the plan, the decisions made so far, design
references, and scratch files.

The core idea: **an AI model with no prior context must be able to open a
ticket's `PLAN.md`, read it top to bottom, and continue working exactly where
the last session stopped.** The chat transcript disappears between sessions;
the plan does not. Everything that matters goes in the plan.

This file describes the generic method and is meant to be copied unchanged
between projects. Project-specific facts (where the main repo lives, how this
folder is versioned, what language plans are written in) live in `PROJECT.md`
next to this file. If a `PROJECT.md` exists, read it before doing anything.

## Instructions for AI models

### Starting a session

1. Read `PROJECT.md` if it exists.
2. Read the relevant ticket's `PLAN.md` top to bottom. Do not skim.
3. Find the resume section: a heading starting with `## ▶`. It contains a
   numbered bootstrap order (files to read, mockups to look at, reference
   code to inspect). Work through it before writing any code.
4. If the ticket has a `GUIDE.md`, or its plan points to one in another
   ticket's folder, read that too: it describes the working method shared by
   a whole family of similar tickets.

### During a session

- **Log decisions immediately**, in `PLAN.md`, with the date and the
  reasoning. "What we chose" without "why" is not a decision log.
- **Absolute dates only** (2026-07-22), never relative ones ("yesterday",
  "last week"). The next session does not know when this one ran.
- **Check off plan steps** as they are completed.
- **No silent scope changes.** If the work uncovers something outside the
  plan, write it down under a clearly marked heading (finding, follow-up,
  sub-ticket candidate) and ask the user before acting on it.
- **Ask before creating or deleting ticket folders.** Breaking a finding out
  into its own ticket is the user's call.

### Ending a session

Update `PLAN.md` so that the next session can start cold:

- Update the `## ▶` resume section: current status, what was just done, the
  exact next step, and the bootstrap order if it changed.
- Make sure the plan is still **self-contained**: all decisions, key file
  paths, and findings must be readable from the plan alone, without the chat
  transcript.
- Update the ticket's line in `INDEX.md` if its status changed.

## Folder structure

One folder per ticket or epic, named in kebab-case after the ticket, not
after the branch:

```
tickets/
  README.md            <- this file (generic, portable)
  CLAUDE.md            <- short reminder loaded automatically by Claude Code
  PROJECT.md           <- project-specific facts
  INDEX.md             <- one line per ticket: name, status, one-line hook
  _templates/PLAN.md   <- copy this to start a new ticket
  archive/             <- closed tickets, moved here when fully done
  some-ticket/
    PLAN.md            <- required: status, decisions, plan, resume pointer
    GUIDE.md           <- optional: reusable method for a family of tickets
    mockups/           <- optional: design references, screenshots
    original-tickets/  <- optional: ticket text as received from the tracker
    *.sql, *.mjs, ...  <- optional: scratch/work files tied to the ticket
```

- The folder name is whatever the project uses (`tickets/`, `.tickets/`);
  check `PROJECT.md`. Never create a second one next to it.
- `PLAN.md` is the only required file. Everything else exists when needed.
- `GUIDE.md` is written once per *kind* of work (for example "redesign a view
  from a mockup") and other tickets' plans link to it instead of copying it.
- Mockup images get descriptive kebab-case names (`overview-table.png`, not
  `Screenshot 2026-07-22.png`), and the plan notes which view each one shows.
- The exact name of the original-ticket folder may vary per project; check
  `PROJECT.md` or existing folders.

## INDEX.md

`INDEX.md` is the map of the workspace: one line per ticket, so any tool or
model can find the right folder without prior context.

```markdown
# Ticket index

## Active
- some-ticket — IN PROGRESS — one-line hook about where it stands

## Parked
- other-ticket — PARKED — waiting on <person/decision>

## Done (not yet archived)
- done-ticket — DONE (PR #123) — cleanup steps remaining
```

Rules:

- Each ticket's `PLAN.md` is the source of truth; `INDEX.md` is only a map.
  On any disagreement, trust the plan and fix the index.
- Update the ticket's line whenever its status changes, and always as part
  of ending a session.

## PLAN.md anatomy

Start a new ticket by copying `_templates/PLAN.md` into the ticket folder
and filling it in. The template carries the headings below; its language
follows `PROJECT.md`.

| Section | What it holds |
| --- | --- |
| Header blockquote | Created date, bold status, branch/PR, source, related plans |
| `## ▶ RESUME HERE` | Bootstrap order, current state, the exact next step |
| Scope | What the ticket covers, and what it explicitly does not |
| Decisions | One dated entry per decision, with the reasoning |
| Mapping | Key files, routes and data flow, with paths |
| Plan | Numbered checklist, ticked as work lands |
| How to verify | URLs, test data, views and roles to check |
| Open questions | What is unanswered, who it waits on, what it blocks |
| Findings | Out-of-scope discoveries needing their own decision or ticket |

Conventions that make this work:

- The header blockquote always carries the created date and a bold status.
- The `## ▶` heading is the universal resume anchor. The heading text after
  `▶` may be in any language; the `▶` symbol is what to search for.
- Statuses are free-form but keep to a small vocabulary, in bold:
  **PLANNING**, **READY TO BUILD**, **IN PROGRESS**, **PARKED** (with the
  reason and date), **DONE** (with PR/commit reference).

## Ticket lifecycle

- **Created** when planning starts, usually before any code is written.
  Planning and mapping happen in the plan file from the start.
- **Broken out**: when a finding inside one ticket grows into its own piece
  of work, it gets its own folder, and both plans link to each other. The
  new plan states what it was broken out of and why.
- **Parked**: work that is deliberately on hold keeps its folder; the status
  line says why it is parked and what unblocks it.
- **Done**: the plan gets a final status with the PR/commit reference. When
  nothing remains (no follow-ups, no cleanup), the folder moves to
  `archive/` — ask the user before moving it. Tickets with remaining
  cleanup stay in the root, listed under "Done (not yet archived)" in
  `INDEX.md`.
