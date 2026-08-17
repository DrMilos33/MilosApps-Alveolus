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
$alveolusGodot = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64.exe'
& $alveolusGodot --editor --path 'C:\Users\pasca\Documents\ChatGPT\Games'
```

Im Editor startet `F5` das Projekt. Direkt aus PowerShell:

```powershell
& $alveolusGodot --path 'C:\Users\pasca\Documents\ChatGPT\Games'
```

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
Set-Location 'C:\Users\pasca\Documents\ChatGPT\Games'
$alveolusGodotConsole = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
$alveolusPython = 'C:\Users\pasca\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
New-Item -ItemType Directory -Force -Path build\web | Out-Null
& $alveolusGodotConsole --headless --path . --export-release Web build/web/index.html
& $alveolusPython -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

Danach: [http://127.0.0.1:8766/](http://127.0.0.1:8766/)

Die veröffentlichte GitHub-Pages-Version bleibt bis zu einer ausdrücklichen
Freigabe ein eingefrorener älterer Vergleichsstand.

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

Der lokale Spielstand verwendet Savegame-Version 5 unter
`user://alveolus_save_v1.json`. Der Dateiname bleibt für Migrationen älterer
Spielstände erhalten. Es gibt kein Backend und keine Cloud-Synchronisierung.

Gebäude, Gegner und Charaktere stammen ausschließlich aus dokumentierten
Assets oder aus Zeichnungen des Nutzers. Alle tatsächlich eingebundenen
Fremdassets und Lizenzen stehen in
[`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md).
