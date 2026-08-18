# ALVEOLUS UI-Leitfaden

Die verbindliche visuelle Golden Reference ist die freigegebene
Einsatzplanung. `res://scenes/ui/style_gallery.tscn` dokumentiert die zentralen
Bausteine sowie Referenzansichten für Einsatzplanung, Lexikon und Pause und
muss visuell an diese Golden Reference anschließen.

## Fachliche Grundlage

Die Regeln dieses Leitfadens übersetzen etablierte plattformübergreifende
Empfehlungen in konkrete Godot-Komponenten. Maßgeblich sind:

- [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines) für lesbare Texte, Kontrast, Fokus, Eingaben und nicht ausschließlich farbcodierte Zustände.
- [Epic CommonUI](https://dev.epicgames.com/documentation/unreal-engine/overview-of-advanced-multiplatform-user-interfaces-with-common-ui-for-unreal-engine) für ein gemeinsames Navigationsmodell über Maus, Tastatur und Gamepad.
- [Steam Deck recommendations](https://partner.steamgames.com/doc/steamdeck/recommendations) für Controllerbedienung, passende Eingabesymbole und kleine Displays.
- [Riot UI Design](https://www.riotgames.com/en/artedu/user-interface-design) für gameplaynahe Informationshierarchie und konsistente visuelle Sprache.
- [Returnal: gameplay-first UI](https://blog.playstation.com/2021/05/11/unpacking-returnals-ux-design-gameplay-first-ui-retro-futuristic-tech-and-accessibility/) für zurückhaltende, aber eindeutige Kampfoberflächen.

Die Quellen definieren die Richtung. Automatisierte Layout-, Fokus-, Kontrast-
und Eingabetests in diesem Projekt machen die Regeln überprüfbar.

## Grundprinzipien

- Eine Ansicht hat genau eine klar hervorgehobene Hauptaktion.
- Die visuelle Sprache ist „Bio-Lumen · lebendige Membran“ als organische Weiterentwicklung des dunklen medizinischen Einsatzdossiers: Petroltiefe, feine Zell- und Kapillarspuren, präzise Linien und wenige leuchtende Akzente. Weiße Kachelwände und beliebige Neon-Sci-Fi-Dekoration sind kein ALVEOLUS-Muster.
- Diese Sprache gilt für die gesamte Oberfläche: Texte, Buttons, Formcontrols, Karten, Popups, Tooltips, Dialoge, HUD-Flächen, Beschriftungen, Fokusdarstellung und Lebensleisten. Häuser und Umgebungsbilder sowie die Figuren von Monstern und Spielern bleiben außerhalb dieses visuellen Rollouts; ihre darüberliegenden UI-Elemente gehören dazu.
- Der feste Seitenkopf folgt auf allen Dokumentseiten der Golden Reference: Er liegt bündig am oberen Fensterrand, füllt die gesamte Breite und enthält links ein 44-Pixel-Medaillon mit Seitensymbol, daneben genau einen Titel und rechts die Navigation. Nur der Dokumentkörper erhält den 24/16-Pixel-Sicherheitsrand. Inhalt, Gebäude und Karten beginnen immer unterhalb des Kopfes und nach dem verbindlichen Inhaltsabstand. Seine Zeichenebene bleibt lokal in der jeweiligen Seite und darf niemals über eine später geöffnete Seite ragen.
- Der Seitenkopf wird durch seine durchgehende Unterkante getrennt. Zusätzliche kurze Akzentbalken unter dem Titel werden nicht verwendet.
- Normale Aktionen, Auswahl, Gefahr und Navigation verwenden semantische Theme-Varianten. Lokale Farb- und Rahmenkopien sind zu vermeiden.
- Farbe ist nie das einzige Signal. Auswahl wird zusätzlich durch Zustand, Text oder Symbol vermittelt.
- Rückwärtsnavigation entfernt die oberste tatsächliche Ebene. Routineaktionen benötigen keine Bestätigung, destruktive Aktionen genau eine; nur die ausdrücklich abschaltbare Neustartbestätigung ist eine dokumentierte Nutzeroption.
- Fließtext ist mindestens 16 Designpixel groß. Kleine Metadaten sind auf 14 Designpixel begrenzt und enthalten keine Kerninformation.
- Maus, Tastatur und Gamepad erhalten dieselbe Informationshierarchie und einen sichtbaren Fokus.
- Für den aktuellen lokalen UI-Stand ist die sichtbare Eingabedarstellung bewusst auf Tastatur und Maus begrenzt. Vorhandene Gamepad- und Skalierungsdaten bleiben kompatibel, erzeugen aber weder auswählbare Settingscontrols noch Gamepadglyphen.
- Fokus und Auswahl werden innerhalb der zugeteilten Geometrie gezeichnet. Hover oder Fokus dürfen Controls niemals skalieren, über ihre Rasterzelle malen oder aus einem Dialog hinausragen.
- Reines Zeigen mit der Maus bleibt still. Sounds markieren bestätigte Aktionen, Öffnen/Schließen, Fehler oder eine tatsächlich per Tastatur beziehungsweise Gamepad bewegte Fokusposition.
- Texte werden in natürlichem Deutsch und Satzschreibweise formuliert. Lange Bindestrichketten und dauerhafte Großschreibung entfallen.
- Aktivfähigkeitstexte verwenden kurze, spielernahe Wirkungsformulierungen statt medizinisch-technischer Umschreibungen. Sie nennen zuerst die Aktion und dann die entscheidende Mechanik beziehungsweise Zahl; `Kontaktschaden` ist der verbindliche Spielerbegriff statt `Kontaktdruck`. Die behandelnde Figur heißt in allen sichtbaren Texten „Doctor Milos“. Die Behandlung mit der stabilen ID `treatment_precision` heißt sichtbar ausschließlich „Impuls“; ältere Varianten wie „Präziser Impuls“ oder „Präziser Einzelimpuls“ dürfen nicht in UI-Copy oder Referenzfixtures verbleiben.
- Flächen folgen auf normalen Ansichten ihrer tatsächlichen Inhaltshöhe. Feste Höhen sind nur Viewportgrenzen für Scrollflächen, keine Reserve für dekorativen Leerraum; unsichtbare Spacer dürfen kurze Dialoge nicht künstlich strecken.
- Text berührt niemals seine bemalte Fläche: Primär-, Sekundär- und Gefahrbuttons besitzen in jedem Zustand mindestens 18 Pixel horizontalen Innenabstand, Auswahlzeilen mindestens 12 Pixel und gestylte Textbadges mindestens 8 Pixel. Lokale Zustands- oder Farb-Overrides müssen diese Safe Area erhalten; Panels mit eigenem `MarginContainer` werden nicht doppelt gepolstert.
- Ausführliche Hilfen oder Wirkungsbeschreibungen belegen keine dauerhafte Kopf- oder Brettfläche. Auf Maus-Hover öffnen sie als kompakter Tooltip; Tastatur und Gamepad öffnen dieselbe Information ausschließlich über `ui_info` als kompakte Detailkarte. Reiner Fokus öffnet nichts. Beide Darstellungen verändern die Geometrie der Ansicht nicht.
- Medizinische Einordnung und unmittelbare Spielwirkung verwenden getrennte semantische Flächen mit eigenem Icon und Akzent. Die Trennung darf nicht nur durch Farbe vermittelt werden und verwandelt kurze Inhalte nicht in zusätzliche Textwände.
- Aktive Schadenstypen sind ausschließlich Feuer, Wasser, Erde und Wind. Jede Darstellung kombiniert Name, eigenes Symbol und Wert; Feuer verwendet Koralle/Orange, Wasser Kobalt/Cyan, Erde Honiggold/Ocker und Wind Türkis/Mint. Farbe ist dabei nur Verstärkung, niemals alleiniger Informationsträger. Das Lexikon stellt die vier Angaben als gestaltete strukturierte Zeilen beziehungsweise Chips dar, nicht als unverbundene Textliste.
- Die UI erhält bereits berechnete Werte. Verteidigung und Resistenzen erscheinen als effektive Prozentwerte; Roh-Ratings, Minderungskurven und Formeln bleiben außerhalb der sichtbaren Oberfläche.
- Radius und Reichweite stammen ausschließlich als zentrale Stufen aus dem Core. Steht die Semantik bereits in Zeilenlabel oder Tooltip, besteht der sichtbare Wert nur aus der nackten Zahl `N`, nicht aus `Stufe N`, `Radius N` oder `Reichweite N`. Interne Weltwerte, Pixelangaben oder eine Umrechnung in UI-Code sind unzulässig. Körpergrößen verwenden stattdessen ihre getrennte benannte Größenklasse.

## Tokens

Alle Werte liegen in `AlveolusVisualTheme`:

- Außenabstand: 24 Pixel, kompakt 16 Pixel.
- Primärbutton: mindestens 46 Pixel hoch.
- Sekundärbutton: mindestens 40 Pixel hoch; interaktive Ziele mindestens 44 Pixel.
- Kontrollradius: 4 Pixel, Kartenradius: 6 Pixel, Dialogsignatur: feste 6 Pixel. Die asymmetrisch ausgesparte Ecke gehört nur zu kleinen Signaturkarten und Dialogen; große Abschnittsflächen bleiben gerade.
- Fließtext: 16 Pixel, Abschnitt: 20 Pixel, Seitentitel: 28 Pixel.
- Rollenfarben: Tiefpetrol für die Bühne, Petrol-Wash für Flächen, Elfenbein für Primärtext, Türkis für Hauptaktionen, Kobalt für Auswahl, Koralle für Gefahr und Honiggold für Belohnung sowie Fokus. Primäraktionen verwenden einen schwachen Teal-zu-Teal-Verlauf und eine sehr ruhige Membranstruktur. Ausschließlich „Behandlung starten“ in der Einsatzplanung verwendet als Startaktion der Golden Reference Teal→Warmgold; für alle anderen Primäraktionen sind Goldverläufe und starkes Dauerleuchten unzulässig.

## Seiten- und Navigationsvertrag

- Normaler Außenabstand: 24 Pixel; kompakt: 16 Pixel.
- Kopfzeile: 76 Pixel; kompakt: 60 Pixel. Danach folgen 20 beziehungsweise 12 Pixel Leerraum, bevor der erste Inhaltsblock beginnt.
- Der Kopf enthält genau einen Seitentitel. Zwischen Medaillon und Titel liegen 16 Pixel; Obertitel oder wiederholte Kontextzeilen werden nicht verwendet.
- `ui_cancel` schließt immer nur die oberste tatsächliche Ebene: Bestätigung → Auswahl → Detail → Seite → Campus/Run. Ein Pflichtdialog kann nicht in den Hintergrund durchgereicht werden.
- Jede Scrollfläche mit interaktiven Inhalten folgt dem Tastatur-/Gamepadfokus. Ein sichtbarer Fokus darf nie außerhalb des aktuellen Viewports stehen; Maus und Touch behalten denselben Scrollbereich.
- Ab 920 logischen Pixeln darf die Einsatzplanung Plan und Editor im Verhältnis 60/40 nebeneinander zeigen. Darunter werden beide Bereiche in derselben Seiten-Scrollfläche gestapelt und nach einer Platzwahl automatisch zum Editor geführt; ein zusätzlicher Übersichts-Zwischenschritt ist unzulässig.
- Die sichtbare UI-Größe ist vorerst fest auf 100 Prozent gesetzt. Frühere 75–200-Prozent-Controls und ihre Skalierungsmatrix gehören nicht zur aktuellen Oberfläche; gespeicherte Werte bleiben lediglich dormant kompatibel. Schrift, Fokus und Ziele werden weiterhin nicht verkleinert, um Inhalt hineinzuzwingen.

## Input- und Popover-Vertrag

- Maus-Hover öffnet einen kompakten, am Auslöser anliegenden Tooltip. Er schließt, sobald der Hover endet, verändert kein Layout und löst keinen Sound oder Fokuswechsel aus.
- Tastatur- oder Gamepadfokus allein öffnet niemals einen Tooltip oder eine Detailkarte. Die fokussierte Informationsquelle bleibt jedoch sichtbar als solche erkennbar.
- `ui_info` öffnet für das fokussierte Element ausdrücklich dieselbe Information und Informationshierarchie wie der Maus-Tooltip. Die sichtbare Standardbelegung ist `I`; alle aktuellen Glyphen verwenden Tastatur-/Mausdarstellung. Dormante Gamepadbelegungen bleiben save-kompatibel, sind aber weder auswählbarer Eingabemodus noch sichtbare Glyphe.
- Falls die dormante Gamepadsteuerung später wieder sichtbar aktiviert wird, bleibt Y exklusiv für `ui_info` und die kontextspezifische Upgrade-Neuwahl auf X. Ohne registrierte Detailquelle bleibt `ui_info` wirkungslos, statt eine fremde Aktion auszulösen.
- Während die Detailkarte offen ist, schließt `ui_info` oder `ui_cancel` ausschließlich diese oberste Ebene. Der Fokus bleibt am Auslöser beziehungsweise kehrt dorthin zurück; das Öffnen oder Schließen löst dessen eigentliche Aktion nicht aus.
- Tooltip und Detailkarte verwenden dieselben Inhaltsdaten. Medizinische Einordnung und unmittelbare Spielwirkung bleiben als zwei semantisch getrennte, nicht nur farbcodierte Flächen erkennbar.
- Registrierte Kontextquellen besitzen stabile IDs und werden differenziell synchronisiert. Bestehende Controls und offene Inhalte werden bei Rang- oder Wertänderungen an Ort und Stelle aktualisiert; ein pauschales Abmelden und erneutes Registrieren aller Quellen sowie Close/Open-Flackern sind unzulässig.
- Jede automatische Kontextkarte liegt bevorzugt diagonal rechts oberhalb ihres tatsächlichen Source-Controls, bei Platzmangel diagonal links oberhalb und verwendet erst danach einen deterministischen viewportgebundenen Fallback. Befund, Fähigkeiten, Progression und Lexikon-Verweise verwenden denselben Controllerpfad ohne Sonderanker.
- Verwandte Begriffe im Lexikon sind echte fokussierbare Detailquellen statt einer zusammengefügten Textzeile. Maus-Hover zeigt ihre zentral gelieferte Erklärung; reiner Fokus öffnet nichts und `ui_info` zeigt dieselbe Erklärung mit erhaltenem Fokus.

## Einsatzplanung

Die Einsatzplanung ist strikt platzorientiert:

1. Die Seite öffnet direkt `COMPONENT_PICK(Behandlung)`. Der aktuell bearbeitete Planplatz ist zusätzlich zum Fokus dauerhaft durch Rahmen und Textzustand markiert.
2. Ein Klick oder `Accept` auf einen der fünf Planplätze wechselt ausdrücklich das Ziel. Maus-Hover darf dessen Kurzinfo als Tooltip zeigen; Tastatur und Gamepad rufen sie mit `ui_info` auf. Reiner Fokus zeigt keine Kurzinfo, und keine dieser Informationsaktionen ändert den Zielplatz.
3. `COMPONENT_PICK(slot)` hält Zielplatz und aktuellen Inhalt im Editorheader sichtbar. Darunter stehen ausschließlich echte passende Alternativen in einem kompakten zweispaltigen Katalog; unter 760 logischen Pixeln wird er einspaltig. Ein gemeinsamer Inspektor zeigt Wirkung, Voraussetzung und Kosten genau einmal.
4. Bei einem belegten Platz ersetzt ein zulässiger Komponenten-Klick den Inhalt direkt und atomar. Es gibt keinen Bestätigungsdialog; aktueller Inhalt, neue Wirkung und Kapazitätsfolge sind vor dem Klick im gemeinsamen Inspektor sichtbar. Danach bleibt derselbe Platz im Picker aktiv, damit ein weiterer Wechsel oder Entfernen die Auswahl unmittelbar reversibel macht.
5. Entfernen ist eine ausdrückliche Sekundäraktion. Die Reserve ist kein sichtbarer Planplatz; alte Savefelder und IDs bleiben lediglich für Kompatibilität bestehen.

Ein Klick auf eine Komponente darf niemals raten, welcher Platz gefüllt oder ersetzt wird. Jede Planzeile besitzt mindestens 12 Pixel horizontalen Innenabstand. Die globale Kapazität wird im Plankopf als semantischer Wert farblich hervorgehoben. Kosten auf Plan- und Kandidatenzeilen bestehen nur aus der Zahl; das Kürzel `K` wird nicht verwendet. Der Inspektor nennt die unmittelbare Änderung vor dem direkten Ersetzen. Der aktuelle Inhalt wird nicht als scheinbar neu gewählter Kandidat wiederholt. Verfügbare, anderweitig verwendete und gesperrte Einträge sind durch Symbol und Kontrast unterscheidbar; gesperrte Icons, Titel und Kosten sind vollständig entsättigt.

Im Intro ist der gesamte Planbereich schreibgeschützt. Eine flächendeckende Schlosskennzeichnung erklärt knapp, dass der Einführungsplan vorgegeben ist; einzelne darunterliegende Plätze oder Komponenten dürfen weder per Maus noch Fokus beziehungsweise Gamepad verändert werden.

Die ereignisgesteuerte Intro-Dauer erscheint in der Fallkurzinfo ausschließlich als `Dauer ∞`. Die Formulierungen „Ereignisgesteuert“ und „Ohne Zeitlimit“ werden dafür nicht verwendet.

Die Fallkurzinfo ist keine massive Karte und keine zweite Textwand. Sie besteht aus Falltitel, höchstens einer Kurzzeile und umbruchfähigen Fakten: Dauer blau, Boss gold, negatives Fallmerkmal und negativer Startzustand korallrot, positive Unterstützung wie Atemhilfe türkis. Die vollständige Erklärung bleibt per Maus-Hover als Tooltip und per `ui_info` als zugängliche Detailkarte verfügbar.

## Run-HUD

- Oben rechts stehen ausschließlich die verstrichene Rundenzeit und das kompakte Pause-Icon frei über dem Spielfeld; beide besitzen weder Kachel noch Rahmen. Ein separater Boss-Timer ist dort nicht dauerhaft sichtbar.
- Intro- und Bossmeldungen verwenden dieselbe wiederverwendbare `PlainRunPrompt`-Darstellung als oberste UI-Ebene. Sie enthält ausschließlich Text, optional einen knappen Maushinweis, und niemals Panel, Shader, Hintergrund oder Button. Alle Varianten liegen in derselben festen Leseband direkt unter dem Lebensbalken; keine Introcopy wird über Doctor Milos oder in der Bildschirmmitte verankert. Sie kann persistent ein- und ausgeblendet werden und hinterlässt beim Schließen oder Szenenwechsel weder Eingabefang noch sichtbaren Restzustand.
- Die Bossmeldung lautet `Infektionsherd erkannt` und steht korallrot in dieser oberen Leseband. Im Intro bleibt sie bis zur Linksklickbestätigung sichtbar; eine reguläre Bossmeldung darf ihren zeitgesteuerten Ablauf behalten, verwendet aber dieselbe containerlose View.
- Die bestätigungspflichtigen Introtexte lauten exakt `Beobachte den ersten Erreger.`, `Du greifst automatisch an.` und `Geh nah ran, um die EXP einzusammeln.` Linksklick ist der einzige Fortsetzungsweg; ein knapper Maushinweis ist zulässig, ein Button nicht. Die blockierende Prompt-Ebene konsumiert den Klick und emittiert genau eine Bestätigung, sodass keine zusätzliche Gameplay-Eingaberoute denselben Klick auswertet.
- Links von der Rundenzeit steht die Forschungsprognose für eine aktuelle Niederlage als einzelnes `Symbol + Zahl`-Paar ohne Kachel. Sie verwendet dieselbe zentrale Belohnungsberechnung wie das Ergebnis, besitzt einen zugänglichen Namen und zeigt keine hergeleitete UI-Schätzung.
- Oben rechts stehen unter der Rundenzeit ausschließlich kompakte Grundwerte als enge, farbcodierte `Icon + Wert`-Paare ohne Überschrift, Kachel oder Mausblockade. Behandlungs- und Fähigkeitswerte gehören nicht in dieses Band. Die Grundwerte werden mit vier Werten pro Reihe angeordnet und dürfen bei kleiner Breite in weitere Vierer- beziehungsweise Teilreihen umbrechen.
- Vollständige Erklärungen und alle weiteren Werte liegen ausschließlich im pausierten Untermenü „Charakterwerte“.
- Das Pausenmenü trägt den geometrisch zentrierten Titel „Pause“ ohne dekoratives Symbol und benennt die behandelnde Figur als „Doctor Milos“. Es ist nicht scrollbar: Titel und Fortsetzen bleiben sichtbar, die übrigen Aktionen liegen in einem responsiven Raster. Charakterwerte bilden stabile einklappbare Sektionen in der Reihenfolge `Grundwerte`, `Behandlung`, `Aktiv 1`, `Aktiv 2`. `Grundwerte` enthält maximales Leben, aktuellen Schild und Schildmaximum, effektive Verteidigung, Bewegungstempo, Regeneration pro Sekunde, EXP-Multiplikator sowie die vier effektiven Resistenzen. Leere Aktivplätze erzeugen keine Sektion. Jeder Accordionheader verwendet ein echtes semantisches `SimpleIcon` mit unterscheidbaren Varianten für ein- und ausgeklappt; ein Unicode-Dreieck oder Farbe allein genügt nicht. Symbol und Accessible Name werden mit dem Zustand aktualisiert. Jede Zeile besitzt einen farbcodierten semantischen Marker, eine linksbündige Bezeichnung und einen an einer gemeinsamen rechten Kante ausgerichteten Wert. Der Aufklappzustand sowie Fokus und Scrollposition bleiben bei Wertaktualisierungen erhalten; nur der innere Wertebereich darf bei Bedarf scrollen, die Zurückaktion bleibt fest sichtbar.
- Befunde zeigen unter dem Titel nur eine knappe mechanische Effektzeile und exakt drei Reaktionskarten. Medizinische und spielerische Erklärungskarten werden dort nicht wiederholt; Hintergrundwissen liegt im Lexikon.
- Dauerhaft sichtbar sind nur Zustand, verstrichene Rundenzeit, aktuelle Ziele und unmittelbar bedienbare Fähigkeiten. Zustand, Befund und Level verwenden keine umgebende Kachel; der Levelbalken ist innerhalb seiner freien HUD-Zone zentriert. Massive weiße oder deckende Petrol-Hintergründe sind unzulässig.
- Belegte aktive Fähigkeiten sitzen kompakt am unteren Rand als schmale Abklingzeitspuren. Icon, Shortcut und verbleibende Zeit liegen gemeinsam auf der Spur; ein dauerhafter Fähigkeitsname oder eine zusätzliche Kartenfläche entfällt. Maus-Hover beziehungsweise `ui_info` liefert die vollständige Wirkung. Leere Plätze werden nicht dargestellt und reagieren nicht auf Eingaben.
- Wird eine belegte, aber noch nicht bereite Fähigkeit ausgelöst, bestätigt ausschließlich ein leiser Fehlersound den blockierten Versuch; zusätzlicher Text, Toast oder Dialog ist unzulässig.
- `Strg+R` fordert während eines laufenden oder pausierten Falls einen Neustart desselben Falls an. Standard ist ein einzelner kompakter Bestätigungsdialog; die Option „Neustart bestätigen“ darf ihn abschalten. Der Shortcut umgeht niemals einen bereits bindenden Pflichtdialog.

## Ausbauten und Ergebnis

- Eine Run-Ausbaukarte verwendet als Überschrift ausschließlich den betroffenen Komponentennamen. Allgemeine Behandlungsverbesserungen tragen den Namen der aktuell ausgerüsteten Behandlung; andere Karten heißen entsprechend `Abwehrzellen`, `Abwehrstoß`, `Behandlungslinie` oder `Bewegung`. Wirkung und Vorher-Nachher-Änderung stehen nur darunter.
- Das Level-Up-Modal zentriert den Titel `Level Up!` innerhalb seiner eigenen Fläche, unabhängig von umgebenden HUD-Ankern.
- Ein Level-up zeigt drei normale Ausbaukarten mit ihren regulären Vergleichswerten. Der ergänzende Hinweis lautet exakt `Du kannst 1 Upgrade auswählen.` und gilt unabhängig vom Intro; ein historischer scripted-Intro-Ein-Kartenmodus darf die Zahl der Karten oder deren Vergleichsdaten nicht verändern.
- Upgradeicons werden über die betroffene Komponente datengetrieben aufgelöst und erscheinen mit ungefähr 32 Pixeln sichtbar größer als bisher; die danebenstehende Komponentenüberschrift bleibt kompakt. Die UI besitzt keine ID-Mappingtabelle für zukünftige Ausbauten.
- Sichtbare Behandlungstempi und Abwehrzelltempi erscheinen als zentral fertig berechnete Rate mit `/s`, beispielsweise `1,22/s` statt `0,82 s Intervall`. Abklingzeiten bleiben Sekunden. Radius- und Reichweitenwerte bleiben nackte zentrale Zahlen ohne Pixel- oder `Stufe`-Copy.
- Das Ergebnis besitzt keine Überschrift `Belohnung`. Sein Rewardstrip zeigt in vier gleichwertigen Spalten zuerst Forschungsicon und reine Zahl, danach vorläufig exakt `+ irgendwas`, `+ maybe nochwas` und `+ idk`.
- Eine Niederlage zeigt exakt den Titel `You suck`. Ein Untertitel, Grundtext oder eine wiederholte Niederlagenursache wird nicht reserviert oder dargestellt.

## Campus

- Der Campus trennt drei Ebenen: eine vollflächige Umgebung, die interaktive Welt und eine oberste geclippte Kopfzone.
- Gebäude beginnen mindestens 20 Pixel unter dem 92-Pixel-Campusheader. Grafiken, Hoverkonturen und Klickflächen verwenden denselben Anker und können nie über der Kopfzone zeichnen.
- Die Umgebung füllt den gesamten sichtbaren Bereich und bindet die isometrische Spielfläche durch Horizont, umgebende Flächen und einen Kontaktschatten ein. Eine isolierte Kachelinsel auf leerer Einheitsfarbe ist unzulässig.

## Forschung und Talente

- Dauerhafte Fortschrittsoptionen erscheinen als responsives kompaktes Brett statt als lange Dokumentliste.
- Forschungskarten sind höchstens 76 Pixel hoch; bei 1280×720 stehen exakt vier kompakte Elemente pro Reihe. Sichtbar bleiben Icon, Titel, Rang beziehungsweise Kosten und ein eindeutiger Zustand. Die zentral berechnete Gesamtwirkung belegt keinen Kartenplatz und erscheint ausschließlich im Tooltip beziehungsweise über `ui_info` als `Gesamt: …`.
- `movement_training` und der Run-Ausbau `mobility` verwenden eine gemeinsame semantische Bewegungs- beziehungsweise Trainingsglyphe; ein generisches Fragezeichen oder unbekannter Platzhalter ist dafür unzulässig.
- Talentknoten sind kompakte quadratische Symbolknoten ohne große ActionCard- oder SelectionCard-Fläche. Ein Rootknoten steht oben, drei Spezialisierungen verzweigen darunter über eindeutige abwärts beziehungsweise diagonal abwärts gerichtete Abhängigkeitslinien. Jedes Talent verwendet innerhalb des Baums ein eigenes, semantisch passendes Symbol. Selected-Ring, Rangpips, Lock-Dim und Verfügbarzustand vermitteln Rang und Voraussetzung redundant. Dauerhafte Titel-, Kosten- oder Beschreibungstexte sind im Knoten unzulässig.
- Die vollständige Wirkung erscheint per Maus-Hover als kompakter Tooltip und per `ui_info` als inhaltsgleiche Detailkarte; reiner Tastatur-/Gamepadfokus öffnet nichts. Beide Darstellungen belegen keinen dauerhaften Platz oberhalb des Bretts. Ein nativer Tooltip darf ergänzen, ist aber niemals die einzige Informationsquelle.
- Talenttooltips nennen zuerst Titel und Kosten, danach eine kurze Wirkung und nur die entscheidenden Zahlenfakten. Voraussetzungen oder Sperrgründe erscheinen ausschließlich, wenn sie für die aktuelle Aktion relevant sind.
- Forschung verwendet auf der Zielansicht 1280×720 vier Spalten und reduziert bei kleinerer Breite responsiv. Talentbaum-Revision 4 beginnt mit `treatment_damage_training` und verzweigt in `spread_penetration`, `manual_treatment_aim` und `piercing_persistence`; `piercing_return` bleibt entfernt und erhält keinen neuen sichtbaren Knoten. Die drei Äste besitzen gezeichnete Verbindungen und echte Voraussetzungen. Bei kleiner logischer Breite werden Äste auf zwei beziehungsweise eine Spalte reduziert und vertikal gescrollt.
- Auf niedrigen 200-Prozent-Ansichten bleiben die beiden Progressionstabs sichtbar; Summary und Brett beziehungsweise Baum liegen in einer fokusfolgenden Scrollfläche, während ein über Maus-Hover oder `ui_info` angefordertes Detail als viewportgebundener Tooltip beziehungsweise Detailkarte erscheint. Reiner Fokus öffnet es nicht. Baumränder führen per D-Pad zu Tabs oder Nachbarästen statt in Selbstschleifen. Ein aktiver Elternknoten mit aktiven Nachfolgern erklärt die Sperre und bleibt unverändert, bis die Nachfolger ausdrücklich zurückgesetzt wurden.

## Einstellungen

- Audio, Anzeige und Bedienung verwenden inhaltsgetriebene Bio-Lumen-Gruppen ohne reservierten Leerraum. Desktop darf zwei gleichgewichtete Spalten nutzen; kompakte Ansichten stapeln sie in einem eindeutigen vertikalen Scrollpfad. Entfernte Controls hinterlassen weder leere Zeilen noch offene Fokusnachbarn.
- `UI-Größe` und `Eingabemodus` erscheinen vorerst nicht in den Einstellungen. Die Laufzeit verwendet effektiv 100 Prozent und sichtbare Tastatur-/Mausglyphen. Bereits gespeicherte Skalierungs- und Moduswerte bleiben lesbar und save-kompatibel, beeinflussen diese Darstellung aber nicht.
- Jede Option und jeder Schalter nennt links sichtbar seinen Zweck und hält die Bedienung rechts in derselben mindestens 44 Pixel hohen Zeile. Schalter liegen direkt in dieser Zeile und erhalten keine eigene Hintergrundkachel; namenlose Toggle-Karten sind unzulässig.
- Jede konfigurierbare Aktion besitzt eine kompakte Karte mit kurzer spielerischer Bezeichnung und zwei direkt darunterliegenden Tastaturfeldern. Beide Felder können unabhängig belegt werden, damit beispielsweise `W` und `Pfeil hoch` gleichzeitig bestehen bleiben. Breite Ansichten zeigen drei dieser Karten pro Reihe, mittlere zwei und kompakte eine; interne Aktionsnamen, übergroße Einzelkarten und dekorativer Leerraum sind unzulässig.
- Controller- und Mausbelegungen bleiben für Laufzeit und Save v6 kompatibel, sind in der aktuellen Einstellungsansicht jedoch visuell ausgeblendet. Ihre Entfernung aus der Oberfläche darf bestehende Belegungen nicht löschen oder umdeuten; sichtbare Glyphen bleiben dennoch bei Tastatur/Maus.
- Wird eine Taste gewählt, die bereits einer anderen konfigurierbaren Aktion gehört, öffnet vor jeder Änderung ein kompakter Pflichtdialog. Bestätigen verschiebt die Taste atomar zur neuen Aktion; Abbrechen erhält beide bisherigen Belegungen. Ein Tastendruck darf nie zwei konkurrierende Aktionen auslösen.

## Semantische Varianten

Buttons:

- `PrimaryButton`
- `SecondaryButton`
- `DangerButton`
- `QuietButton`
- `TabButton` und `SelectedTabButton`
- `SelectionCard` und `SelectedCard`

Flächen:

- `PageCanvas`
- `SectionGroup`
- `ActionCard`
- `DocumentInset`
- `ModalSheet`
- `HudVital`, `HudObjective`, `HudAbility` und `HudAlert`

Die bisherigen `Panel*`-Namen bleiben lediglich Kompatibilitätsaliasse. Neue Ansichten verwenden die semantischen Rollen.
- `Badge`

Text:

- `TitleLabel`
- `SectionLabel`
- `EyebrowLabel`
- `BodyLabel`
- `MutedLabel`
- `ValueLabel`

Jeder Button besitzt die Zustände `normal`, `hover`, `pressed`, `focus` und `disabled`. Schaltflächen mit dauerhaftem Ein/Aus-Zustand besitzen zusätzlich einen deckenden `hover_pressed`-Zustand. Auswahl ist eine eigene semantische Variante und kein nachträglicher lokaler Farbaustausch.

## Wiederverwendbare Konstruktion

`AlveolusUIComponents` erzeugt einfache Labels, Buttons, Panels, Karten, Badges, Wertezeilen und Fortschrittsanzeigen. Die Fabrik enthält ausschließlich Struktur. Das Aussehen stammt immer aus `AlveolusVisualTheme`.

`IconTextButton` zentriert Symbol und Beschriftung als gemeinsame Einheit. Buttons mit manuell positioniertem Symbol und separat zentriertem Text sind nicht zulässig.

## Prüfung

Die UI- und Binding-Runner, darunter `tests/style_gallery_runner.gd`, prüfen:

- vollständige Interaktionszustände;
- semantische Theme-Varianten;
- die Einsatzplanung als Golden Reference, einschließlich Teal→Warmgold ausschließlich auf „Behandlung starten“ und Teal→Teal auf allen anderen Primäraktionen;
- Maus-Hover als einzigen automatischen Tooltip-Auslöser sowie stilles Schließen ohne Fokus- oder Aktionswechsel;
- dass Tastatur-/Gamepadfokus allein keine Detailkarte öffnet, `ui_info` jedoch inhaltsgleiche Informationen zeigt und `ui_info` beziehungsweise `ui_cancel` mit erhaltenem Auslöserfokus schließt;
- die sichtbare `ui_info`-Tastaturbelegung und konsistente Tastatur-/Mausglyphen bei dormant erhaltener Gamepadbelegung;
- zwei unabhängige Tastaturplätze je konfigurierbarer Aktion, Save-v6-Erhalt ausgeblendeter Maus-/Controllerbindungen und den atomaren Konfliktdialog;
- vier aktive Schadenstypen mit redundantem Namen, Symbol und Wert sowie ausschließlich effektive Verteidigungs-/Resistenzprozente;
- nackte Radius-/Reichweitenstufenwerte ohne `Stufe`, Pixel oder Weltwerte;
- differenziellen Kontextquellen-Sync mit stabilen IDs, flackerfreier Aktualisierung und viewportgebundener diagonaler Befundplatzierung;
- stabile Charakterwert-Sektionen samt `SimpleIcon`-Zustand, Accessible Name und erhaltenem Aufklappzustand sowie das Grundwerte-only-HUD mit zentral berechneter Niederlagen-Forschungsprognose;
- Komponentenüberschriften und drei normale Vergleichskarten auf Ausbaukarten, den Hinweis `Du kannst 1 Upgrade auswählen.`, lokal zentriertes `Level Up!` und die untertitellose Niederlage `You suck`;
- `Dauer ∞` für die Introplanung sowie die persistent und cleanup-sicher ein-/ausblendbare containerlose `PlainRunPrompt`-Darstellung mit einmalig konsumierter Linksklickbestätigung;
- das kachellose Run-HUD mit verstrichener Rundenzeit, Viererreihen optionaler Werte sowie Abklingzeitspuren für ausschließlich belegte Fähigkeiten;
- Mindestschrift und Kontrast;
- gemeinsame Zentrierung von Symbol und Text;
- Referenzansichten bei der aktuell festen UI-Größe von 100 Prozent; für den laufenden Intro-/HUD-Schnitt genügt ein nativer 1280×720-Smoke;
- Screenshot-Smokes unter `.codex-temp/style-gallery/`.
