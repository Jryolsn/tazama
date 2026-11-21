# Telefonkamera i mediapanelen

> Skapad: 2026-11-21
> Status: **PLANNING**
> Branch/PR: —
> Källa: `STATUS.md` (Media panel, "Next: move Phone camera here")
> Relaterade planer: `../desktop-widget-types/PLAN.md` (kamerawidgeten använder mediapanelens kort)

## ▶ BÖRJA HÄR

**Läs i den här ordningen:**

1. `../PROJECT.md`, `../../AGENT.md` och `../../STATUS.md`
2. `../../camera-app/PROTOCOL.md` (handskakning, meddelanden, väckning)
3. `lib/media_panel/media_panel_service.dart` och `lib/media_panel/stream_view.dart` (hur kort lagras och visas)
4. `android/app/src/main/java/com/leanbitlab/ltvL/PhoneCameraActivity.java` (dagens helskärmsvy)

**Nuläge:** Ingen kod skriven. Telefonkameran visas i dag i en egen Android-aktivitet
(`PhoneCameraActivity`) som öppnas från inställningarna eller när telefonen väcker TV:n.

**Nästa steg:** Kartlägg hur `PhoneCameraActivity` avkodar H.264-strömmen och om den kan
återanvändas som en Flutter-vy (platform view eller texture) i ett mediapanelkort. Skriv
resultatet under Kartläggning och föreslå ett vägval under Beslut innan någon kod skrivs.

## Omfattning

**Ingår:**

- En ny korttyp "Telefonkamera" i mediapanelen (lägg till, byt namn, flytta, ta bort som andra kort).
- Fjärrkontrollens kamerastyrning (zoom, ljus, kvalitet) när kortet har fokus.

**Ingår inte:**

- Ändringar i Tazama Link-appens protokoll, om det inte visar sig nödvändigt (då: Upptäckter).
- Skärmdelning från telefonen som eget kort (egen ticket om det behövs).

## Beslut

_(inga än)_

## Kartläggning

| Fil | Roll |
| --- | --- |
| `lib/media_panel/media_panel_service.dart` | Kortlistan och dess inställningar |
| `lib/media_panel/stream_view.dart` | Visning av RTSP-/HA-strömmar i kort |
| `lib/widgets/settings/tazama_camera_page.dart` | Inställningar för telefonkamera och parkoppling |
| `lib/flauncher_channel.dart` | Method channel mot Android-sidan |
| `android/.../PhoneCameraActivity.java` | Ansluter till telefonen, avkodar och visar strömmen |
| `android/.../LinkWakeService.java` | Tar emot väckning från telefonen och öppnar kameran |

## Plan

- [ ] 1. Kartlägg avkodningen i `PhoneCameraActivity` och välj väg (platform view, texture eller kvar som aktivitet som öppnas från kortet)
- [ ] 2. Ny korttyp i mediapanelen
- [ ] 3. Fjärrkontrollstyrning när kortet har fokus
- [ ] 4. Bestäm vad väckning från telefonen ska öppna (panelen eller helskärm)
- [ ] 5. Uppdatera `STATUS.md`

## Så verifierar vi

- [ ] `flutter analyze` och `flutter test` (eller grön "Build APK" på PR:en)
- [ ] Installera dev-releasen på test-TV:n via Obtainium
- [ ] Håll in Home, lägg till kortet Telefonkamera, starta strömmen i Tazama Link och se bilden i panelen
- [ ] Zooma och tänd lampan med fjärrkontrollen när kortet har fokus

## Öppna frågor

- Ska helskärmsvyn finnas kvar vid sidan av kortet? — väntar på Jerry — blockerar steg 4

## Upptäckter

_(inga än)_
