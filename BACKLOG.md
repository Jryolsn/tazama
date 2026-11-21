# Backlog

The single list of ideas and things to fix for Tazama and Tazama Link. Used the same way in
Claude app sessions and in local work (IDE, Claude Code, by hand). Add a line, edit it, tick it.
Items may be written in Swedish.

Format: `- [ ] Short title (area) – one-line description`. Areas: home, media panel, settings,
HA, Link (phone app), TV, build.

How an item moves on:

1. It sits here until someone picks it up.
2. Small fix: just do it in a PR, then tick it and move it to **Done** with the PR number.
3. Bigger work: create a ticket folder in `dev-tickets/` (see `dev-tickets/README.md`), copy the
   item text into the ticket's `original-tickets/`, and replace the line here with
   `→ dev-tickets/<folder>`. The ticket's `PLAN.md` is the source of truth from then on.
4. Dropped ideas go to **Dropped** with a short reason, so they are not proposed again.

## To fix

- [ ] 

## Ideas

- [ ] Casta en enskild app från telefonen (Link) – skärmcasting finns (PR #21); idén är att kunna välja att bara dela en app.
- [ ] Fler widgettyper (home) → dev-tickets/desktop-widget-types
- [ ] Telefonkameran som kort i mediapanelen (media panel) → dev-tickets/media-panel-phone-camera

## Done

- [x] Starta och stoppa streamen från telefonappen (Link) – PR #21
- [x] Casta det man ser på telefonen till TV:n (Link) – PR #21; appen bytte namn till Tazama Link i PR #22

## Dropped

_(none yet)_
