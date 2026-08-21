# ALVEOLUS

ALVEOLUS ist ein spielbarer taktischer 2D-Action- und Idle-Prototyp in Godot.
Als Arzt planst du einen Einsatz und kontrollierst in stilisierten
Lungenmodellen bakterielle Infektionen. Vor jedem Fall wählst du eine
Grundbehandlung, zwei aktive Fähigkeiten, zwei Passivmodule und eine Reserve;
im Run reagierst du zusätzlich auf Proben, Ausbaustufen und einen Befund.

Der aktuelle Entwicklungsstand, die nächsten Schritte und die dauerhaften
Produktentscheidungen stehen in [`docs/PROJECT.md`](docs/PROJECT.md).

## Lokal spielen

Das Projekt verwendet **Godot 4.7.1 Standard**, GDScript und den
Compatibility-Renderer.

```powershell
.\ALVEOLUS.cmd setup
.\ALVEOLUS.cmd status
.\ALVEOLUS.cmd editor
```

`setup` ist pro lokalem Repository nur einmal nötig. Im Editor startet `F5`
das Projekt. Direkt aus PowerShell:

```powershell
.\ALVEOLUS.cmd play
```

Falls Godot nicht automatisch gefunden wird, `.alveolus.local.example.json`
als `.alveolus.local.json` kopieren und dort den lokalen Godot-Pfad eintragen.
Diese persönliche Konfiguration wird nicht committed.

Steuerung:

- `WASD` oder Pfeiltasten: bewegen
- `Q` und `E`: vorbereitete aktive Fähigkeiten
- `Esc`: Pause beziehungsweise Zurück
- `1`, `2`, `3`: Ausbaustufe wählen
- `R`: einmalige Neuauswahl, wenn „Zweitmeinung“ aktiv ist

## Lokaler Browser-Build

Ein Webbuild muss über HTTP geöffnet werden. `file://` kann die
WebAssembly-Dateien nicht zuverlässig laden.

```powershell
.\ALVEOLUS.cmd build-web
.\ALVEOLUS.cmd open-build
```

Jeder Export liegt unter `build/local/<Datum>-<Commit>/` und enthält ein
`manifest.json`. `open-build` öffnet den Ordner und gibt den vollständigen
Serverbefehl aus. Alternativ funktioniert direkt:

```powershell
$build = (.\ALVEOLUS.cmd status -Json | ConvertFrom-Json).latest_build.path
$python = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python -m http.server 8766 --bind 127.0.0.1 --directory $build
```

Danach: [http://127.0.0.1:8766/](http://127.0.0.1:8766/).

Die veröffentlichte GitHub-Pages-Version bleibt bis zu einer ausdrücklichen
Freigabe ein eingefrorener älterer Vergleichsstand.

## Lokaler Stand und GitHub

`C:\Users\pasca\Documents\ChatGPT\Games` ist die kanonische lokale
Arbeitskopie auf `codex/alveolus-local-main`. Die Begriffe sind getrennt:

- **Arbeitskopie:** noch nicht committete lokale Änderungen;
- **Git-Commit:** schneller, rein lokaler und wiederherstellbarer Checkpoint;
- **GitHub-Push:** externe Veröffentlichung auf `origin/dev`.

Lokale Commits benötigen keine Freigabe und verändern GitHub nicht. Ein Push
ist technisch gesperrt und benötigt einen separaten Releaseauftrag mit
vollständiger Commit-ID und der exakten Bestätigung
`ALVEOLUS-RELEASE-v1 <SHA> origin/dev`. `.\ALVEOLUS.cmd status` zeigt lokalen
HEAD, Dirty-State, die Zahl nur lokal vorhandener Commits, Builds sowie Rolle
und Pfad aller Worktrees. Der GitHub-Vergleich verwendet den lokal gecachten
Stand von `origin/dev`; `status` führt absichtlich keinen Netzwerk-Fetch aus.

Alte generierte Dateien werden zuerst mit `.\ALVEOLUS.cmd cleanup-preview`
aufgelistet. `cleanup-apply` bewahrt den neuesten gültigen Webbuild, entfernt
nur validierte Pfade unter `build/` beziehungsweise `.codex-temp/` und schreibt
einen lokalen Bericht.

### Checkpoints und Recovery

Zur kanonischen Arbeitskopie zurückkehren:

```powershell
Set-Location 'C:\Users\pasca\Documents\ChatGPT\Games'
.\ALVEOLUS.cmd status
```

Vor einer eigenen Änderung zuerst `git status --short` prüfen. Einen lokalen
Checkpoint erzeugst du mit `git add <deine-Dateien>` und
`git commit -m "kurze Beschreibung"`; das lädt nichts hoch. Frühere
Checkpoints zeigt `git log --oneline --decorate -12`. Der verlustfreie Stand
vor der Ordnerumstellung bleibt zusätzlich unter dem lokalen Branch
`codex/recovery-documents-dirty-20260821` und dem Tag
`recovery/pre-canonical-migration-20260821` erhalten. Zum Prüfen genügt
`git show --stat recovery/pre-canonical-migration-20260821`; Dateien daraus
erst nach einem sauberen `git status` gezielt wiederherstellen.

## Projektübersicht

| Thema | Verbindliche Quelle |
|---|---|
| Status, Roadmap, offene Grenzen und Entscheidungen | [`docs/PROJECT.md`](docs/PROJECT.md) |
| Arbeitsweise für Codex und parallele Aufgaben | [`AGENTS.md`](AGENTS.md) |
| Testauswahl und Definition of Done | [`docs/QUALITY.md`](docs/QUALITY.md) |
| Laufzeit, Ownership und Fixed-Step | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Aktive Fähigkeiten und Feedback | [`docs/ABILITY_PIPELINE.md`](docs/ABILITY_PIPELINE.md) |
| Leistungsziele und Messverfahren | [`docs/PERFORMANCE_BUDGET.md`](docs/PERFORMANCE_BUDGET.md) |
| UI-Komponenten und Gestaltungsregeln | [`docs/UI_STYLE_GUIDE.md`](docs/UI_STYLE_GUIDE.md) |
| Campus im Godot-Editor bearbeiten | [`docs/CAMPUS_EDITOR.md`](docs/CAMPUS_EDITOR.md) |
| Fremdassets und Lizenzen | [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md) |

Der Ordner `docs/` enthält zusätzlich den eingefrorenen GitHub-Pages-Export.
`docs/health.json` beschreibt deshalb den veröffentlichten Vergleichsstand und
nicht den aktuellen lokalen Projektstatus.

## Entwicklung und Tests

Nicht jede Änderung benötigt die komplette Testsuite. Die passende Prüftiefe
steht in [`docs/QUALITY.md`](docs/QUALITY.md). Profile anzeigen:

```powershell
& .\tests\run_checks.ps1 -List
```

Typische Beispiele:

```powershell
& .\tests\run_checks.ps1 -Profile Quick
& .\tests\run_checks.ps1 -Profile UI -Visual
& .\tests\run_checks.ps1 -Profile Combat
& .\tests\run_checks.ps1 -Profile Runtime
```

Die vollständige lokale Headless-Matrix ist für breite Änderungen und
Releasekandidaten vorgesehen:

```powershell
& .\tests\run_checks.ps1 -Profile Full
```

Die ältere technische Spezialsuite bleibt für Renderer- und Performancearbeit
verfügbar:

```powershell
& .\tests\run_technical_regressions.ps1
& .\tests\run_technical_regressions.ps1 -FullSoak
```

## Speicherstand und Assets

Der lokale Spielstand verwendet Savegame-Version 6 unter
`user://alveolus_save_v1.json`. Der Dateiname bleibt für Migrationen älterer
Spielstände erhalten. Es gibt kein Backend und keine Cloud-Synchronisierung.

Gebäude, Gegner und Charaktere stammen ausschließlich aus dokumentierten
Assets oder aus Zeichnungen des Nutzers. Alle tatsächlich eingebundenen
Fremdassets und Lizenzen stehen in
[`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md).
