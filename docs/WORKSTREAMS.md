# ALVEOLUS – temporäre Tasks, Leases und Handoffs

Dieses Dokument regelt die Zusammenarbeit für einen konkreten Slice. Es
ergänzt [`AGENTS.md`](../AGENTS.md), ohne Produkt-, Architektur- oder
Qualitätsentscheidungen zu ersetzen. ALVEOLUS verwendet keine dauerhaften
Thread-IDs und keinen dauerhaft festgelegten UI- oder Architekturintegrator.

## Ein Task, ein Ergebnis

- Für jedes unabhängig prüfbare Ergebnis existiert ein temporärer Haupttask.
- Plan, Goal, Umsetzung und fokussierte Verifikation bleiben im selben Task.
- Produktentscheidungen und Architekturreviews liefern read-only zu. Sie
  besitzen keine Produktionsdateien, solange keine ausdrückliche Lease erteilt
  wurde.
- Der Slice benennt einen Integrator. Diese Rolle endet mit der Integration und
  geht nicht automatisch auf den nächsten Slice über.
- Gleichzeitig schreibt genau ein Besitzer an einer Datei. Renderer, Worlds,
  Entity-Lifecycle und Performance bleiben ein gemeinsames serielles Paket.
- Abgeschlossene Tasks werden nach bestätigtem Handoff archiviert. Sie werden
  nicht als langfristige Wissensquelle weitergeführt.

Der wiederholbare Ablauf steht im Repository-Skill
`.agents/skills/alveolus-change-workflow/SKILL.md`.

## Rollen pro Slice

| Rolle | Verantwortung | Schreibrecht |
|---|---|---|
| **Slice-Integrator** | Baseline, Leases, Integration, finale risikogerechte Prüfung | ausschließlich die im Slice genannten Hotspots und Integrationsdateien |
| **Produktreview** | Regeln, Verständlichkeit, Balance und Akzeptanzkriterien | standardmäßig read-only |
| **Architekturreview** | Abhängigkeiten, Runtimeverträge, Risiken und Performancehypothesen | standardmäßig read-only |
| **Modul-Writer** | eine klar abgegrenzte, unabhängig integrierbare Änderung | nur die ausdrücklich geleasten Dateien |

Mehrere sichtbare Tasks sind nur sinnvoll, wenn ihre Ergebnisse unabhängig
sind. Unteragenten sind für begrenzte parallele Audits vorzuziehen; sie erhalten
keine Vollhistorie.

## Lokale Basis und Dateileases

Vor Produktionsänderungen werden Branch, exakter HEAD, Dirty-State und
relevante lokale Berichte geprüft. Ein fremder oder breiter Dirty-State wird
zuerst als eigener lokaler `BASELINE_READY`-Commit gesichert. Kein älterer
Worktree ersetzt diese Basis.

Eine Lease enthält:

1. das überprüfbare Ziel;
2. die exakten bestehenden und neuen Pfade;
3. den einzigen Writer beziehungsweise Integrator;
4. zu bewahrende Signale, IDs, Saves, Reihenfolgen und Budgets;
5. die fokussierten Abnahmetests.

Read-only-Audits benötigen keine Lease, starten aber keine Formatter,
Codegeneratoren, Importe, Godot-Prozesse oder sonstigen schreibenden Werkzeuge.
Eine notwendige Scope-Erweiterung wird vor der Änderung explizit festgehalten.

Lokale Branches, Worktrees, Commits, Builds und an `127.0.0.1` gebundene Smokes
sind erlaubt. Push, Upload, Deployment, PR und Release bleiben durch die
projektlokale Policy gesperrt. Ausschließlich ein separater Release-Task darf
mit vollständigem HEAD und `ALVEOLUS-RELEASE-v1 <SHA> origin/dev` den
einmaligen Releasewrapper ausführen. Entwicklungshandoffs verwenden immer
`Remote: keine`; ein Releasehandoff nennt stattdessen das exakt verifizierte
Remoteziel und den übertragenen Commit.

## Taskgröße und Medien

- Unter 20 MiB lokaler Sessiondatei läuft der Task normal weiter.
- Ab 20 MiB wird der aktuelle kleinste Slice beendet und ein textbasierter
  Rollover vorbereitet.
- Ab 40 MiB sind normale Prompts gesperrt. Ein Prompt, der mit
  `ALVEOLUS-ROLLOVER` beginnt, erzeugt ausschließlich den kompakten Handoff für
  einen neuen Task.
- Rohlogs, Benchmark-JSON und Capturelisten liegen unter
  `.codex-temp/reports/<slice>/`.
- GIF-Originale und aufbereitete Belege liegen unter
  `.codex-temp/evidence/<case>/`. In Tasks erscheinen nie animierte GIFs,
  sondern höchstens Kontaktblatt beziehungsweise ausgewählte Frames mit
  Zeitmarke und Beobachtungsauftrag. Der aufbereitete Medienkontext ist auf
  sechs Bilder und 8 MiB begrenzt.
- Bereits übergroße Tasks werden archiviert, nicht gelöscht. Eine
  Speicherbereinigung ist ein eigener freizugebender Auftrag.

## `ALVEOLUS-HANDOFF-v2`

Der Handoff enthält nur die Informationen, die der nächste Task zum sicheren
Fortsetzen braucht. Nicht zutreffende Felder verwenden `entfällt`.

```text
ALVEOLUS-HANDOFF-v2
Ergebnis/Status: <prüfbares Ergebnis und READY | BLOCKED | INTEGRATED>
Basis: <Worktree, Branch, exakter Ausgangscommit>
Lokaler Commit: <exakte Commit-ID oder entfällt>
Dateilease: <Writer sowie exakte Pfade; bei read-only: entfällt>
Geänderte Verträge: <APIs, IDs, Save-, Reihenfolge-, Optik- oder Budgetvertrag>
Prüfungen: <ausgeführt und Ergebnis; bewusst ausgelassene größere Matrix>
Lokale Artefakte: <Pfade unter .codex-temp oder lokaler Build; sonst entfällt>
Offen: <nächste Entscheidung, manuelle Abnahme oder Blocker; sonst keine>
Remote: <bei Entwicklung: keine; bei explizitem Release: verifiziertes Ziel und SHA>
```

Nicht enthalten sind wiederholte Projekthistorie, Medien, vollständige Logs,
Capturelisten oder fremde Commitketten.

## Verbindlicher Ablauf

1. Auftrag und Quellen der Wahrheit einer Risikoklasse zuordnen.
2. Git-/Worktree-/Dirty-State prüfen und eine exakte lokale Baseline nennen.
3. Read-only planen; Produkt- und Architekturfragen als klar begrenzte
   Zulieferung klären.
4. Integrator, Writer und Dateilease festlegen.
5. Im selben fokussierten Task umsetzen und den kleinsten Check zuerst
   ausführen. Godot bleibt checkoutübergreifend seriell.
6. Diff, Status, Verträge und Messbelege prüfen; lokal committen.
7. `ALVEOLUS-HANDOFF-v2` senden, Integration bestätigen und den Task
   archivieren.

Bei Konflikten gilt weiterhin die Quellenreihenfolge aus `AGENTS.md`. Ein
Handoff kann keine Nutzerentscheidung, stabile ID, Save-Kompatibilität oder
Runtime-Invariante stillschweigend überschreiben.
