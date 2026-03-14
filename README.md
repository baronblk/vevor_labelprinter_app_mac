# VevorPrint

Eine native macOS-App zum Entwerfen und Drucken von Labels auf dem **Vevor Y428BT-42B0** Bluetooth-Thermodrucker.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Bluetooth-Verbindung** — Direkte BLE-Verbindung zum Drucker, automatische Wiedererkennung
- **Label-Designer** — Vollständiger visueller Editor mit Drag & Drop
- **Label-Größen** — 8 vordefinierte Größen (40×30 mm bis 100×150 mm Paketlabel) + benutzerdefiniert
- **Elemente**
  - Textfelder (Font, Größe, Stil, Rotation)
  - Bilder (PNG, JPEG, PDF-Import)
  - QR-Codes (alle Fehlerkorrekturlevel)
  - Barcodes (Code 128, EAN-13, EAN-8, Aztec, PDF417, DataMatrix)
  - Trennlinien
- **Templates** — Labels speichern, laden und als Galerie durchsuchen
- **Export** — PNG (300 dpi) und PDF
- **Modernes UI** — macOS-native SwiftUI, Dark Mode, Keyboard Shortcuts

---

## Systemvoraussetzungen

| Anforderung | Minimum |
|---|---|
| macOS | 14.0 (Sonoma) |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Hardware | Vevor Y428BT-42B0 (oder kompatibler ESC/POS BLE-Drucker) |

---

## Installation & Build

```bash
# Repository klonen
git clone https://github.com/yourname/VevorPrint.git
cd VevorPrint

# In Xcode öffnen
open VevorPrint.xcodeproj

# Build & Run
⌘ + R
```

### Erster Start

1. Die App fragt beim ersten Start nach Bluetooth-Berechtigung — **Erlauben** klicken
2. Den Drucker einschalten und sicherstellen, dass er sichtbar (discoverable) ist
3. Im Onboarding-Screen auf **"Drucker suchen"** klicken
4. Vevor Y428BT-42B0 aus der Liste auswählen und verbinden

---

## Verwendung

### Label erstellen

1. **Label-Größe** in der linken Sidebar auswählen (z.B. "100 × 150 mm Paketlabel")
2. Elemente per Klick auf die Werkzeug-Buttons hinzufügen:
   - **T** — Textfeld
   - **⬜** — Bild/PDF importieren
   - **◼** — QR-Code
   - **|||||** — Barcode
   - **—** — Trennlinie
3. Elemente durch Ziehen positionieren, per Handles skalieren
4. Eigenschaften in der rechten Sidebar anpassen

### Drucken

1. Sicherstellen, dass der Drucker verbunden ist (grüner Punkt in der Statusbar)
2. **⌘ + P** drücken oder auf den Drucken-Button klicken
3. Vorschau prüfen und mit **"Drucken"** bestätigen

### Tastenkürzel

| Aktion | Shortcut |
|---|---|
| Drucken | ⌘ P |
| Vorschau | ⌘ ⇧ P |
| Exportieren (PNG) | ⌘ E |
| Exportieren (PDF) | ⌘ ⇧ E |
| Rückgängig | ⌘ Z |
| Wiederholen | ⌘ ⇧ Z |
| Alles auswählen | ⌘ A |
| Löschen | ⌫ |
| Zoom +/- | ⌘ +/– |
| Zoom Reset | ⌘ 0 |
| Neues Label | ⌘ N |
| Template speichern | ⌘ S |

---

## Unterstützte Label-Größen

| Name | Maße |
|---|---|
| Standard klein | 40 × 30 mm |
| Produktlabel | 50 × 30 mm |
| Kassenlabel | 57 × 32 mm |
| Adresslabel klein | 60 × 40 mm |
| Adresslabel | 75 × 40 mm |
| Versandlabel | 100 × 50 mm |
| Paketlabel | 100 × 150 mm |
| Benutzerdefiniert | frei wählbar |

---

## Architektur

```
VevorPrint
├── SwiftUI UI Layer
├── @Observable ViewModels (LabelViewModel, PrinterViewModel)
├── Services
│   ├── BluetoothManager     CoreBluetooth BLE
│   ├── LabelRenderer        CGContext Bitmap-Rendering
│   ├── ESCPOSEncoder        Drucker-Kommandos
│   └── BarcodeGenerator     CoreImage CIFilter
└── SwiftData                 Templates & Einstellungen
```

Vollständige Architektur-Dokumentation: [`CLAUDE_CODE_PROMPT.md`](CLAUDE_CODE_PROMPT.md)

---

## Druckerprotokoll

Der Vevor Y428BT-42B0 kommuniziert über **BLE GATT** und akzeptiert **ESC/POS**-Kommandos. VevorPrint rendert das Label als 1-Bit-Bitmap (203 dpi) und überträgt es via `GS v 0` Raster-Image-Kommando.

> **Hinweis:** Die BLE-UUIDs des Druckers sind in `BLEConstants.swift` hinterlegt. Beim ersten Verbinden werden alle gefundenen UUIDs geloggt, sodass sie bei Bedarf angepasst werden können.

---

## Entwicklung

### Tests ausführen

```bash
⌘ + U   # in Xcode
# oder
xcodebuild test -scheme VevorPrint -destination 'platform=macOS'
```

### Für Claude Code

Dieses Projekt wurde für die Entwicklung mit **Claude Code** ausgelegt. Alle Anweisungen befinden sich in [`CLAUDE.md`](CLAUDE.md) und [`CLAUDE_CODE_PROMPT.md`](CLAUDE_CODE_PROMPT.md).

```bash
# Im Projektverzeichnis
claude
# Dann: "Lies CLAUDE.md und setze Phase 2 fort."
```

---

## Bekannte Einschränkungen

- Die BLE-UUIDs des Druckers können je nach Firmware-Version variieren. Beim ersten Test mit dem realen Gerät müssen die UUIDs aus dem Log entnommen und in `BLEConstants.swift` eingetragen werden.
- Kein offizielles Protokoll-Dokument von Vevor verfügbar — ESC/POS-Implementierung basiert auf dem Standard-Protokoll.
- Druckgeschwindigkeit ist von der BLE-Bandbreite abhängig (ca. 2–5 Sekunden für ein typisches Label).

---

## Lizenz

MIT License — siehe [LICENSE](LICENSE)

---

## Beiträge

Pull Requests sind willkommen. Bitte vor größeren Änderungen ein Issue öffnen.
