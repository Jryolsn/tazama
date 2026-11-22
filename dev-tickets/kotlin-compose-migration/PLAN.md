# Kotlin + Compose TV Migration

> Skapad: 2026-11-22
> Status: **PLANNING**
> Branch/PR: —
> Källa: diskussion (muntligt)
> Relaterade planer: —

## ▶ BÖRJA HÄR

**Läs i den här ordningen:**

1. `../PROJECT.md`, `../../AGENT.md` och `../../STATUS.md`
2. Denna plan
3. Referenskod: `lib/main.dart`, `lib/flauncher_app.dart`, `lib/desktop/`, `lib/media_panel/`, `android/app/src/main/java/...`

**Nuläge:** Idéfas. Flutter-appen (Tazama) fungerar på Chromecast HD/4K (armeabi-v7a). Tazama Link (`camera-app/`) är separat Java/Gradle-app.

**Nästa steg:** Besluta om migrationen ska påbörjas nu eller parkeras. Om påbörjas: definiera första skärm att byta ut (strangler-fig) och skapa PoC-branch.

## Omfattning

**Ingår:**

- Total migration av TV-appen (`lib/`, `android/app/...`) från Flutter + Java bridges → Kotlin + Compose TV
- Native launcher-logik först: `HomeActivity`, accessibility service, package query, method channels
- UI-skärm för skärm: desktop (taskbar + paged widgets), media panel, quick panel, settings
- Drift-databas → Room (eller behåll via FFI)
- Bevara funktionsparitet: D-pad focus, ARM32, sideload-keystore, Obtainium-uppdatering

**Ingår inte:**

- Tazama Link (`camera-app/`) – kan stanna Java eller bytas till KMP separat
- Upstream-synk (meddouribadis/arclauncher) – hanteras separat

## Beslut

### 2026-11-22 — Målformulering

**Val:** Målet är Kotlin + Compose TV för TV-appen.
**Varför:** Compose TV är förstaklassigt stöd för Android TV (D-pad/focus, leanback-komponenter), mindre APK, ingen JNI-bridge för system-API:er, moderna kotlinx-bibliotek. Flutter var pragmatiskt valet för en fork; greenfield väljer Compose TV.
**Alternativ som valdes bort:** React Native (ej lämplig för launcher), Flutter kvar (större APK, bridge-smärta), Kotlin + Views (äldre paradigm).

> **NOTE:** Alternativ går att diskutera vidare. Detta är en riktning, inte ett låst beslut.

## Kartläggning

| Fil | Roll |
| --- | --- |
| `lib/main.dart` / `lib/flauncher_app.dart` | App entry, flavor-setup, root widget |
| `lib/desktop/` | Hemskärm: taskbar, paged widget desktop (`desktop_pages` JSON) |
| `lib/media_panel/` | Media panel (håll Home): kameror, HA-kort |
| `lib/quick_panel.dart` | Quick panel / media panel / notices (alltid laddad engine) |
| `lib/home_assistant/` | HA-anslutning, kontroller, notiser |
| `lib/widgets/settings/` | Inställningssidor |
| `lib/database.dart` | Drift DB (scheman i `drift_schemas/`) |
| `android/app/src/main/java/.../ltvL/` | Native: method channel, accessibility service, `PhoneCameraActivity`, `LinkWakeService` |
| `.github/workflows/build-apk.yml` | CI: build, sign, release (måste bytas till Gradle/Kotlin) |

Method channels som berörs: `launcher`, `accessibility`, `camera`, `wake`, `homeassistant`, `settings`.

## Plan

- [ ] 1. **PoC-branch**: `HomeActivity` + minimal Compose TV-skärm (visa "Hello Compose TV" på TV), bygga APK, verifiera ARM32
- [ ] 2. **Native launcher-kärna**: `HomeActivity`, `HomeReceiver`, accessibility service, package-query i Kotlin (inga bridges)
- [ ] 3. **Strangler-fig – Desktop**: Taskbar + paged widget grid i Compose TV (först statisk, sedan Drift → Room-migration)
- [ ] 4. **Strangler-fig – Media Panel**: Kameror + HA-kort
- [ ] 5. **Strangler-fig – Quick Panel / Notices**
- [ ] 6. **Strangler-fig – Settings**
- [ ] 7. **Databas**: Drift → Room (migrera scheman i `drift_schemas/`)
- [ ] 8. **CI/CD**: `.github/workflows/build-apk.yml` → Gradle/Kotlin build, samma flavor/keystore/Obtainium-flöde
- [ ] 9. **Test på båda TV:er** (test + main) med fjärrkontroll – D-pad focus, koldstart, uppdatering över Obtainium
- [ ] 10. **Feature parity checklist** + släpp som `v2.0.0` (major bump)

## Så verifierar vi

- [ ] `./gradlew assembleRelease` (eller `fvm flutter build apk` under övergången) – grön build
- [ ] Installera dev-releasen på test-TV:n via Obtainium
- [ ] D-pad navigation: Up/Down/Left/Right/Enter/Back/Heap på alla skärmar
- [ ] Koldstart < 2s på Chromecast HD (boreal)
- [ ] Uppdatering över befintlig APK (samma keystore) fungerar

## Öppna frågor

- **Migrationstempo** – en skärm i taget (rekommenderas) eller big-bang? — väntar på beslut — blockerar steg 3+
- **Drift → Room strategi** – migrera data live eller fresh install? — väntar på beslut — blockerar steg 7
- **camera-app/** – byta till KMP-modul nu eller senare? — väntar på beslut — blockerar inget i TV-appen
- **Compose TV version** – stabil vs. RC vid starttidpunkt? — väntar på beslut — blockerar steg 1

## Upptäckter

- Ingen än.