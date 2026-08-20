# ALVEOLUS – Projektstand

Letzte inhaltliche Aktualisierung: 18. August 2026

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
- zehn globale Forschungen für intrinsische Werte und
  Behandlungsfreischaltungen;
- zufällige Run-Ausbaustufen, die mit dem vorbereiteten Plan interagieren.

## Aktuell spielbarer Stand

- Vollständiger lokaler Ablauf:
  `Prolog → Campus → Fallarchiv → Einsatzplanung → Run → Ergebnis`.
- Vier wiederholbare Fälle einschließlich ereignisgesteuertem Intro und Bossen.
- Einsatzplan mit einer Grundbehandlung und bis zu zwei aktiven Fähigkeiten.
  Impuls ist sofort verfügbar; Streuimpuls und Durchdringender Impuls
  werden durch Forschung freigeschaltet. `idk name stoß` und `Fetter lazer` sind
  auswählbar, vier weitere aktive Fähigkeiten bleiben sichtbar gesperrt.
  Passive Module gehören nicht mehr zum aktiven Produktkatalog; technisch
  verbliebene Passiv- und Reservefelder dienen ausschließlich der
  Save-/Schema-Kompatibilität.
- Der aktuelle Produktkatalog umfasst drei Behandlungen, sechs sichtbare aktive
  Fähigkeiten, zehn globale Forschungen, vier Rangtalente und 18
  Run-Ausbaustufen.
- Praxis mit Offline-Forschung und Klinikfällen, Forschungsbrett, Talente,
  Meisterschaft, kategorisiertes Lexikon und lokale Savegame-Version 6.
- Hauptfälle haben keine Zeitbegrenzung; ihr Boss erscheint nach 180 Sekunden.
  Doctor Milos startet mit 50 Leben.
- Die sichtbaren Kampfbegriffe lauten Leben, Schaden, Regeneration, Schild und
  Verteidigung. Feuer, Wasser, Erde und Wind sind die vier aktiven
  Schadenstypen. Die UI zeigt Verteidigung und Resistenzen ausschließlich als
  bereits berechnete effektive Prozentwerte.
- Maus und Tastatur, UI-Sounds, Audioeinstellungen, reduzierte Bewegung und
  anpassbare Tastaturbelegungen. Die sichtbare UI läuft vorerst fest bei
  100 Prozent und zeigt ausschließlich Tastatur-/Mausglyphen; frühere
  Skalierungs- und Gamepadfelder bleiben dormant save-kompatibel.
- Zusammenhängendes dunkles Dossier-UI mit sicherer Kopfzone, slotorientierter
  Einsatzplanung, kompaktem Kampf-HUD und responsiven Dialogen bei der festen
  UI-Größe von 100 Prozent.
- Stabile Massendarstellung mit gepoolten Worlds, festen Render-Slots und
  automatischer Reduktion ausschließlich kosmetischer Effekte.

## Aktueller Arbeitsmodus

**Jetzt:** Den aktuellen lokalen Build als zusammenhängendes Spiel testen und
konkretes Feedback zu Bedienung, Verständlichkeit, Fähigkeiten und Spielfluss
sammeln. Bestätigte Fehler werden zuerst reproduziert und gezielt behoben.

Der aktuelle Test verwendet die echte Forschungsökonomie. Nach dem ersten
Introabschluss stehen 30 Forschung bereit; der erste Talentpunkt folgt erst
mit Fall 2. Forschungs- und Talentreset geben investierte Punkte zurück, und
der vollständige lokale Spielstand lässt sich für neue Testläufe zurücksetzen.

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
- Die aktuell sichtbare Einstellungsoberfläche bietet weder UI-Größe noch
  Eingabemodus an. Ältere gespeicherte Werte bleiben kompatibel, wirken aber
  vorerst nicht auf Größe oder sichtbare Glyphen.
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
| D-033 | Präzisiert D-015 und D-030: Dokumentseiten übernehmen die Kopfarchitektur der freigegebenen Einsatzplanung. Der Bio-Lumen-Seitenkopf liegt bündig am oberen Rand, füllt die gesamte Breite und enthält Medaillon, Titel und Navigation; nur der Dokumentkörper erhält den 24/16-Pixel-Sicherheitsrand. Alle Rückkehraktionen verwenden dieselbe zentrale dunkle Navigationsmembran und dieselben Hover-, Fokus- und Pressed-Zustände. |
| D-034 | Präzisiert D-021 und D-031: Der Talentbaum zeigt dauerhaft ausschließlich kompakte, je Talent eindeutige Symbole sowie redundante Aktiv-/Sperrzeichen. Titel, Kosten, Voraussetzung und Wirkung erscheinen nicht als Text in den Knoten, sondern kompakt auf Maus-Hover beziehungsweise über `ui_info`; Zahlen werden dort als kurze Fakten formuliert. Topologie, Voraussetzungen und Navigation bleiben unverändert. |
| D-035 | Jede konfigurierbare Aktion besitzt zwei unabhängige Tastaturplätze. Controller- und Mausbelegungen bleiben für Laufzeit und Save v5 erhalten, werden in der aktuellen Einstellungsansicht aber nicht gezeigt. Wird eine bereits verwendete Taste gewählt, bestätigt ein Pflichtdialog die atomare Verschiebung statt doppelte Auslösung oder stilles Überschreiben zuzulassen. |
| D-036 | Ersetzt D-013 und D-020 für die Anordnung des Run-HUDs: Zustand, Befund, Level, verstrichene Rundenzeit und Pause stehen ohne eigene Kacheln über dem Spielfeld. Optionale Kampfwerte liegen kompakt unter der Zeit in Viererreihen. Belegte aktive Fähigkeiten erscheinen als schmale Abklingzeitspuren mit Icon, Shortcut und Zeit; leere Plätze bleiben unsichtbar. |
| D-037 | Plankapazität wird als hervorgehobener Gesamtwert benannt; einzelne Plan- und Kandidatenkosten zeigen ausschließlich die Zahl ohne das Kürzel `K`. |
| D-038 | Spielernahe Aktivfähigkeitstexte nennen knapp und direkt die mechanische Wirkung; der verständliche Begriff lautet `Kontaktschaden` statt `Kontaktdruck`. Die behandelnde Figur heißt durchgängig „Doctor Milos“, und das Laufzeitmenü trägt den zentrierten Titel „Pause“ ohne dekoratives Titelsymbol. |
| D-039 | Ein Befund zeigt genau drei Reaktionen und nur eine kompakte mechanische Effektzeile. Medizinischer Hintergrund bleibt im Lexikon; `Weitere Perspektive` ersetzt die letzte Basisreaktion durch `Flexible Anpassung`, statt eine vierte Karte anzuhängen. |
| D-040 | Für den aktuellen Balance-Meilenstein ist Auswahlverfügbarkeit von Forschungseigentum getrennt. Auswählbar sind alle drei Behandlungen sowie Abwehrstoß und Behandlungslinie. Fokusfeld, Notfallhilfe, Schutzfeld, Probenzug und alle Passivmodule behalten IDs, Werte, Forschung und Save-Daten, bleiben in der Einsatzplanung aber sichtbar gesperrt. Neue effektive Pläne verwenden Präziser Impuls, Abwehrstoß und Behandlungslinie ohne Passive; historische Pläne werden erst für Planung oder Run als Kopie bereinigt und nicht beim Laden zerstört. |
| D-041 | Ersetzt die sichtbare Terminologie aus D-036 und D-038: `Leben`, `Schaden`, `Regeneration`, `Schild` und `Verteidigung` sind die spielernahen Begriffe. Gegner zeigen Schaden mit Schadenstypen statt eines separaten Werts `Kontaktschaden`. Historische interne IDs dürfen für Save-Kompatibilität bestehen bleiben, dürfen aber keine alte sichtbare Sprache erzwingen. |
| D-042 | Ersetzt D-005, die Fünf-Platz-Angaben aus D-017 und D-019, die Kapazitätsbedeutung aus D-037 sowie D-040 für den aktuellen Progressionsumfang; deren übrige Interaktionsregeln bleiben anwendbar. Sieben globale Forschungen wirken intrinsisch und ohne Passivmodule; fünf verbessern Leben, Behandlungsschaden, Probengewinn, Verteidigung oder Regeneration, zwei schalten Streuimpuls und Durchdringenden Impuls frei. Der aktive Plan umfasst eine Behandlung und bis zu zwei aktive Fähigkeiten. Passivmodule sind nicht sichtbar oder auswählbar; verbliebene Passiv- und Reservefelder sind reine Schema-Kompatibilität. |
| D-043 | Ersetzt D-021, D-023, D-024 und D-034 inhaltlich: Es gibt zunächst genau einen Behandlungs-Talentbaum mit vier Rangtalenten für Mausziel, zusätzliche Streuimpuls-Durchdringung, längere tickende Laserwirkung und den zurückkehrenden Laser. Die Baumrevision verwirft beziehungsweise erstattet frühere Talentbelegungen, ohne Meisterschaft zu verlieren. |
| D-044 | Ersetzt D-006 und die Versionsangabe aus D-035 hinsichtlich des aktuellen Formats: Savegame-Version 6 und Talentbaum-Revision 3 sind verbindlich. Migrationen bewahren Forschung, Meisterschaft und übrigen Fortschritt; entfernte alte Talentbelegungen werden erstattet. |
| D-045 | Hauptfälle besitzen keine Ablaufzeit und rufen den Boss nach 180 Sekunden. Doctor Milos hat 100 Basisleben. Beim ersten Abschluss eines Falls ist noch keine Variation aktiv; danach wird die Variation aus dem Fallseed erzeugt, und dieser Seed rotiert ausschließlich nach einem Sieg. `minor_focus` bleibt ein freisetzendes Nebenziel, besitzt aber eine mobile Basisgeschwindigkeit von 12 px/s, bevor Fallmodifikatoren wirken. |
| D-046 | Feuer, Wasser, Erde, Wind, Blut, Holy und Undead bilden ein festes Set aus sieben Schadenstypen. Angriffe und Gegner besitzen explizite Schadensprofile, Spieler und Gegner explizite Resistenzen; allgemeine Verteidigung reduziert eingehenden Schaden zusätzlich, bevor Schild absorbiert. Abwehrzellen treffen nur über die tatsächliche Geometrie jeder einzelnen Zelle und können je Zelle höchstens einmal pro 0,1 Sekunden Schaden auslösen. |
| D-047 | Ersetzt den Schadenstypanteil aus D-046; dessen Treffergeometrie und Schadensreihenfolge bleiben unberührt. Aktiv sind ausschließlich Feuer, Wasser, Erde und Wind. Jede sichtbare Typangabe kombiniert Name, eigenes Symbol und Wert; Feuer verwendet Koralle/Orange, Wasser Kobalt/Cyan, Erde Honiggold/Ocker und Wind Türkis/Mint. Farbe allein vermittelt niemals den Typ. |
| D-048 | Kampfentfernungen werden zentral als Stufen geführt. Die UI zeigt ausschließlich `Radius N` oder `Reichweite N` und niemals Pixel-, Welt- oder intern umgerechnete Entfernungen; Körpergrößen verwenden eine getrennte Größenklasse. Verteidigungs- und Resistenzanzeigen erhalten fertig berechnete effektive Prozentwerte und zeigen weder Roh-Ratings noch Formeln. |
| D-049 | Ersetzt D-043 sowie ausschließlich die Angabe zur Baumrevision aus D-044; dessen Save-v6- und Migrationsvertrag bleibt bestehen. Talentbaum-Revision 4 beginnt mit `treatment_damage_training` und verzweigt in `spread_penetration`, `manual_treatment_aim` und `piercing_persistence`; `piercing_return` bleibt entfernt und reserviert. Revision-3-Belegungen werden zurückgesetzt beziehungsweise erstattet, Forschung und Meisterschaft bleiben erhalten. |
| D-050 | Ersetzt den Forschungsumfang aus D-042: Acht globale Forschungen umfassen zusätzlich `movement_training` mit drei Rängen; der Run-Katalog umfasst 18 Ausbauten einschließlich `mobility`. Beide Einträge bleiben in stabiler Reihenfolge hinten angehängt und verwenden sichtbar eine semantische Bewegungs- beziehungsweise Trainingsglyphe statt eines unbekannten Platzhalters. |
| D-051 | Präzisiert D-036 für Kampf- und Pausenwerte: Oben rechts zeigt das Run-HUD ausschließlich kompakte Grundwerte. Links vom Rundentimer steht die mit derselben Belohnungsfunktion wie die Niederlage berechnete Forschungsprognose als zugängliches Symbol-Wert-Paar. Charakterwerte erscheinen in stabilen einklappbaren Sektionen `Grundwerte`, `Behandlung`, `Aktiv 1` und `Aktiv 2`; leere Aktivplätze erzeugen keine Sektion, und der Aufklappzustand bleibt bei Aktualisierungen erhalten. |
| D-052 | Kontextquellen verwenden stabile IDs und werden differenziell synchronisiert. Wert- oder Rangänderungen aktualisieren bestehende Controls und Inhalte an Ort und Stelle, ohne alle Quellen ab- und wieder anzumelden oder eine offene Detailansicht zu schließen. Befunddetails liegen bevorzugt diagonal rechts oberhalb ihres Auslösers, bei Platzmangel diagonal links oberhalb und immer vollständig im Viewport. |
| D-053 | Run-Ausbaukarten tragen als Überschrift ausschließlich den betroffenen Komponentennamen; Wirkung und Änderung stehen nur darunter. Das Level-Up-Modal zentriert `Level Up!` lokal. Eine Niederlage zeigt exakt den Titel `You suck` und weder Untertitel noch Grundtext. |
| D-054 | Ersetzt D-040 nur hinsichtlich der sichtbaren Behandlungsbezeichnung: `treatment_precision` heißt in der gesamten Oberfläche „Impuls“; die Content-ID und interne Kompatibilitätsbegriffe bleiben unverändert. Präzisiert und ersetzt D-048 nur hinsichtlich der Darstellung: Wo Zeilenbezeichnung oder Tooltip bereits `Radius` beziehungsweise `Reichweite` nennt, zeigt der zugehörige Wert ausschließlich die nackte zentrale Stufenzahl `N`; Pixel-, Welt- oder UI-eigene Umrechnungen bleiben unzulässig. |
| D-055 | Ersetzt D-008, D-031, D-032 und D-035 ausschließlich hinsichtlich der aktuell sichtbaren Einstellungs- und Glyphendarstellung. `UI-Größe` und `Eingabemodus` sind vorerst nicht sichtbar; die UI wirkt fest bei 100 Prozent und zeigt Tastatur-/Mausglyphen. Vorhandene Skalierungs-, Controller-, Maus- und Savefelder bleiben dormant kompatibel und werden weder gelöscht noch umgedeutet. Die sichtbaren Settings schließen nach dem Entfernen ohne Lücken und besitzen vollständige Fokusnachbarn. |
| D-056 | Intro- und Bossmeldungen verwenden eine gemeinsame containerlose `PlainRunPrompt`-Darstellung: ausschließlich Text ohne Panel, Shader, Hintergrund oder Button. Die Bossmeldung „Infektionsherd erkannt“ steht korallrot direkt unter dem Lebensbalken. Bestätigungspflichtige Intro-Prompts sind die exakten Texte „Beobachte den ersten Erreger.“, „Du greifst automatisch an.“ und „Geh nah ran, um die EXP einzusammeln.“; nur ein Linksklick setzt fort. Die oberste Prompt-Ebene konsumiert den Klick und meldet genau eine Bestätigung, damit keine zweite Gameplay-Klickroute auslöst. |
| D-057 | Präzisiert D-045 und D-053 für das Intro: Die ereignisgesteuerte Tutorialdauer erscheint in der Planung ausschließlich als `Dauer ∞`; die Texte „Ereignisgesteuert“ und „Ohne Zeitlimit“ werden dafür nicht verwendet. Ein Level-up zeigt drei normale Ausbaukarten mit ihren üblichen Vergleichswerten und zusätzlich exakt „Du kannst 1 Upgrade auswählen.“; der Hinweis ist nicht an einen historischen Ein-Karten-Introzustand gekoppelt. |
| D-058 | Präzisiert D-051: Jeder Charakterwerte-Accordionheader zeigt seinen Zustand mit einem echten semantischen `SimpleIcon` für ein- beziehungsweise ausgeklappt. Ein bloßes Unicode-Dreieck oder Farbe allein genügt nicht; Symbol und zugänglicher Name werden bei jedem Zustandswechsel gemeinsam aktualisiert. |
| D-059 | Präzisiert D-056 hinsichtlich der Platzierung: Alle normalen und korallenen Intro-Prompts liegen containerlos in derselben festen Leseband direkt unter dem Lebensbalken. Keine Introcopy wird über Doctor Milos oder in der Bildschirmmitte verankert. |
| D-060 | Präzisiert D-016 und D-049 für die Progressionsdarstellung: Forschung zeigt bei 1280×720 vier kompakte Elemente pro Reihe; die zentral berechnete Gesamtwirkung erscheint ausschließlich im Tooltip als `Gesamt: …`. Der Talentbaum bewahrt seine Focustopologie, beginnt mit einem kompakten Root-Icon und verzweigt über sichtbare Voraussetzungen in drei kompakte Iconknoten mit Rangpips, Auswahlring sowie redundanten Verfügbar-/Gesperrtzuständen. Details bleiben Hover beziehungsweise `ui_info` vorbehalten. |
| D-061 | Erweitert D-052 zur globalen Popoverregel: `ContextDetailController.AUTO` verankert jede Quelle am tatsächlichen Source-Control und versucht diagonal rechts oberhalb, danach diagonal links oberhalb, rechts unterhalb und links unterhalb; erst danach wird deterministisch viewportgebunden geklemmt, ohne die Quelle zu überdecken. Befund, Fähigkeiten, Progression und Lexikon-Verweise verwenden denselben Pfad ohne Sonderanker. Verwandte Lexikonbegriffe sind fokussierbare Detailquellen; Maus-Hover beziehungsweise `ui_info` zeigt ihre zentral gelieferte Erklärung, reiner Fokus öffnet weiterhin nichts. |
| D-062 | Präzisiert D-053 für Ausbau und Ergebnis: Upgradeicons stammen datengetrieben aus der betroffenen Komponente, sind etwa 32 Pixel groß und stehen neben einer kompakteren Überschrift. Behandlungstempo und Abwehrzelltempo erscheinen als fertig berechnete Rate `/s`; Abklingzeit bleibt Sekunden. Das Ergebnis zeigt keinen Titel `Belohnung`, sondern einen vierteiligen Strip aus Forschungsicon plus Zahl sowie den vorläufigen Spalten `+ irgendwas`, `+ maybe nochwas` und `+ idk`. |
| D-063 | Ersetzt die betreffenden sichtbaren Begriffe aus D-038, D-041 und D-054 für den aktuellen Testmeilenstein, ohne IDs zu ändern: `ability_defense_burst` heißt `idk name stoß`, `ability_treatment_line` heißt `Fetter lazer`, Proben-/Samplewerte heißen `Erfahrung` und Bewegungs-/Tempowerte heißen `Geschwindigkeit`. |
| D-064 | Ersetzt D-057 und D-062 hinsichtlich der Level-up-Hilfe und Tempobezeichnung: Das Modal zeigt keinen zusätzlichen Satz „Du kannst 1 Upgrade auswählen.“. Jede Ausbaukarte zeigt unten rechts `gewählt/maximal`, ist geringfügig höher und nennt Anwendungen pro Sekunde `Attack Speed`. Der Geschwindigkeitskartenname erhält kompaktere Schrift. Im Run erworbene Systeme wie Abwehrzellen erscheinen sofort als eigene Charakterwertsektion. Ein Rechtsklick entfernt genau einen zulässigen Talentrang; abhängige Talente verhindern weiterhin ein ungültiges Entfernen. |
| D-065 | Der Boss von Fall 1 bewegt sich mit dem Faktor 1,35 und feuert fortlaufend zwei korallenrote Projektile auf gespiegelten Rautenbahnen. Bei 70 und 40 Prozent Leben erscheinen jeweils vier schießende Bakterien; nach Phase zwei folgen alle 20 Sekunden vier weitere. Kleine Herde feuern ebenfalls normale Projektile. Gegnerprojektile verwenden generationssichere World-Handles, den gemeinsamen zentralen Projektil-World und einen getrennten stabilen Renderbatch. |
| D-066 | Abwehrzellen besitzen zunächst 0,2 Sekunden Trefferabstand je Zelle, also 5 Angriffe pro Sekunde. Die technische Untergrenze von 0,1 Sekunden bleibt ausschließlich als spätere Ausbaugrenze bestehen. Die Forschung `Stärkere Behandlung` beschreibt ihren Rang sichtbar als `+2 % Schaden der Behandlungen`. |
| D-067 | Ersetzt D-045 hinsichtlich des Basislebens, D-063 hinsichtlich des Spieler-Bewegungsbegriffs, D-066 hinsichtlich der Behandlungsforschung und D-050 hinsichtlich des Forschungsumfangs: Doctor Milos besitzt 50 Basisleben; sein Bewegungswert heißt überall `Galopp`. Schaden, Reichweite und Galopp werden nach allen Modifikatoren ganzzahlig aufgelöst. Schadensausbauten addieren feste Werte. `Stärkere Behandlung` gibt +1 Schaden je Rang. Der lineare Impuls-Ausbau addiert +0,06 Attack Speed pro Rang statt ein Intervall prozentual zu multiplizieren. Zehn Forschungen umfassen zusätzlich die Freischaltungen von `idk name stoß` für 30 und `Fetter lazer` für 1000 Forschung; sämtliche früheren Forschungskosten sind verfünffacht. |
| D-068 | Ersetzt D-065: Der einfache neue `Bakterienkern` ist Boss von Fall 1. Der bisherige rautenförmig schießende Infektionsherd ist Boss von Fall 2, bewegt sich dort mit Faktor 1,35, besitzt eine deutlich breitere Flugbahn und 2,5-fachen Projektilschaden. Der Intro-Boss bleibt die kurze einfache Altvariante ohne Spezialprojektile. Fall 3 behält den Infektionsherd ohne den Fall-2-Projektilvertrag. |
| D-069 | Ersetzt D-064 ausschließlich für die Introhilfe: Das erste reguläre Drei-Karten-Level-up zeigt unter `Level Up!` den knappen Satz `1 von 3 Upgrades aussuchen`. Nach dem ersten Introsieg kehrt das Spiel direkt zum Campus zurück, vergibt genau 30 Forschung und einen Talentpunkt und markiert das Forschungsgebäude einmalig. Die Markierung verschwindet dauerhaft, sobald irgendein Campusgebäude gewählt wird. Settings bieten `Neues Spiel`, das den lokalen Fortschritt auf den Startzustand zurücksetzt. |
| D-070 | Die aktiven Befunde sind vorerst ausschließlich `Gruppenbildung` und `Verdeckte Nester`; `Beschleunigte Ausbreitung` und `Belastungsschübe` sind aus dem aktiven Katalog entfernt. Der Befundtitel besitzt dieselbe globale diagonale Detailkarte wie andere Tooltips. Sie erklärt die konkrete Wirkung; verdeckte Nester zeigen zusätzlich ihr Gegnerbild. Das Ergebnis listet den tatsächlich verursachten Schaden getrennt für Behandlung, ausgerüstete Aktive und im Run erworbene Schadenssysteme. |
| D-071 | Ersetzt D-069 hinsichtlich des Introabschlusses und D-070 hinsichtlich der Befundwirkung: Der erste Introsieg zeigt den normalen Ergebnis-Screen mit dem Hinweis `Nutze die Forschung für Upgrades im Forschungsgebäude.`; erst dessen Weiter-Aktion führt zum Campus. Aktive Befunde und Reaktionen bleiben sichtbar, sind aber vorerst ausdrücklich wirkungslose Platzhalter. |
| D-072 | Präzisiert D-052 und ersetzt die Entdeckungsdarstellung mit seitlicher Zentrierung: Jede Anzeige `Neu` versucht dieselbe diagonale Eckreihenfolge wie globale Kontextdetails und darf ihr zugehöriges Objekt bei normaler Zielauflösung nicht überdecken. Monsterentdeckungen stehen weiter vom Körper entfernt und enthalten keine Grundwerttabelle; vollständige Werte bleiben im Lexikon. Der sichtbare Schadenstyp `wind` heißt `Luft`, die stabile interne ID bleibt unverändert. |
| D-073 | Ersetzt D-063 für `ability_defense_burst`: Die Fähigkeit heißt sichtbar `Stoß`, besitzt 0 Basisschaden und erhält Schaden ausschließlich durch Run-Ausbauränge. Ihr Rückstoß wird über mehrere Fixed Ticks bewegt, betäubt getroffene Gegner eine Sekunde und unterbindet in dieser Zeit Bewegung, Kontaktangriffe und neue Projektilangriffe. Ein kleines dokumentiertes Sternsymbol zeigt die Betäubung. |
| D-074 | Ersetzt den absoluten Attack-Speed-Anteil aus D-067: Jeder Rang addiert einen Prozentpunktbonus auf den unveränderten Basis-Attack-Speed, niemals auf den bereits erhöhten Wert. Die Karte zeigt ausschließlich den Rangbonus und die akkumulierte Summe, beispielsweise `+6 % Attack Speed` und `6 % → 12 %`; exakte Angriffe pro Sekunde bleiben Charakterwerten und Fähigkeitsdetails vorbehalten. |
| D-075 | Gegnerkörper verwenden einen zentralen, rastergestützten weichen Trennpass nach dem EnemyWorld-Schritt. Leichte visuelle Überlappung bleibt erlaubt, unendliches Stapeln nicht. Normale Gegner weichen dem Doctor stärker aus als umgekehrt; Bosse sind deutlich schwerer. Dadurch kann der Spieler Gegner nicht frei durchqueren, bleibt aber in dichten Gruppen beweglich. |
| D-076 | Ersetzt D-075: `EnemyWorld` berechnet vor der Bewegung eine begrenzte lokale Separation aus dem bestehenden Raumraster und mischt sie in die Bewegungsrichtung; nachträgliche Positionskorrekturen sind verboten. Gleich große Gegner halten ungefähr ihre sichtbare Körperbreite Abstand, bremsen beim Auflaufen auf einen dichten Pulk und erhalten eine stabile leicht versetzte Annäherungsspur statt alle dieselbe Mittellinie zu wählen. Doctor Milos kann ausschließlich kleine Bakterien durch Annäherung verdrängen. Größere Gegner entfernen nur die auf sie gerichtete Bewegungskomponente, während tangentiales Entkommen erhalten bleibt. Nach dem Intro gibt es keinen Talentpunkt; Meisterschaften vor Fall 2 tragen null Punkte. Forschungsreset erstattet bezahlte Rangkosten, Talentreset macht alle verdienten Punkte wieder frei. |

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
