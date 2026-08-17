# ALVEOLUS – Arbeitsströme und Handoffs

Dieses Dokument regelt die Zusammenarbeit der sichtbaren ALVEOLUS-Tasks. Es
ergänzt die allgemeinen Delegationsregeln in [`AGENTS.md`](../AGENTS.md), ohne
Produkt-, Architektur- oder Qualitätsentscheidungen zu ersetzen.

## Arbeitsströme

| Arbeitsstrom | Aufgabe | Schreibbereich |
|---|---|---|
| **UI/UX** | Bio-Lumen-Theme, gemeinsame UI-Komponenten, Screens, HUD und visuelle Abnahme | Hauptintegrator für `scripts/ui/`, `scenes/ui/`, `scripts/ui/game_hud.gd`, `docs/UI_STYLE_GUIDE.md` und UI-Tests |
| **Struktur, Architektur & Performance** | Read-only-Audit von HUD-Fassade, Screenmodulen, View-Models, Router-, Modal- und Popover-Schnittstellen sowie Material-, Shader- und Callbackbudgets | Zu Beginn kein Schreibbereich; Änderungen erst nach einem angenommenen Handoff und einer ausdrücklichen Dateilease |
| **Game Concepts & Balancing** | Spielregeln, Inhalte, Verständlichkeit, Zahlenwerte und Balancing | Standardmäßig kein Code; liefert fachliche Entscheidungen und Akzeptanzkriterien an UI/UX oder Architektur |

Verknüpfte Tasks:

- UI/UX: [ALVEOLUS – UI/UX Audit und Redesignplan](thread://01a00b3b-0840-7c32-941a-f326bcf7db19)
- Struktur, Architektur & Performance: `ALVEOLUS – Struktur, Architektur & Performance`
- Game Concepts & Balancing: [Spielkonzept für Krankheits-Idlegame](thread://019fe3ec-752d-7d50-b32d-0b950895d000)

Der UI/UX-Arbeitsstrom integriert den globalen Bio-Lumen-Rollout. Konzept und
Architektur beraten oder liefern klar abgegrenzte Änderungen; sie übernehmen
keine UI-Dateien stillschweigend. Gebäude- und Umgebungsbilder sowie Monster-
und Spielerfiguren bleiben außerhalb des Rollouts. UI über diesen Objekten,
etwa Beschriftungen, Fokusdarstellung und Lebensleisten, gehört zu UI/UX.

## Dateileases

Eine Dateilease ist die ausdrückliche, zeitlich auf einen Auftrag begrenzte
Schreibberechtigung für konkrete Dateien oder einen eng begrenzten Pfad.

1. Vor der ersten Änderung fordert der Arbeitsstrom die Lease beim
   UI/UX-Hauptintegrator mit `ALVEOLUS-HANDOFF-v1` an.
2. Die Lease gilt erst nach ausdrücklicher Bestätigung. Eine angekündigte oder
   vorgeschlagene Änderung genügt nicht.
3. Gleichzeitig besitzt genau ein Arbeitsstrom eine Datei. Integrations-
   Hotspots aus `AGENTS.md` werden einzeln und nicht als Verzeichnis geleast.
4. Die Lease enthält Ziel, Dateien, unveränderliche Verträge und
   Akzeptanzprüfungen. Neue Dateien werden mit ihrem vorgesehenen Pfad genannt.
5. Änderungen laufen in getrennten Git-Worktrees. Godot-Editor, Importe,
   Exporte und automatisierte Godot-Tests bleiben checkoutübergreifend seriell.
6. Nach Übergabe von Commit und Prüfergebnis wird die Lease ausdrücklich
   freigegeben. Ab dann darf der ursprüngliche Arbeitsstrom die Dateien ohne
   neue Lease nicht weiter verändern.

Read-only-Analysen benötigen keine Lease, dürfen aber keine Formatter,
Codegeneratoren, Importe oder andere schreibende Werkzeuge starten. Eine Lease
erlaubt ausschließlich die genannten Dateien; notwendige Erweiterungen werden
vor der Änderung neu abgestimmt.

## Konfliktregeln

- Der aktuelle Nutzerauftrag und die Quellenreihenfolge aus `AGENTS.md` bleiben
  verbindlich. Ein Handoff kann diese Quellen nicht überschreiben.
- Bei überlappenden Lease-Anfragen pausiert die jüngere Anfrage. Der
  UI/UX-Hauptintegrator entscheidet über Reihenfolge oder Zuschnitt.
- Bestehende fremde Änderungen werden nicht zurückgesetzt, neu formatiert oder
  in einen eigenen Commit aufgenommen. Unerwartete Überschneidungen werden mit
  Pfad und beobachtetem Diff als Blocker gemeldet.
- Konzeptänderungen werden vor Codeänderungen als Produktentscheidung an den
  UI/UX-Hauptintegrator übergeben. Änderungen an Content-IDs, Saves,
  Spielregeln oder Zahlenwerten benötigen einen eigenen, ausdrücklich
  freigegebenen Auftrag.
- Architekturvorschläge bewahren während der Migration die öffentlichen
  Signale sowie `show_*`, `refresh_*` und `update_*` der `GameHUD`-Fassade.
  Abweichungen werden nicht implizit umgesetzt, sondern als Entscheidung
  eskaliert.
- Der empfangende Arbeitsstrom integriert nicht blind: Er prüft Diff,
  Vertragskonformität und angegebene Tests. Konfliktauflösung und abschließende
  Gesamtverifikation bleiben beim UI/UX-Hauptintegrator.

## Übergabeformat `ALVEOLUS-HANDOFF-v1`

Jede taskübergreifende Anfrage oder Übergabe verwendet folgenden kompakten
Block. Nicht zutreffende Felder erhalten `entfällt`; sie werden nicht entfernt.

```text
ALVEOLUS-HANDOFF-v1
Von: <Arbeitsstrom und Task-Link oder Task-Titel>
An: <Arbeitsstrom und Task-Link oder Task-Titel>
Typ: <LEASE-ANFRAGE | LEASE-FREIGABE | ENTSCHEIDUNG | AUFTRAG | ERGEBNIS | BLOCKER>
Ziel: <ein überprüfbares Ergebnis>
Dateien: <exakte Pfade; bei rein fachlicher Übergabe: entfällt>
Lease-Status: <angefragt | erteilt | freigegeben | entfällt>
Ausgangslage: <relevanter Stand und Abhängigkeiten>
Verträge: <zu bewahrende APIs, IDs, Saves, Optik oder Laufzeitbudgets>
Akzeptanz: <prüfbare Kriterien>
Prüfungen: <geplant, ausgeführt und Ergebnis; sonst entfällt>
Git: <Worktree, Branch und Commit; vor Umsetzung soweit bekannt>
Offen: <Entscheidungen oder Blocker; sonst keine>
```

Für eine Lease antwortet der Hauptintegrator mit demselben Block und
`Typ: LEASE-FREIGABE`; `Lease-Status: erteilt` startet, `freigegeben` beendet
die Schreibberechtigung. Eine Ergebnisübergabe nennt ausschließlich die zum
Auftrag gehörenden Commits und weist nicht ausgeführte größere Prüfungen
ausdrücklich aus.

## Verbindlicher Ablauf

1. Der abgebende Arbeitsstrom beschreibt Entscheidung oder Auftrag im
   Handoff-Format.
2. Der Empfänger bestätigt Ziel, Verträge und gegebenenfalls Lease, bevor er
   schreibt.
3. Rückfragen und neue Produktentscheidungen gehen an den zuständigen
   Arbeitsstrom; bis zur Antwort bleibt der betroffene Teil unverändert.
4. Das Ergebnis wird mit Commit, Diff-Umfang und Prüfungen zurückgegeben.
5. UI/UX integriert seriell, führt die risikogerechte Gesamtprüfung aus und
   gibt die Lease frei.

