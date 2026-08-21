# ALVEOLUS – Arbeitsregeln

Diese Datei ist der dauerhafte Arbeitsvertrag für Codex und andere Agenten in
diesem Repository. Sie bleibt bewusst kurz. Fachdetails stehen in den
verlinkten Projektdokumenten.

## Quellen der Wahrheit

Bei Widersprüchen gilt diese Reihenfolge:

1. der aktuelle Auftrag des Nutzers;
2. `docs/PROJECT.md` für Status, Prioritäten und dauerhafte Entscheidungen;
3. `docs/ARCHITECTURE.md` für Laufzeit- und Ownership-Verträge;
4. `docs/QUALITY.md` für die erforderliche Prüftiefe;
5. `docs/UI_STYLE_GUIDE.md` für sichtbare Oberflächen;
6. `THIRD_PARTY_ASSETS.md` für Herkunft und Lizenzen.

Spezialisierte Referenzen wie `docs/ABILITY_PIPELINE.md`,
`docs/PERFORMANCE_BUDGET.md`, `docs/CAMPUS_EDITOR.md` und
`docs/WORKSTREAMS.md` für taskübergreifende Dateileases und Handoffs ergänzen
diese Quellen, ersetzen sie aber nicht.

## Arbeitsweise

- Erst den Auftrag einer Risikoklasse in `docs/QUALITY.md` zuordnen. Nur die
  dafür nötigen Dateien lesen und nur die dazugehörigen Prüfungen ausführen.
- Kleine, klar begrenzte Änderungen direkt umsetzen. Erst bei mehreren
  Systemen, unscharfen Produktentscheidungen, Save-Migrationen oder hohem
  Regressionsrisiko ausführlich planen.
- Bestehende Nutzeränderungen bleiben erhalten. Keine fremden Änderungen
  zurücksetzen, bereinigen oder neu formatieren.
- Dauerhafte Produkt- oder Architekturentscheidungen in `docs/PROJECT.md`
  nachtragen. Einzelne Bugfixes und Testresultate gehören nicht in den
  Entscheidungslog.
- Statusdokumente nur bei einer echten Meilenstein- oder Prioritätsänderung
  aktualisieren. Keine Dokumentationspflicht für triviale lokale Korrekturen.
- Entwicklung bleibt lokal. Nicht veröffentlichen, Hosting aktualisieren,
  Spielstände löschen oder den PC herunterfahren, sofern der Nutzer das nicht
  ausdrücklich in seinem aktuellen Auftrag verlangt.
- Wiederholbare Änderungen folgen dem Repository-Skill
  `.agents/skills/alveolus-change-workflow/SKILL.md`. Ein Task besitzt genau
  ein überprüfbares Ergebnis; Plan und Umsetzung bleiben zusammen, solange der
  lokale Transcript-Warnwert keinen textbasierten Rollover verlangt.
- Rohlogs, Capturelisten und Messdateien gehören unter
  `.codex-temp/reports/`, nicht in den Task. Animierte GIFs niemals direkt in
  einen Task einbetten; der Workflow-Skill erzeugt höchstens sechs PNG-Frames,
  ein Kontaktblatt und ein Textmanifest unter `.codex-temp/evidence/`.
- Die projektlokalen Hooks unter `.codex/` sperren Remote-Schreibvorgänge und
  übergroße Tasks. Sie sind ein Unfall-Guardrail; eine Veröffentlichung
  benötigt einen eigenen Releaseauftrag und eine bewusst aktivierte
  Releasekonfiguration.

## Delegation und Parallelität

- Der Hauptagent integriert. Unteragenten erhalten eine konkrete, unabhängige
  Teilaufgabe und eine explizite Liste eigener Dateien.
- Gleichzeitig laufen höchstens zwei Unteragenten. Sie starten mit
  `fork_turns="none"` und einem vollständigen Kurzbriefing; Vollhistorie-Forks
  sind in diesem Repository verboten.
- Pro Datei gibt es gleichzeitig genau einen schreibenden Besitzer.
- Read-only-Audits, Assetrecherche und getrennte Module dürfen parallel laufen.
  Godot-Editor, Importe, Exporte und automatisierte Godot-Tests laufen im
  gemeinsamen Checkout seriell.
- Folgende Integrations-Hotspots bearbeitet nur der Hauptagent oder ein einziger
  ausdrücklich benannter Integrator:
  `scripts/game.gd`, `scripts/ui/game_hud.gd`,
  `scripts/data/content_catalog.gd`,
  `scripts/core/meta_progression_state.gd`,
  `scripts/core/player_stats.gd`, `scripts/core/run_session.gd`,
  `project.godot`, `export_presets.cfg`, Hauptszenen und zentrale Teststarter.
- Renderer, Worlds, Entity-Lifecycle und Performance bilden ein gemeinsames
  Paket. Diese Dateien nicht auf mehrere gleichzeitig schreibende Agenten
  verteilen.
- Mehrere sichtbare Chats verwenden nur für wirklich unabhängige Ergebnisse.
  Parallele Codeänderungen gehören in getrennte Git-Worktrees; die abschließende
  Integration und Verifikation bleibt seriell.

## Technische Leitplanken

- Godot 4.7.1 Standard, GDScript und Compatibility-Renderer bleiben gesetzt.
- Masseneinheiten erhalten keine eigenen dauerhaften Prozessschleifen. Worlds,
  generationssichere Handles, `CombatQuery` und die feste `RunSession`-Reihenfolge
  bleiben die verbindliche Laufzeitarchitektur.
- Dynamische MultiMeshes verwenden CPU-Snapshots und `set_buffer()`.
  Engine-seitige MultiMesh-Physikinterpolation und
  `set_buffer_interpolated()` sind auf diesem Zielsystem verboten.
- Gameplaykritische Anzeigen dürfen durch Qualitätsstufen nie verschwinden.
- UI verwendet `AlveolusVisualTheme`, wiederverwendbare Komponenten, sichtbaren
  Fokus und zentrierte Icon-Text-Einheiten. Keine neuen lokalen Style-Kopien,
  wenn eine semantische Theme-Variante ausreicht.
- Gebäude, Gegner und Charaktere stammen aus dokumentierten Assets oder aus
  Zeichnungen des Nutzers. Dafür kein ImageGen verwenden.
- Stabile Content-IDs und Save-Kompatibilität nicht ohne explizite Migration
  ändern.

## Verifikation und Abschluss

- Den kleinsten passenden Check aus `docs/QUALITY.md` beziehungsweise
  `tests/run_checks.ps1` wählen. Die Full-Suite ist kein Standard für kleine
  Änderungen.
- Ein reproduzierter Fehler erhält nach Möglichkeit einen fokussierten
  Regressionstest. Performancebehauptungen benötigen einen echten Messlauf;
  Headless-Zeit ist kein Browser- oder GPU-Nachweis.
- Vor Übergabe den eigenen Diff auf unbeabsichtigte Änderungen prüfen.
- Im Abschluss knapp nennen: Ergebnis, geänderte Bereiche, ausgeführte Checks
  und bewusst nicht ausgeführte größere Prüfungen.
