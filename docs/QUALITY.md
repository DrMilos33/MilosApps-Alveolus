# ALVEOLUS – Qualitäts- und Teststrategie

Ziel ist zuverlässige Entwicklung ohne reflexartig jede teure Prüfung nach
jeder kleinen Änderung auszuführen. Die Prüftiefe richtet sich nach dem
größten betroffenen Risiko, nicht nach der Anzahl geänderter Zeilen.

## Grundregel

1. Fehler oder gewünschtes Verhalten möglichst konkret reproduzieren.
2. Die kleinste betroffene Systemgrenze bestimmen.
3. Einen fokussierten Check ausführen und bei einem Bug einen Regressionstest
   ergänzen, sofern das Verhalten automatisierbar ist.
4. Nur bei breitem Einfluss zur nächsthöheren Stufe eskalieren.
5. Release-, Export- und Soak-Prüfungen niemals als Ersatz für gezielte Tests
   verwenden.

## Testprofile

Der Dispatcher `tests/run_checks.ps1` bündelt die üblichen Profile:

```powershell
& .\tests\run_checks.ps1 -List
& .\tests\run_checks.ps1 -Profile Quick
& .\tests\run_checks.ps1 -Profile Flow
& .\tests\run_checks.ps1 -Profile UI
& .\tests\run_checks.ps1 -Profile Combat
& .\tests\run_checks.ps1 -Profile Runtime
& .\tests\run_checks.ps1 -Profile Performance
& .\tests\run_checks.ps1 -Profile Full
```

`Full` ist die vollständige lokale Headless-Matrix mit kurzen Performancechecks.
Der fünfminütige Soak ist separat und wird nur mit `-FullSoak` aktiviert.

| Änderung | Standardprofil | Zusätzliche Prüfung |
|---|---|---|
| Dokumentation ohne Code oder IDs | `Docs` | Links und Inhalt gezielt lesen |
| Kleine isolierte Logik oder Daten | `Quick` oder einzelner Runner | Katalogtest, falls IDs betroffen sind |
| Navigation, Save, Einsatzplan oder Ergebnis | `Flow` | betroffenen Ablauf manuell öffnen |
| UI, Textfluss, Fokus, Skalierung oder Eingaben | `UI` | visuelle Zielauflösung beziehungsweise Screenshot |
| Behandlung, Fähigkeit, Passiv, Talent oder Upgrade | `Combat` | echte Spielsituation kurz prüfen |
| Entity, Pool, Query, Tick, Renderer oder Pause | `Runtime` | kurzer nativer Lastlauf bei Darstellungscode |
| Performance- oder Kapazitätsänderung | `Performance` | native Rendertelemetrie; Browser nur bei Webrisiko |
| Mehrere Systemgrenzen oder Releasekandidat | `Full` | Webexport und End-to-End-Smoke |
| Pool-, MultiMesh- oder Langzeitstabilität | `Runtime` und `Performance -FullSoak` | fünfminütiger Browser-Soak bei Webfreigabe |

Mehrere kleine Profile dürfen kombiniert werden. Ein Textfix im Lexikon
benötigt beispielsweise keinen Renderer-Soak; eine Änderung an
`scripts/game.gd` benötigt nicht automatisch alle UI-Screenshotgrößen, wenn
sie ausschließlich einen isolierten Kampfeffekt anbindet.

## Serielle Ausführung

In einem Checkout läuft höchstens ein Godot-Test-, Import-, Editor- oder
Exportprozess gleichzeitig. Parallele Godot-Prozesse können `.godot`-Importe,
temporäre Reports und Renderressourcen gegenseitig beeinflussen. Read-only
Codeaudits und getrennte Dateiarbeiten dürfen parallel stattfinden.

## Manuelle Smokes

Manuelle Prüfung ergänzt Automatisierung dort, wo Wahrnehmung zählt:

- UI: Hierarchie, Lesbarkeit, Fokus, Hover, zentrierte Icons und Textüberlauf.
- Kampf: Fähigkeit ist sichtbar, verständlich und entspricht ihrer Geometrie.
- Audio: Cue ist hörbar, nicht aufdringlich und respektiert Bus und Stummschaltung.
- Performance: keine sichtbaren Geisterbilder, Pop-ins oder rhythmischen Hänger.
- Web: nicht über `file://` öffnen; Export immer über einen lokalen HTTP-Server testen.

## Wann die vollständige Suite nötig ist

`Full` plus relevante visuelle oder Browser-Smokes ist erforderlich bei:

- Saveversion oder Migration;
- stabilen Content-IDs oder projektweiter Katalogstruktur;
- Fixed-Step-Reihenfolge, Handle- oder Pool-Lebenszyklus;
- globaler Eingabe- oder Projekteinstellung;
- breitem Umbau von `scripts/game.gd` oder `scripts/ui/game_hud.gd`;
- Webexport, Veröffentlichung oder neuem spielbaren Meilenstein.

Ein vollständiger Soak ist zusätzlich erforderlich, wenn Pooling, Kapazitäten,
MultiMesh, Interpolation, Speicherentwicklung oder langfristige Last berührt
wurden. Die genauen Last- und Framebudgets stehen in
[`PERFORMANCE_BUDGET.md`](PERFORMANCE_BUDGET.md).

## Ergebnisbericht

Ein Abschluss nennt immer:

- was sich für den Spieler oder Entwickler geändert hat;
- welche Profile oder Einzelrunner ausgeführt wurden;
- welche größere Prüfung bewusst nicht nötig war;
- offene Abnahmen, die auf anderer Hardware oder im Browser erfolgen müssen.

Eine bestandene Headless-Prüfung ist kein Beleg für visuelle Qualität oder
GPU-/Browserleistung. Solche Aussagen benötigen den passenden sichtbaren Lauf.
