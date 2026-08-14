# ALVEOLUS

ALVEOLUS ist ein kleiner, vollständig spielbarer 2D-Survivors- und Idle-Prototyp. Als Therapie-Avatar behandelst du stilisierte bakterielle Pneumonien, während die Angriffe automatisch zielen. Prolog, isometrischer Praxis-Campus, Forschung, Fallarchiv, wiederholbare Level und lokale Fortschritte bilden bereits den vollständigen Rahmen des Spiels.

## Spielen

Das Projekt verwendet **Godot 4.7.1 Standard** mit GDScript und dem Compatibility-Renderer. Die portable Godot-Version liegt auf diesem Rechner hier:

```text
C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64.exe
```

Projekt im Editor öffnen:

```powershell
$alveolusGodot = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64.exe'
& $alveolusGodot --editor --path 'C:\Users\pasca\Documents\ChatGPT\Games'
```

Im Godot-Editor startet `F6` die aktuelle Szene und `F5` das Projekt. Alternativ lässt sich das Spiel direkt aus PowerShell starten:

```powershell
& $alveolusGodot --path 'C:\Users\pasca\Documents\ChatGPT\Games'
```

Steuerung:

- `WASD` oder Pfeiltasten: Therapie-Avatar bewegen
- `P` oder `Esc`: pausieren beziehungsweise fortsetzen
- `1`, `2`, `3`: Level-up auswählen
- `R`: Upgrades einmal pro Run neu ziehen, sobald „Zweitmeinung“ erforscht wurde
- Therapien zielen und feuern automatisch

## Web-Build

Der konfigurierte Webexport ist Single-Threaded und benötigt keine speziellen Cross-Origin-Header:

```powershell
Set-Location 'C:\Users\pasca\Documents\ChatGPT\Games'
New-Item -ItemType Directory -Force -Path build\web | Out-Null
& $alveolusGodot --headless --path . --export-release Web build/web/index.html
python -m http.server 8766 --bind 127.0.0.1 --directory build/web
```

Danach läuft das Spiel unter `http://127.0.0.1:8766/`. Der Browser darf nicht direkt über `file://` geöffnet werden, da WebAssembly über einen lokalen Webserver geladen werden muss.

Die aktuelle, ausdrücklich nicht für Production freigegebene DEV-Vorschau wird über GitHub Pages aus `docs/` veröffentlicht:

```text
https://drmilos33.github.io/MilosApps-Alveolus/
```

## Spielschleife

- Der Spielfluss lautet `Prolog → Campus → Fallarchiv → Briefing → Run → Ergebnis`; bestehende Spielstände beginnen direkt auf dem Campus.
- Der abendliche Campus ist das Hauptmenü und trennt Praxis, Forschung, Fallarchiv, medizinisches Lexikon und Einstellungen über fünf anklickbare isometrische Gebäude.
- Die Praxis sammelt bis zu acht Stunden automatische Forschung und bietet einen von drei zeitgesteuerten Klinikfällen mit exakter Rest- und Fertigstellungszeit.
- Fünf kompakte Forschungsknoten geben gedeckelte Werteboni, Startanalyse oder eine Upgrade-Neuauswahl.
- Das Intro besitzt keine Deadline. Drei kurze ereignisgesteuerte Lektionen erklären jeweils genau ein Antibiotika-, Immun- und Support-Upgrade; erst danach erscheint der Mini-Boss.
- Ein allgemeines Entdeckungssystem pausiert neue Gegner und Mechaniken bei ihrem ersten Auftreten, zeigt einen Pfeil samt medizinischer und spielerischer Erklärung und speichert sie im eigenen bebilderten Lexikon-Gebäude.
- Drei Hauptfälle dauern drei, vier und fünf Minuten. Der Infektionsherd erscheint jeweils nach 75 % der Levelzeit; die verbleibende Zeit ist die Deadline.
- Siege schalten genau den nächsten Fall frei. Freigeschaltete Fälle bleiben wiederholbar und speichern Siege, beste Zeit, höchste Analyse und höchste Erregerzahl.
- Besiegte Erreger hinterlassen Analyse. Eine volle Analyseleiste pausiert den Run und bietet drei eindeutige Upgrades.
- Alle vier Arenaränder sind verbunden. Avatar, Gegner, Projektile und Zielsuche verwenden über die Naht den kürzesten Weg.
- Gegner materialisieren sich vor der Aktivierung. Trefferzahlen, Trefferblitz, Todesanimation, Analyse-Schweif, Patientenwarnung und Bossphasen liefern direktes Feedback.
- Antibiotische Therapie verbessert automatische Angriffe.
- Immununterstützung ergänzt neutrophile Nahbereichsabwehr.
- Supportive Therapie stabilisiert den Patienten, verursacht aber keinen Erregerschaden.
- Der Run endet durch Kontrolle des Infektionsherds oder durch vollständigen Verlust der Patientenstabilität.
- Das Pausemenü bietet Fortsetzen, Einstellungen und einen bestätigten Levelabbruch ohne Belohnung.

Die Darstellung ist bewusst metaphorisch und enthält keine Dosierungen oder individuelle medizinische Beratung. Antibiotische Wirkungen sind in diesem Fall auf bakterielle Gegner begrenzt; Oxygenierung ist ausschließlich unterstützend modelliert.

## Architektur

- `scripts/core`: testbarer Run-Zustand, Levelrekorde, Flow-/Pausezustände, Entdeckungswarteschlange, Torus-Geometrie, Metafortschritt und Savegame-Migration
- `scripts/data`: zentrale Definitionen für Level, Arenaoptik, Run, Gegner, Entdeckungen, Upgrades, Klinikfälle und Forschung
- `scripts/entities`: Therapie-Avatar, Erreger, Projektile und Analyse-Pickups
- `scripts/ui`: isometrischer Campus, wiederverwendbare Objekt-/UI-Umrandung, Lexikon, Entdeckungstooltip, HUD, Briefing, Upgrade-Vorschauen, Pause und Abschlussbericht
- `scripts/game.gd`: Spielfluss, Spawnkurven, Zielwahl, Bossphasen und Verbindung der Subsysteme
- `tests/test_runner.gd`: 152 Headless-Prüfungen für Zustände, Leveldaten, Spawn, Bossphasen, Entdeckungen, Umrandungsgeometrie, Torus, kompakte Upgrade-Texte, Idle-Zeit, Forschung und Spielstände
- `tests/flow_runner.gd`: vollständiger Navigations-, Überspringen-, Abbruch-, Sieg-, Freischaltungs- und Wiederholungstest
- `tests/intro_runner.gd`: 15 Integrationsprüfungen für den echten Einstiegspfad aus Bewegung, automatischem Treffer und Analyseaufnahme sowie die drei Lektionen bis zum Mini-Boss
- `tests/performance_runner.gd`: Massentest mit 600 Gegnern und 1.200 Analyse-Drops; prüft Zeitbudget, werttreue Stapelung, Pool-Wiederverwendung und automatische Render-Bündelung

Die extern relevanten internen Schnittstellen sind `RunConfig`, `EnemyDefinition` und `UpgradeDefinition`. `RunState` meldet Stabilität, Analyse, Level-up, Bossphase und Run-Ende ausschließlich über Signale.

## Tests

Alle Logiktests:

```powershell
$alveolusGodotConsole = 'C:\Users\pasca\.cache\codex-runtimes\godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
& $alveolusGodotConsole --headless --path . --script res://tests/test_runner.gd
```

Vollständiger Menü- und Spielfluss:

```powershell
& $alveolusGodotConsole --headless --path . --script res://tests/flow_runner.gd -- --quick-run
```

Vollständiges ereignisgesteuertes Intro:

```powershell
& $alveolusGodotConsole --headless --path . --script res://tests/intro_runner.gd -- --quick-run
```

Kurzer Start-Smoke-Test:

```powershell
& $alveolusGodotConsole --headless --path . --quit-after 300 -- --auto-start --quick-run
```

Pause-Regressionslauf; prüft Gegnerposition, Run-Zeit und Therapie-Abklingzeit:

```powershell
& $alveolusGodotConsole --headless --path . -- --auto-start --pause-smoke
```

Beschleunigter vollständiger Run bis zum Infektionsherd:

```powershell
& $alveolusGodotConsole --headless --path . -- --auto-start --completion-smoke
```

Stresslauf mit mehr als 150 aktiven Gegnern:

```powershell
& $alveolusGodotConsole --headless --path . --quit-after 360 -- --auto-start --quick-run --stress-test
```

## Lokaler Fortschritt

Die Praxis speichert automatisch als Savegame-Version 3 unter `user://alveolus_save_v1.json`. Der Dateiname bleibt absichtlich bestehen, damit Version-1- und Version-2-Spielstände am selben Ort gefunden und migriert werden. Forschung, Ränge, Offline-Zeit, aktive Klinikfälle und Levelrekorde bleiben erhalten; Version 3 ergänzt Introstatus und spielstandweite Entdeckungen. Im Webexport liegt der Spielstand im lokalen Browserspeicher. Es gibt bewusst kein Konto, Backend oder geräteübergreifendes Speichern.

Die tatsächlich eingebundenen CC0-Dateien, Quellen, Versionen und lokalen Lizenzkopien sind in [`THIRD_PARTY_ASSETS.md`](THIRD_PARTY_ASSETS.md) dokumentiert.

## Bewusst noch nicht enthalten

Hosting, Cloud-Synchronisierung, Steam-/Android-Integration, Audio, finale Illustrationen, vollständige Storytexte, funktionale Einstellungen, weitere Krankheitsfälle und die stärkere spielerische Abgrenzung vom Survivors-Genre folgen erst nach dem Spieltest dieses Kerns.
