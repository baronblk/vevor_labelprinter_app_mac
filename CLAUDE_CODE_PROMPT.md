# Claude Code Prompt — VevorPrint macOS App

Technischer Masterplan für die Entwicklung der VevorPrint macOS-App.
Vollständige Spezifikation aller Phasen, Features und Implementierungsdetails.

Siehe CLAUDE.md für Session-Start-Anweisungen und Phasen-Übersicht.
Siehe GIT_WORKFLOW.md für Git- und GitHub-Regeln.

## Technischer Stack

| Komponente | Technologie |
|---|---|
| UI-Framework | SwiftUI (macOS-nativ) |
| State Management | @Observable (Swift 5.9 Observation) + @Environment |
| Persistenz | SwiftData (Label-Templates, Einstellungen) |
| Bluetooth | CoreBluetooth (BLE GATT) |
| PDF-Verarbeitung | PDFKit |
| Barcode/QR | CoreImage (CIFilter) |
| Grafik / Rendering | Core Graphics (CGContext, CGImage) |
| Build System | Swift Package Manager / Xcode |
| Mindest-macOS | 14.0 (Sonoma) |

## Implementierungs-Reihenfolge (Phasen)

### Phase 1 — Projekt-Grundgerüst
1. Xcode-Projekt aufsetzen (Bundle-ID: de.baronblk.vevorprint)
2. SwiftData Container konfigurieren
3. NavigationSplitView Grundlayout mit Sidebar Placeholders
4. AppSettings @Observable implementieren

### Phase 2 — Bluetooth-Stack
1. BluetoothManager mit CBCentralManager, Scan, Connect, Reconnect
2. PrinterConnection CBPeripheral-Wrapper mit Write-Characteristic-Discovery
3. BLE-Status-UI (Statusbar + Toolbar-Indikator)
4. Onboarding-Sheet mit Bluetooth-Permission-Flow

### Phase 3 — Label-Datenmodell & Canvas
1. LabelElement Protokoll + alle konkreten Element-Typen (struct, identifiable, codable)
2. LabelViewModel mit Element-Array, Selection, UndoManager
3. LabelCanvasView — Layer-basiertes Rendering mit SwiftUI Canvas
4. Drag, Resize-Handles, Rotation implementieren
5. Snap-to-Grid, Ruler-Overlay

### Phase 4 — Element-Typen
1. TextElement — Font-Picker, Styling, Inline-Editing
2. ImageElement — Drag & Drop + NSOpenPanel Import, PDF-Seiten-Rendering
3. QRCodeElement — CoreImage CIQRCodeGenerator, Live-Preview
4. BarcodeElement — alle Barcode-Typen via CoreImage
5. LineElement — simple Trennlinie

### Phase 5 — Print-Pipeline
1. LabelRenderer — CGContext Bitmap-Rendering aller Elemente bei 203/300 dpi
2. ESCPOSEncoder — Raster-Image-Command (GS v 0), Init, Feed, Cut
3. Print-Queue in PrinterViewModel mit chunked BLE-Write
4. PrintPreviewPanel — hochauflösendes Preview-Image

### Phase 6 — Templates & Export
1. SwiftData Template-Persistenz (LabelDocument Model)
2. Template-Browser (Grid mit Vorschaubildern)
3. PNG-Export (300 dpi via CGImage)
4. PDF-Export (PDFDocument mit Single-Page)
5. JSON-Export/Import des Label-Formats

### Phase 7 — Polish
1. Menüleiste vollständig (inkl. Keyboard Shortcuts)
2. Dark Mode, Accessibility Labels
3. Error-Handling & User-Feedback (Toasts, Alerts)
4. Onboarding komplett

## Kritische Implementierungsdetails

### BluetoothManager — CoreBluetooth Pattern

```swift
@Observable final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var connectedPrinter: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?
    var connectionState: ConnectionState = .disconnected

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func send(data: Data) {
        guard let char = writeCharacteristic,
              let printer = connectedPrinter else { return }
        stride(from: 0, to: data.count, by: 512).forEach { offset in
            let end = min(offset + 512, data.count)
            let chunk = data[offset..<end]
            printer.writeValue(chunk, for: char, type: .withoutResponse)
        }
    }
}
```

### LabelElement Protokoll-Design

```swift
protocol LabelElement: Identifiable, Codable {
    var id: UUID { get }
    var frame: CGRect { get set }     // in mm
    var rotation: Double { get set }  // Grad
    var zIndex: Int { get set }
    func render(in context: CGContext, scale: CGFloat)
}
```

### UnitConversion

```swift
struct UnitConversion {
    static let mmPerInch: CGFloat = 25.4
    static func mmToPx(_ mm: CGFloat, dpi: CGFloat) -> CGFloat { mm / mmPerInch * dpi }
    static func pxToMm(_ px: CGFloat, dpi: CGFloat) -> CGFloat { px / dpi * mmPerInch }
    static func mmToPt(_ mm: CGFloat) -> CGFloat { mm / mmPerInch * 72.0 }
}
```

### ESC/POS Raster-Bitmap-Kommando

```swift
// GS v 0 — Raster bit image
func rasterImageCommand(from image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    let bytesPerRow = (width + 7) / 8
    var imageData = [UInt8](repeating: 0, count: bytesPerRow * height)
    // ... CGContext mit 1-Bit-Tiefe rendern ...
    var cmd: [UInt8] = [0x1D, 0x76, 0x30, 0x00]  // GS v 0 normal
    let xL = UInt8(bytesPerRow & 0xFF)
    let xH = UInt8((bytesPerRow >> 8) & 0xFF)
    let yL = UInt8(height & 0xFF)
    let yH = UInt8((height >> 8) & 0xFF)
    cmd += [xL, xH, yL, yH]
    cmd += imageData
    return cmd
}
```

## BLE UUIDs (zu verifizieren mit realem Gerät)

```swift
enum BLEConstants {
    static let printerServiceUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")
    static let writeCharUUID      = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")
    static let sppServiceUUID     = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
}
```

## Label-Größen

| Name | Breite | Höhe |
|---|---|---|
| 40 × 30 mm | 40 | 30 |
| 50 × 30 mm | 50 | 30 |
| 57 × 32 mm | 57 | 32 |
| 60 × 40 mm | 60 | 40 |
| 75 × 40 mm | 75 | 40 |
| 100 × 50 mm | 100 | 50 |
| 100 × 150 mm (Paketlabel) | 100 | 150 |
| Benutzerdefiniert | frei | frei |

## Print-Pipeline

```
LabelElements (Array von LabelElement)
    ↓
LabelRenderer.render(size:dpi:) → CGImage (300 dpi Bitmap)
    ↓
ESCPOSEncoder.printBitmap(_ cgImage:) → [UInt8]
    ↓
BluetoothManager.send(data: Data, in chunks of 512 bytes)
    ↓
Vevor Y428BT-42B0
```

## ESC/POS Kommando-Sequenz

```
1. ESC @ (0x1B 0x40)                              — Drucker initialisieren
2. GS v 0 (0x1D 0x76 0x30 0x00) + Bitmap-Daten   — Raster-Bild drucken
3. LF (0x0A) × 3                                  — Paper feed
4. GS V (0x1D 0x56 0x00)                          — Paper cut
```

## Bekannte Fallstricke

1. **BLE UUIDs:** Der Vevor Y428BT-42B0 verwendet wahrscheinlich einen proprietären Service. Scanne alle Services und suche nach Write-fähigen Characteristics. Logge alle gefundenen UUIDs in der Debug-Konsole.
2. **App Sandbox & Bluetooth:** Erfordert Entitlement `com.apple.security.device.bluetooth`.
3. **SwiftUI Canvas vs NSView:** SwiftUI Canvas für statisches Rendering; ZStack mit DragGesture für interaktive Elemente.
4. **CGImage Bit-Konvertierung:** 1-Bit (schwarz/weiß) für ESC/POS. Nutze `CGColorSpace.genericGrayGamma2_2`.
5. **SwiftData Schema:** Alle `@Model`-Klassen müssen `class` sein, alle Properties brauchen Standardwerte.
