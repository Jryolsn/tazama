# Fler widgettyper på skrivbordet

> Skapad: 2026-11-21
> Status: **PLANNING**
> Branch/PR: —
> Källa: `STATUS.md` (One home layout, "Ideas for later")
> Relaterade planer: `../media-panel-phone-camera/PLAN.md`

## ▶ BÖRJA HÄR

**Läs i den här ordningen:**

1. `../PROJECT.md`, `../../AGENT.md` och `../../STATUS.md` (avsnittet om skrivbordet)
2. `lib/desktop/desktop_service.dart` (`DesktopWidgetType`, lagring i `desktop_pages`)
3. `lib/desktop/desktop_widgets.dart` (hur befintliga widgetar ritas) och `lib/desktop/desktop_menus.dart` (Lägg till widget)

**Nuläge:** Ingen kod skriven. Skrivbordet har i dag widgetarna klocka, kamera,
Home Assistant-entitet, appgenväg och Fortsätt titta (senaste objektet).

**Nästa steg:** Fråga Jerry vilken widgettyp som ska komma först, och logga valet under Beslut.

## Omfattning

**Ingår (kandidater, en i taget):**

- Spelas nu (media som spelas på TV:n)
- Väder
- Home Assistant-grupper (flera entiteter i en widget)
- Fortsätt titta med flera objekt

**Ingår inte:**

- Ändringar i rutnätet (4x2 per sida) eller storlekarna.

## Beslut

_(inga än)_

## Kartläggning

| Fil | Roll |
| --- | --- |
| `lib/desktop/desktop_service.dart` | Widgettyper, sidor och JSON-lagring |
| `lib/desktop/desktop_widgets.dart` | Ritar varje widgettyp |
| `lib/desktop/desktop_menus.dart` | Menyn som visas när OK hålls in |
| `test/desktop/` | Tester för skrivbordet |

## Plan

- [ ] 1. Välj första widgettypen
- [ ] 2. Kartlägg datakällan för den (till exempel media session eller HA-websocket)
- [ ] 3. Lägg till typen i `DesktopWidgetType`, rita den och lägg till den i menyn
- [ ] 4. Tester i `test/desktop/`
- [ ] 5. Uppdatera `STATUS.md`

## Så verifierar vi

- [ ] `flutter analyze` och `flutter test` (eller grön "Build APK" på PR:en)
- [ ] Installera dev-releasen på test-TV:n via Obtainium
- [ ] Håll in OK på skrivbordet, Lägg till widget, välj den nya typen i alla storlekar den stöder

## Öppna frågor

- Vilken widgettyp först? — väntar på Jerry — blockerar steg 1
- Väder: vilken källa (Home Assistant eller en öppen väder-API)? — väntar på Jerry

## Upptäckter

_(inga än)_
