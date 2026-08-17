# ALVEOLUS – Projektstand

Letzte inhaltliche Aktualisierung: 17. August 2026

Dieses Dokument ist die einzige veränderliche Quelle für Produktstatus,
Prioritäten, bekannte Grenzen und dauerhafte Entscheidungen. Technische
Details stehen in den verlinkten Spezialdokumenten.

## Produktziel

ALVEOLUS ist ein zugängliches taktisches 2D-Actionspiel mit Idle-Metaspiel.
Der Spieler leitet eine medizinische Abteilung, plant einen Einsatz und
kontrolliert in stilisierten Lungenmodellen bakterielle Infektionen. Medizin
liefert Bedeutung und Lernwert, soll die Bedienung aber nicht mit Fachsprache
überladen.

Die langfristige Eigenständigkeit gegenüber klassischen Survivors-Spielen
entsteht durch:

- einen begrenzten Behandlungsplan vor jedem Fall;
- zwei bewusst eingesetzte aktive Fähigkeiten;
- Fallmerkmale, Befunde und Reaktionen während des Runs;
- Forschung als Freischaltung neuer Optionen statt endloser Stärke;
- zufällige Run-Ausbaustufen, die mit dem vorbereiteten Plan interagieren.

## Aktuell spielbarer Stand

- Vollständiger lokaler Ablauf:
  `Prolog → Campus → Fallarchiv → Einsatzplanung → Run → Ergebnis`.
- Vier wiederholbare Fälle einschließlich ereignisgesteuertem Intro und Bossen.
- Einsatzplan mit einer Grundbehandlung, zwei aktiven Fähigkeiten und zwei
  Passivmodulen. Die technisch weiterhin kompatible Reserve ruht vorerst.
- Drei Behandlungen, sechs aktive Fähigkeiten, neun Passivmodule, zwölf
  Talente und katalogisierte Run-Ausbaustufen.
- Praxis mit Offline-Forschung und Klinikfällen, Forschungsbrett, Talente,
  Meisterschaft, kategorisiertes Lexikon und lokale Savegame-Version 5.
- Maus, Tastatur und Gamepad, UI-Sounds, Audioeinstellungen, UI-Skalierung von
  75 bis 200 Prozent,
  reduzierte Bewegung und anpassbare Eingaben.
- Zusammenhängendes dunkles Dossier-UI mit sicherer Kopfzone, slotorientierter
  Einsatzplanung, kompaktem Kampf-HUD und responsiven Dialogen bis 200 Prozent.
- Stabile Massendarstellung mit gepoolten Worlds, festen Render-Slots und
  automatischer Reduktion ausschließlich kosmetischer Effekte.

## Aktueller Arbeitsmodus

**Jetzt:** Den aktuellen lokalen Build als zusammenhängendes Spiel testen und
konkretes Feedback zu Bedienung, Verständlichkeit, Fähigkeiten und Spielfluss
sammeln. Bestätigte Fehler werden zuerst reproduziert und gezielt behoben.

Für diesen Systemtest sind Forschung und Talentpunkte absichtlich unbegrenzt.
Balancingentscheidungen werden erst getroffen, nachdem alle Grundsysteme
verständlich und zuverlässig funktionieren.

Die Entwicklung bleibt lokal. Die GitHub-Pages-Version ist ein eingefrorener
älterer Vergleichsstand und wird nur nach ausdrücklicher Freigabe aktualisiert.

## Danach

1. Spieltestfehler und UX-Reibung priorisiert beheben.
2. Grundbehandlungen, Fähigkeiten, Befunde und Talente spielerisch balancieren.
3. Fälle stärker voneinander unterscheiden und die Abgrenzung zum
   Survivors-Grundmuster ausbauen.
4. Story, Texte, Audio und visuelle Details auf einen konsistenten
   Produktionsstand bringen.
5. Erst danach einen neuen teilbaren Web-Meilenstein freigeben.

## Später

- weitere Krankheitsfälle und Bosse;
- ausgebaute Praxis- und Idle-Progression;
- Windows-/Steam- und Android-Anpassungen;
- Hosting, Telemetrie oder Cloud-Synchronisierung nur als eigene Meilensteine.

## Bekannte Grenzen und offene Abnahmen

- Namen, Zahlenwerte und Schwierigkeitskurven sind teilweise noch Platzhalter.
- Vollständige Storytexte, Musik und finales Sounddesign fehlen bewusst.
- Das responsive UI ist automatisiert geprüft; 200 Prozent Skalierung auf sehr
  kleinen Ansichten verwendet stellenweise Scrollflächen statt eigener
  Einspaltenvarianten.
- Die Leistungsziele sind auf dem Entwicklungs-PC nativ und im lokalen Browser
  geprüft. Eine separate Abnahme auf dem definierten Mittelklasse-Referenz-PC
  bleibt offen.
- Der aktuelle Arbeitsbaum enthält einen großen zusammenhängenden lokalen
  Meilenstein. Vor einer neuen breiten Featurephase ist ein geprüfter
  Git-Checkpoint sinnvoll, wird aber nicht ohne Auftrag erstellt.

## Dauerhafte Entscheidungen

| ID | Entscheidung |
|---|---|
| D-001 | Godot 4.7.1 Standard, GDScript und Compatibility-Renderer bleiben die technische Basis. |
| D-002 | Lokale Entwicklung ist der Standard. Veröffentlichungen benötigen eine ausdrückliche Freigabe. |
| D-003 | Gebäude, Gegner und Charaktere stammen aus dokumentierten Assets oder Nutzerzeichnungen, nicht aus ImageGen. |
| D-004 | Einfache Spielbegriffe stehen im Kampf; Fachbegriffe und medizinischer Hintergrund liegen in Tutorial und Lexikon. |
| D-005 | Forschung schaltet Optionen frei. Ein festes Planbudget erzwingt Entscheidungen, ohne gekaufte Inhalte zu verlieren. |
| D-006 | Savegame-Migrationen bewahren Fortschritt und stabile Content-IDs. Der aktuelle Stand ist Version 5. |
| D-007 | Masseneinheiten besitzen einen stabilen, generationssicheren Render- und Pool-Lebenszyklus ohne Schwellenwechsel. |
| D-008 | UI folgt dem zentralen Theme, einer klaren Hauptaktion, konsistenter Rücknavigation und gleichwertiger Maus-, Tastatur- und Gamepadbedienung. |
| D-009 | Verifikation ist risikobasiert. Full-Suite, Export und Soak laufen nur bei breiten, laufzeitkritischen oder veröffentlichungsnahen Änderungen. |
| D-010 | Ein Hauptchat integriert. Unabhängige Unteraufgaben dürfen parallel laufen, aber pro Datei existiert nur ein schreibender Besitzer. |
| D-011 | Die sichtbare ALVEOLUS-Sprache ist ein dunkles medizinisches Einsatzdossier. Semantische Petrolflächen ersetzen generische weiße Kachelwände; große Flächen erhalten keine überzeichneten ausgesparten Ecken. |
| D-012 | Einsatzplanung ist platzorientiert: zuerst Platz, dann gefilterte Komponente, bei Ersatz eine explizite Gegenüberstellung. Ein Komponenten-Klick bestimmt nie implizit den Zielplatz. |
| D-013 | Optionale Run-Statistik zeigt oben rechts höchstens fünf transparente Paare aus Icon und Wert. Überschriften, Erklärungen und weitere Werte liegen ausschließlich in der Pause. |
| D-014 | Maus-Hover ist still. UI-Sounds bestätigen semantische Ereignisse; Fokus-Sound entsteht nur durch echte Tastatur- oder Gamepadnavigation. |
| D-015 | Seiten verwenden 24/16 Pixel Außenabstand, 76/60 Pixel Kopfzonen und 20/12 Pixel Abstand zum Inhalt. Interaktive Ziele sind mindestens 44 Pixel groß. |
| D-016 | Normale Flächen und kurze Dialoge folgen ihrer Inhaltshöhe statt Leerraum zu reservieren. Forschung und Talente verwenden kompakte responsive Icon-Bretter mit einem gemeinsamen Hover-/Fokusinspektor. |
| D-017 | Der Einsatzplan nutzt im Übersichtsmodus die volle Breite. Beim Bearbeiten bleiben Zielplatz und aktueller Inhalt fest sichtbar; ein responsiver 2/1-Spalten-Katalog trennt verfügbare, anderweitig belegte und gesperrte Alternativen redundant und endet in genau einem Vergleich. |
| D-018 | Fokus und Hover verändern niemals die Geometrie eines Controls. Fokusrahmen bleiben innerhalb der Layoutzelle; Seiten- und Campusheader besitzen nur lokale Zeichenebenen und können keine später geöffnete Oberfläche übermalen. |
| D-019 | Ersetzt den Übersichtsmodus aus D-017: Die Einsatzplanung öffnet direkt den Behandlungsplatz im Komponentenpicker. Alle fünf Planplätze und der Editor bleiben Teil derselben responsiven Ansicht; Anwenden oder Entfernen hält den gewählten Platz aktiv. Die Reserve bleibt in Save- und Laufzeitadaptern kompatibel, ist aber bis zu einer späteren Produktentscheidung unsichtbar und in neuen Plänen leer. |
| D-020 | Präzisiert D-013: Optionale Run-Werte füllen den freien Raum zwischen Timer und rechtem Rand als transparentes horizontales `Icon + Wert`-Band und umbrechen erst bei Platzmangel in eine zweite Zeile. |
| D-021 | Ersetzt den flachen Talentteil aus D-016: Talente bilden drei sichtbare, verzweigte Äste mit verbindlichen Voraussetzungen und topologischer Tastatur-/Gamepadnavigation. Eine additive Baumrevision erstattet alte Auswahlen vollständig, ohne Meisterschaften oder verdiente Punkte zu verlieren. |
| D-022 | Dokumentseiten besitzen genau einen Seitentitel mit definiertem Abstand zum Icon. Falldaten erscheinen als kompakte transparente Fakten mit semantischen Farben; beschädigte gebatchte Gegner erhalten ihre Lebensanzeige aus dem zuständigen Renderer statt aus versteckten Entity-Nodes. |
| D-023 | Bei geringer logischer Höhe bleiben Progressionstabs und ein kompakter Fokusinspektor sichtbar; Summary und Brett beziehungsweise Baum teilen eine fokusfolgende Scrollfläche. Baumkanten besitzen ausdrückliche D-Pad-Ausgänge zu Tabs und Nachbarästen. Ein aktiver Talent-Elternknoten kann erst nach seinen aktiven Nachfolgern zurückgesetzt werden. |
| D-024 | Der temporäre unbegrenzte Fortschrittsmodus wird vor dem Laden konfiguriert. Aktuelle Talentbäume werden immer gegen Topologie und den aktiven Economy-Modus validiert; ein später im Normalmodus überteuerter Testbaum wird vollständig mit Refund-Hinweis geleert. |
| D-025 | Die Dossier-Sprache entwickelt sich zu „Bio-Lumen · lebendige Membran“ weiter: ruhige organische Tiefen, feine Zell- und Kapillarspuren sowie ein schwacher rollenreiner Teal-Verlauf auf Primäraktionen. Honiggold bleibt Fokus und Belohnung vorbehalten und wird nicht als Primary-Gradient eingesetzt. |
| D-026 | Ersetzt den Bestätigungs- und Anwenden-Schritt aus D-012, D-017 und D-019; deren ausdrückliche Platzwahl bleibt verbindlich. Danach ersetzt ein zulässiger Komponenten-Klick den Inhalt direkt und atomar. Der gewählte Platz bleibt aktiv, sodass Wechsel oder Entfernen unmittelbar reversibel sind. Im Intro ist der gesamte Plan schreibgeschützt und als gesperrter Bereich mit Schloss gekennzeichnet. |
| D-027 | Ersetzt den permanent sichtbaren Inspektor-Anteil aus D-023: Ausführliche kontextuelle Details erscheinen bei Hover und Fokus als zugängliches Popover statt als permanente Textwand. Medizinische Einordnung und Spielwirkung bleiben darin beziehungsweise in Detailansichten als zwei semantisch getrennte Flächen erkennbar. |
| D-028 | `Strg+R` startet den laufenden oder pausierten Fall neu. Standardmäßig schützt eine kompakte Bestätigung vor Fehlauslösung; diese Bestätigung kann in den Einstellungen abgeschaltet werden. |
| D-029 | Drei verbundene Arbeitsströme trennen UI/UX, Struktur/Architektur/Performance und Game Concepts/Balancing. UI/UX ist Hauptintegrator und besitzt Theme, Komponenten, Screens sowie visuelle Abnahme. Architektur verändert UI-Dateien nur nach ausdrücklicher Übergabe; Konzept/Balancing besitzt Spielregeln, Inhalte und Balance und schreibt standardmäßig keinen Code. |
| D-030 | Präzisiert D-025: Die freigegebene Einsatzplanung ist die Golden Reference für den globalen Stil „Bio-Lumen · lebendige Membran“. Globale Primäraktionen bleiben Teal→Teal; ausschließlich ihre Startaktion „Behandlung starten“ verwendet Teal→Warmgold. |
| D-031 | Ersetzt hinsichtlich kontextueller Informationen die Hover-/Fokusregeln aus D-016, D-023 und D-027: Tooltips öffnen ausschließlich auf Maus-Hover. Tastatur und Gamepad öffnen dieselbe Information ausdrücklich über die konfigurierbare Aktion `ui_info`, standardmäßig `I` beziehungsweise Gamepad-Y. `ui_info` oder `ui_cancel` schließt die Detailkarte, der Fokus bleibt am Auslöser und dessen eigentliche Aktion wird nicht ausgelöst. |
| D-032 | Gamepad-Y bleibt exklusiver Standard für `ui_info`. `reroll_upgrades` verwendet deshalb Gamepad-X; ein physischer Tastendruck darf auch in der Upgrade-Auswahl niemals gleichzeitig Information und Reroll auslösen. `ui_info` wird nur konsumiert, wenn das fokussierte Element eine registrierte Detailquelle besitzt. |

Neue Entscheidungen erhalten eine neue ID. Bestehende Entscheidungen werden
nicht still umgedeutet; eine ersetzende Entscheidung verweist auf die alte ID.

## Fachliche Referenzen

- Laufzeitarchitektur: [`ARCHITECTURE.md`](ARCHITECTURE.md)
- Fähigkeitenpipeline: [`ABILITY_PIPELINE.md`](ABILITY_PIPELINE.md)
- Qualitäts- und Testauswahl: [`QUALITY.md`](QUALITY.md)
- Leistungsbudgets: [`PERFORMANCE_BUDGET.md`](PERFORMANCE_BUDGET.md)
- UI-System: [`UI_STYLE_GUIDE.md`](UI_STYLE_GUIDE.md)
- Campusbearbeitung: [`CAMPUS_EDITOR.md`](CAMPUS_EDITOR.md)
- Assetquellen und Lizenzen: [`../THIRD_PARTY_ASSETS.md`](../THIRD_PARTY_ASSETS.md)
