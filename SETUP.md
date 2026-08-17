# Punkt — Intention Tracker (iOS)

Eine native iOS-App, die hilft, erklärte Intention und tatsächliches
Verhalten in Deckung zu bringen — durch regelmäßiges, freundliches
Bewusstmachen statt Blocken, Belohnen oder Gamification. Siehe die
ursprüngliche Spezifikation für den vollständigen Produktkontext.

## Getroffene Entscheidungen

Die fünf offenen Punkte aus der Spezifikation wurden wie folgt entschieden:

1. **App-Name:** *Punkt* — der Arbeitstitel folgt der zentralen visuellen
   Metapher (ein einzelner, atmender Kreis).
2. **Check-in-Intervall:** `Wachheit` = 6–12 min, `Vertiefung` = 20–40 min
   (`SessionMode.baseIntervalRange`), mit adaptiver Dämpfung/Verdichtung
   über `CheckInIntervalPolicy`.
3. **Hauptuhr während des Exkurses:** läuft weiter (wie in der Spec
   vorgeschlagen) — `Session.totalDuration` schließt Exkurszeit ein,
   `PatternAnalyzer.coherenceRatio` zieht sie wieder ab. Genau diese
   Differenz ist der Erkenntniswert.
4. **Aktivität bei „Nein“ erfragen:** optional und mit einem Tap
   überspringbar (`CheckInPromptView`), nie Pflichtfeld.
5. **Ausbleibende Rückkehr nach Exkurs:** wird nur protokolliert
   (`Detour.returned = false`), nie nachträglich erinnert oder bewertet.

## Projektstruktur

```
Package.swift              — SwiftPM: IntentionCore, eigenständig testbar
                               via `swift test` (unabhängig vom Xcode-Projekt)
Sources/IntentionCore/      — Models (SwiftData), SessionEngine, Scheduling,
                               SharedState (App Group), Activity, Analytics
Tests/IntentionCoreTests/   — Unit-Tests für SessionEngine, Interval-Policy,
                               PatternAnalyzer (reines XCTest, kein UI)
App/Punkt/                  — SwiftUI-App (App-Target)
Widget/PunktWidget/         — Widget-Extension: Home-Screen-Widget + Live Activity
project.yml                 — XcodeGen-Spezifikation: kompiliert Sources/IntentionCore
                               als eigenes Framework-Target (statisch gelinkt),
                               plus App-Target, Widget-Extension und
                               IntentionCoreTests
```

`IntentionCore` existiert damit über zwei unabhängige Wege: als SwiftPM-Package
(`Package.swift`, für schnelles `swift test` ohne Xcode) und als
Framework-Target innerhalb des generierten Xcode-Projekts (`project.yml`,
kompiliert aus denselben Quellen in `Sources/IntentionCore`). Xcode bindet
das Package selbst nicht ein — das vermeidet die SourceKit-Indexierungsprobleme,
die lokale SwiftPM-Pakete in Xcode gelegentlich verursachen. Das
Framework-Target ist bewusst **statisch** (`MACH_O_TYPE: staticlib`), weil es
sowohl von `Punkt` als auch von `PunktWidgetExtension` gelinkt wird — als
dynamisches Framework müssten beide es einbetten, was zu "multiple commands
produce ...framework"-Fehlern führt.

`SessionEngine` (Sources/IntentionCore/Engine/SessionEngine.swift) kennt
weder SwiftUI noch Notifications noch Haptik — es ist die testbare,
UI-unabhängige Zustandsmaschine aus §4 der Spezifikation, exakt
nachgebildet: LEERLAUF → AKTIV → CHECK_IN/KORREKTUR → EXKURS →
RÜCKKEHR_PROMPT. `SessionStore` (App/Punkt/SessionStore.swift) ist die
einzige Stelle, die den Kern mit SwiftData, `UNUserNotificationCenter`,
Haptik, der App-Group und ActivityKit verbindet.

## Setup

### Voraussetzungen

- Xcode 15+ auf macOS
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Ein Apple Developer Team (für App Groups, Live Activities, Time
  Sensitive Notifications, Siri/App Intents — alle vier benötigen ein
  echtes Gerät bzw. ein Team, nicht nur den Simulator für Haptik/Diktat)

### Projekt generieren

```bash
xcodegen generate
open Punkt.xcodeproj
```

`project.yml` erzeugt vier Targets: `IntentionCore` (Framework, aus
`Sources/IntentionCore`), `IntentionCoreTests` (Unit-Tests, im Xcode
Test-Navigator sichtbar), `Punkt` (App) und `PunktWidgetExtension`.

### Vor dem ersten Build in Xcode anpassen

1. **Team & Bundle-IDs:** `project.yml` → `DEVELOPMENT_TEAM` setzen (oder in
   Xcode je Target unter "Signing & Capabilities"), Bundle-IDs
   `de.cyberriskadvisor.punkt` / `.widget` bei Bedarf auf eine eigene
   Domain ändern.
2. **App Group:** Für beide Targets unter "Signing & Capabilities" → "App
   Groups" die Gruppe `group.de.cyberriskadvisor.punkt` aktivieren (Bundle-ID
   ggf. angepasst — dann auch `AppGroup.identifier` in
   `Sources/IntentionCore/SharedState/AppGroup.swift` nachziehen).
3. **Capabilities auf dem `Punkt`-Target:**
   - *Live Activities* (Info.plist-Key `NSSupportsLiveActivities` ist
     bereits in `project.yml` gesetzt)
   - *Push Notifications* wird **nicht** benötigt (kein Server, §10) —
     nicht aktivieren.
   - *Time Sensitive Notifications* (`com.apple.developer.usernotifications.time-sensitive`)
     für die `.timeSensitive`-Check-ins — ggf. via Apple Developer Portal
     freischalten lassen.
   - *Siri & Shortcuts* für `StartIntentionIntent` / `AppShortcutsProvider`.
   - *Background Modes* wird bewusst **nicht** gebraucht — es gibt keinen
     Hintergrund-Task; check-ins laufen über geplante lokale Notifications.
4. **Info.plist-Einträge** (bereits in `project.yml` hinterlegt, zur
   Kontrolle): `NSSpeechRecognitionUsageDescription`,
   `NSMicrophoneUsageDescription`, `NSSupportsLiveActivities`.

### Kern-Tests ausführen

Zwei gleichwertige Wege:

- **In Xcode:** ⌘U im `Punkt`-Scheme läuft `IntentionCoreTests` gegen das
  generierte Framework-Target.
- **Terminal, unabhängig vom Xcode-Projekt:**
  ```bash
  swift test
  ```

(Erfordert eine Apple-Plattform, da `SwiftData` und `ActivityKit`
plattformspezifisch sind — nicht unter Linux.)

## Bekannte Grenzen / TODOs für den nächsten Xcode-Durchlauf

- Dieses Projekt wurde ohne Zugriff auf Xcode/den Swift-Compiler erstellt
  (Cloud-Sandbox ohne macOS). Der Code folgt den öffentlichen SwiftUI-,
  SwiftData-, ActivityKit-, WidgetKit- und App-Intents-APIs so genau wie
  möglich, wurde aber nicht kompiliert — ein erster Build-Durchgang in
  Xcode wird kleinere Korrekturen brauchen (Typinferenz, exakte
  API-Signaturen je Xcode-Version).
- **Live-Activity-/Widget-Buttons laufen in einem eigenen Prozess:**
  Interaktive Buttons in der Live Activity (`AnswerCheckInYesIntent` etc.)
  können den laufenden `SessionEngine` der App nicht direkt erreichen. Sie
  schreiben stattdessen in `PendingActionStore` (App Group); die App wendet
  die Aktion beim nächsten Vordergrundwechsel an
  (`SessionStore.refreshAfterForeground`). Ohne Server/Push (§10 explizit
  ausgeschlossen) ist das die ehrliche Lösung — aber dadurch reagiert die
  Live Activity selbst nicht sofort optisch, bis die App kurz aktiv war.
  Für nahtloseres Verhalten könnte ein `ActivityKit`-Push-Update-Kanal
  ergänzt werden, was aber einen Server voraussetzen würde.
- Assets.xcassets (App-Icon, Accent-Farbe) wurde nicht erzeugt — Xcode
  legt beim ersten Öffnen einen Platzhalter an; ein eigenes Icon fehlt noch.
- CloudKit-Sync (optional laut §10) ist nicht implementiert.
