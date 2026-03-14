# CLAUDE.md — VevorPrint

Dieses Dokument enthält alle Anweisungen für Claude Code zur Entwicklung der VevorPrint macOS-App.

## Repository

```
https://github.com/baronblk/vevor_labelprinter_app_mac.git
```

**Pflichtlektüre beim Session-Start:**
1. `CLAUDE.md` (diese Datei)
2. `CLAUDE_CODE_PROMPT.md` (technischer Masterplan)
3. `GIT_WORKFLOW.md` (Git & GitHub Regeln)

---

## Session-Start — immer zuerst ausführen

```bash
pwd                          # Sicherstellen im richtigen Verzeichnis
git branch --show-current    # Branch prüfen
git pull origin develop      # Aktuellen Stand holen
git log --oneline -5         # Letzten Stand lesen
git status                   # Offene Änderungen prüfen
```

Erst danach mit der Implementierung beginnen.

---

## Projektübersicht

**VevorPrint** ist eine native macOS-App (SwiftUI, macOS 14+) zum Entwerfen und Drucken von Labels auf einem Vevor Y428BT-42B0 Bluetooth-Thermodrucker.

---

## Entwicklungsregeln

### Allgemein

- Sprache: **Swift 5.9+**, kein Objective-C außer zwingend notwendig für CoreBluetooth-Delegates
- UI ausschließlich **SwiftUI**; AppKit (`NSView`) nur als letzter Ausweg für Gesten, die SwiftUI nicht abbilden kann
- State Management: **`@Observable`** (Swift 5.9 Observation Framework), nicht `ObservableObject`/`@Published`
- Persistenz: **SwiftData** — kein CoreData, kein UserDefaults für komplexe Daten
- Kein `DispatchQueue.main.async` — nutze `@MainActor` und Swift Concurrency (`async/await`)
- Fehlerbehandlung: immer `throws` / `Result<T,E>` — kein `fatalError` in Produktionscode
- Alle public APIs mit `// MARK:` strukturieren

### Namenskonventionen

- ViewModels: `*ViewModel` (z.B. `LabelViewModel`)
- Services: keine Suffix (z.B. `BluetoothManager`, `LabelRenderer`)
- Models: ohne Suffix (z.B. `LabelElement`, `LabelSize`)
- Views: `*View` (z.B. `LabelCanvasView`)

### Code-Qualität

- Keine Warnings toleriert (treat warnings as errors im Build)
- Jede Klasse/Struct hat einen kurzen Kommentarblock mit Zweck
- Alle öffentlichen Funktionen haben Parameter-Dokumentation (`/// - Parameter:`)
- Unit-Tests für: `UnitConversion`, `ESCPOSEncoder`, `BarcodeGenerator`, `LabelRenderer`

---

## Git-Regeln (ZWINGEND einhalten)

Vollständige Regeln: siehe `GIT_WORKFLOW.md`

### Kurzfassung

- Arbeite immer auf `develop` oder einem `feature/*`-Branch — **niemals direkt auf `main`**
- Committe nach **jedem abgeschlossenen logischen Schritt** (nie halbfertigen Code)
- Commit-Messages nach **Conventional Commits**: `feat(scope): beschreibung`
- **Spezifische Dateien stagen** — kein blindes `git add .`
- Nach jedem Commit sofort **pushen**: `git push origin <branch>`
- Bei Phasen-Abschluss: develop in main mergen + **Git-Tag setzen**

### Commit-Pflicht nach diesen Ereignissen

| Ereignis | Commit-Typ |
|---|---|
| Neue Datei vollständig implementiert | `feat(scope): ...` |
| Bug gefunden und behoben | `fix(scope): ...` |
| Tests geschrieben und grün | `test(scope): ...` |
| Code umstrukturiert (keine Logik-Änderung) | `refactor(scope): ...` |
| Dokumentation aktualisiert | `docs(scope): ...` |
| Build-Konfiguration geändert | `chore(build): ...` |

---

## Phasen-Übersicht

Implementiere immer genau eine Phase vollständig, bevor du mit der nächsten beginnst.
Nach jeder Phase: develop in main mergen + Tag setzen.

| Phase | Inhalt | Tag |
|---|---|---|
| 1 | Projekt-Setup, SwiftData Container, Root-Layout | v0.1.0 |
| 2 | Bluetooth-Stack (CoreBluetooth) | v0.2.0 |
| 3 | Label-Datenmodell + Canvas-Grundgerüst | v0.3.0 |
| 4 | Element-Typen (Text, Image, QR, Barcode, Linie) | v0.4.0 |
| 5 | Print-Pipeline (Renderer → ESC/POS → BLE) | v0.5.0 |
| 6 | Templates & Export | v0.6.0 |
| 7 | Polish, Menüleiste, Shortcuts, Accessibility | v1.0.0 |

Details zu jeder Phase: siehe `CLAUDE_CODE_PROMPT.md`.

---

## Bluetooth-Protokoll

Der Drucker ist ein BLE-Gerät. Beim ersten Connect:

1. Alle Services loggen: `peripheral.discoverServices(nil)`
2. Alle Characteristics loggen: `peripheral.discoverCharacteristics(nil, for: service)`
3. Write-fähige Characteristic identifizieren (`.write` oder `.writeWithoutResponse`)
4. UUID in `BLEConstants.swift` festhalten und committen: `chore(bluetooth): update verified BLE UUIDs`

Erwartete UUIDs (zu verifizieren mit realem Gerät):
```swift
enum BLEConstants {
    static let printerServiceUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")
    static let writeCharUUID      = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")
    static let sppServiceUUID     = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
}
```

---

## Print-Protokoll (ESC/POS)

Kommando-Sequenz für einen vollständigen Druckauftrag:

```
1. ESC @ (0x1B 0x40)                              — Drucker initialisieren
2. GS v 0 (0x1D 0x76 0x30 0x00) + Bitmap-Daten   — Raster-Bild drucken
3. LF (0x0A) × 3                                  — Paper feed
4. GS V (0x1D 0x56 0x00)                          — Paper cut
```

---

## Datei-Struktur (NICHT verändern)

```
VevorPrint/
├── VevorPrintApp.swift
├── ContentView.swift
├── Models/
├── ViewModels/
├── Views/
│   ├── Canvas/
│   ├── Sidebar/
│   ├── Toolbar/
│   ├── Panels/
│   └── Printer/
├── Services/
│   ├── Bluetooth/
│   ├── Printing/
│   └── Import/
├── Utilities/
│   └── Extensions/
└── Resources/
```

---

## Tests

Test-Targets anlegen für:

```swift
// Tests/VevorPrintTests/
// - UnitConversionTests.swift
// - ESCPOSEncoderTests.swift
// - BarcodeGeneratorTests.swift
// - LabelRendererTests.swift
```

Jeder Test muss ohne Bluetooth/Hardware laufen.

---

## Bekannte Einschränkungen

- ESC/POS des Vevor Y428BT-42B0 ist nicht offiziell dokumentiert → Standard-ESC/POS implementieren
- Adaptive BLE-Chunk-Größe: starte mit 20 Byte, erhöhe auf 512 falls `maximumWriteValueLength` es erlaubt
- CoreBluetooth benötigt zwingend Bluetooth-Entitlement in der `.entitlements`-Datei

---

## Wenn du auf Probleme stößt

1. **BLE verbindet sich nicht:** Entitlements prüfen, alle gefundenen Peripherals loggen
2. **Drucker druckt nichts:** UUIDs prüfen, Write-Typ prüfen, Chunk-Größe auf 20 Byte reduzieren
3. **Schlechte Druckqualität:** DPI auf 300 erhöhen, Bitmap-Bit-Konvertierung prüfen
4. **SwiftData Fehler:** Alle `@Model`-Klassen müssen `class` sein, alle Properties brauchen Standardwerte
5. **Git-Konflikt:** `git status` und `git diff` lesen, manuell lösen, dann committen mit `fix(merge): resolve conflict in <datei>`

---

## Nächste Session starten

Am Anfang jeder neuen Claude Code Session:

```
"Lies CLAUDE.md, GIT_WORKFLOW.md und CLAUDE_CODE_PROMPT.md.
Führe den Session-Start-Check aus (git pull, git log, git status).
Zeige mir den aktuellen Stand und setze Phase [N] fort."
```
