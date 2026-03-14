# GIT_WORKFLOW.md — VevorPrint Git & GitHub Anweisungen

## Repository

```
https://github.com/baronblk/vevor_labelprinter_app_mac.git
```

Dieses Repository ist die **einzige Source of Truth** für das VevorPrint-Projekt.
Claude Code arbeitet **immer** im geklonten lokalen Verzeichnis und hält das Remote-Repo stets aktuell.

---

## Setup (einmalig, beim ersten Start)

```bash
# Repository klonen (falls noch nicht vorhanden)
git clone https://github.com/baronblk/vevor_labelprinter_app_mac.git
cd vevor_labelprinter_app_mac

# Git-Identität setzen (einmalig pro Maschine)
git config user.name "baronblk"
git config user.email "deine@email.com"

# Branch-Strategie initialisieren
git checkout -b develop
git push -u origin develop
```

---

## Branch-Strategie

```
main        ← stabil, nur getesteter Code, kein direktes Commiten
develop     ← aktiver Entwicklungs-Branch
feature/*   ← neue Features (z.B. feature/bluetooth-manager)
fix/*       ← Bugfixes (z.B. fix/ble-reconnect)
```

**Regel:** Claude Code arbeitet immer auf `develop` oder einem `feature/`-Branch.
Auf `main` wird nur per Pull Request gemergt — niemals direkt.

---

## Commit-Konventionen (Conventional Commits)

Jeder Commit folgt exakt diesem Format:

```
<type>(<scope>): <kurze Beschreibung>

[optionaler Body]

[optionaler Footer]
```

### Erlaubte Types

| Type | Wann |
|---|---|
| `feat` | Neues Feature |
| `fix` | Bugfix |
| `refactor` | Code-Umstrukturierung ohne Funktionsänderung |
| `style` | Formatierung, keine Logik-Änderung |
| `docs` | Dokumentation (README, CLAUDE.md usw.) |
| `test` | Tests hinzufügen oder ändern |
| `chore` | Build, Dependencies, Konfiguration |
| `perf` | Performance-Verbesserung |
| `ci` | CI/CD-Konfiguration |

### Erlaubte Scopes

`bluetooth`, `canvas`, `printer`, `templates`, `import`, `export`, `ui`, `models`, `tests`, `docs`, `build`

### Beispiele

```bash
feat(bluetooth): add auto-reconnect on app foreground
fix(canvas): resolve resize handle offset at zoom > 100%
feat(printer): implement ESC/POS raster bitmap encoder
refactor(models): extract LabelElement into separate files
docs(readme): add keyboard shortcuts table
test(encoder): add unit tests for ESCPOSEncoder bitmap command
chore(build): update Swift package dependencies
feat(templates): add SwiftData persistence for label templates
fix(ble): reduce chunk size to 20 bytes for compatibility
perf(renderer): cache CGImage rendering at 300 dpi
```

---

## Wann Claude Code committen soll

Claude Code committet **nach jedem abgeschlossenen logischen Schritt**, nicht erst am Ende einer Phase. Faustregel:

- ✅ Eine neue Datei vollständig implementiert → commit
- ✅ Ein Bug behoben und getestet → commit
- ✅ Refactoring abgeschlossen → commit
- ✅ Tests geschrieben und grün → commit
- ❌ Halbfertiger Code → KEIN commit (nie broken state pushen)
- ❌ Mehrere unzusammenhängende Änderungen in einem Commit → vermeiden

---

## Git-Workflow pro Feature

```bash
# 1. Auf develop starten, aktuellen Stand holen
git checkout develop
git pull origin develop

# 2. Feature-Branch anlegen
git checkout -b feature/bluetooth-manager

# 3. Implementieren...
# ... Code schreiben ...

# 4. Staged commit (nur relevante Dateien)
git add VevorPrint/Services/Bluetooth/BluetoothManager.swift
git add VevorPrint/Services/Bluetooth/BLEConstants.swift
git add VevorPrint/Services/Bluetooth/PrinterConnection.swift
git commit -m "feat(bluetooth): implement CBCentralManager scan and connect

- Auto-scan on app launch
- Reconnect via stored peripheral UUID
- Chunked BLE write with 512 byte packets
- Connection state enum: disconnected/scanning/connecting/connected/error"

# 5. Pushen
git push origin feature/bluetooth-manager

# 6. In develop mergen (nach eigenem Review)
git checkout develop
git merge feature/bluetooth-manager --no-ff -m "merge: feature/bluetooth-manager into develop"
git push origin develop

# 7. Feature-Branch aufräumen
git branch -d feature/bluetooth-manager
git push origin --delete feature/bluetooth-manager
```

---

## Release / Merge in main

Wenn eine Phase komplett abgeschlossen und getestet ist:

```bash
git checkout main
git pull origin main
git merge develop --no-ff -m "release: Phase 2 - Bluetooth stack complete

Features:
- CBCentralManager BLE scan and connect
- Auto-reconnect on app start
- ESC/POS chunked write (512 bytes)
- Connection status UI (toolbar + statusbar)
- Onboarding Bluetooth permission flow"

git tag -a v0.2.0 -m "Phase 2: Bluetooth stack"
git push origin main
git push origin --tags
```

### Versions-Schema (Semantic Versioning)

```
v0.1.0  — Phase 1 abgeschlossen (Projekt-Setup)
v0.2.0  — Phase 2 abgeschlossen (Bluetooth)
v0.3.0  — Phase 3 abgeschlossen (Canvas-Grundgerüst)
v0.4.0  — Phase 4 abgeschlossen (alle Element-Typen)
v0.5.0  — Phase 5 abgeschlossen (Print-Pipeline)
v0.6.0  — Phase 6 abgeschlossen (Templates & Export)
v1.0.0  — Phase 7 abgeschlossen (Production Ready)
```

---

## .gitignore (Swift/Xcode — muss im Repo vorhanden sein)

```gitignore
# Xcode
*.xcuserstate
xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

# Swift Package Manager
.build/
.swiftpm/
*.resolved

# macOS
.DS_Store
.AppleDouble
.LSOverride
*.icloud

# Backup & temp
*~
*.orig
*.bak

# Claude Code
.claude/todos.md

# Sensitive / local
*.env
Secrets.swift
```

---

## Anweisungen an Claude Code

Claude Code führt folgende Git-Operationen **eigenständig und proaktiv** durch:

### Nach jeder abgeschlossenen Implementierung

```bash
# Status prüfen
git status
git diff --stat

# Sinnvolle Dateien stagen (nie git add . blind verwenden)
git add <spezifische Dateien>

# Committen mit aussagekräftiger Message
git commit -m "feat(scope): beschreibung"

# Pushen
git push origin <aktueller-branch>
```

### Vor jeder neuen Aufgabe

```bash
# Immer zuerst aktuellen Stand holen
git pull origin develop
```

### Nach einem erfolgreichen Build / grünen Tests

```bash
git add .
git commit -m "test(scope): all tests passing after <was wurde implementiert>"
git push origin <branch>
```

### Bei Refactoring

```bash
git commit -m "refactor(scope): <was wurde vereinfacht/umstrukturiert>

No functional changes. Motivation: <kurze Begründung>"
```

---

## GitHub Repository pflegen

Claude Code soll folgende Repository-Hygiene einhalten:

1. **Kein toter Code** — gelöschter Code wird nicht auskommentiert, sondern entfernt (Git History bewahrt ihn)
2. **Kein `TODO:` ohne zugehörigen Commit** — offene TODOs gehören in GitHub Issues, nicht als Kommentare im Code
3. **`develop` ist immer buildbar** — nie broken code auf develop pushen
4. **Tags bei Phasen-Abschluss** — jede Phase bekommt einen Git-Tag (siehe Versions-Schema)
5. **Commit-Messages auf Englisch** — einheitlich, maschinenlesbar, konventionskonform

---

## Schnellbefehle für Claude Code

```bash
# Aktuellen Branch anzeigen
git branch --show-current

# Log der letzten 10 Commits (kompakt)
git log --oneline -10

# Alle Branches anzeigen
git branch -a

# Uncommitted changes prüfen
git status -s

# Letzten Commit rückgängig (nur lokal, noch nicht gepusht)
git reset --soft HEAD~1

# Remote-Stand anzeigen ohne zu mergen
git fetch origin && git log HEAD..origin/develop --oneline
```

---

## Session-Start Checkliste für Claude Code

Am Anfang **jeder** Claude Code Session:

```bash
# 1. Im richtigen Verzeichnis?
pwd

# 2. Aktuellen Branch prüfen
git branch --show-current

# 3. Remote-Änderungen holen
git pull origin develop

# 4. Offene Änderungen prüfen
git status

# 5. Letzten Stand lesen
git log --oneline -5
```

Danach: `CLAUDE.md` lesen und weitermachen wo aufgehört wurde.
