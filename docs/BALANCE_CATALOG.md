# ALVEOLUS – aktueller Werte- und Ausbaukatalog

**Stand:** 21. August 2026
**Geprüfte Codebasis:** lokaler Balance-Arbeitsbaum auf Basis von `16122ec`
**Zweck:** Verbindliche Ist-Aufnahme für die nächste Balanceiteration.

Dieses Dokument beschreibt implementierte Werte und Auswahlregeln. Es ist noch
kein finales Ziel-Balancing. Der Erwerbsrhythmus durch Praxis, Offline-Zeit und
Klinikaufträge ist nicht Teil dieser Aufnahme; die Wirkung gekaufter Forschung
im Kampf ist dagegen vollständig enthalten.

## 1. Aktueller Produktumfang

- Ein Einsatzplan enthält genau eine Behandlung und bis zu zwei aktive
  Fähigkeiten.
- Es gibt drei Behandlungen. Impuls ist sofort verfügbar; Streuimpuls
  und Durchdringender Impuls werden durch Forschung freigeschaltet.
- `Stoß` wird durch Forschung freigeschaltet. `Fetter lazer` und der zweite
  aktive Slot werden nach dem ersten Sieg in Fall 1 automatisch freigeschaltet.
  Vier weitere aktive Fähigkeiten bleiben mit ihren Werten sichtbar, aber gesperrt.
- Es gibt derzeit **keine Passivmodule** im aktiven Produktkatalog.
- Dauerhafte Progression besteht aus zehn globalen Forschungen und vier
  Rangtalenten in einem Behandlungsbaum.
- Ein Run enthält 26 Ausbaudefinitionen; endlose Familien besitzen kein Rangmaximum.
- Alle Hauptfälle haben kein Zeitlimit. Der Boss erscheint nach 300 Sekunden.
- Die harte Hauptarena misst **8.640 × 4.860 Weltpunkte**. Spawnraten und
  Gegnerabstände bleiben von dieser dichteren Spielfläche unberührt.
- Das 1.280 × 720 Referenzcanvas nutzt `canvas_items` mit `expand`: Vollbild
  und freie Fensterformate füllen die gesamte Fläche verzerrungsfrei und zeigen
  bei abweichendem Seitenverhältnis entsprechend mehr Welt.

Die spielernahen Begriffe sind **Leben**, **Schaden**, **Regeneration**,
**Schild** und **Verteidigung**. Alte interne Namen wie `stability`,
`contact_damage` oder `support_effect` bleiben nur dort bestehen, wo stabile
IDs oder Save-Kompatibilität sie noch erfordern.

## 2. Doctor Milos

### Grundwerte in Hauptfällen

| Wert | Basis |
|---|---:|
| Leben | 50 |
| Galopp | 180 |
| Körpergröße | Mittel (separate Größenklasse) |
| Erfahrungsradius | Stufe 6 |
| Verteidigung | 0 |
| Regeneration | 0 Leben/s |
| Schild | 0 |
| Erfahrungsmultiplikator | 1,00 |
| Globale Schutzzeit nach einem Gegnertreffer | 0,5 s |

Forschung erhöht diese Basis auf höchstens 59 Leben, 6 Verteidigungsrating
(effektiv 5,6 % Minderung), 0,75 Leben/s Regeneration, 1,15-fache Erfahrung
und ganzzahligen Galopp 196. Behandlungen erhalten bis zu 6 Prozent zusätzlichen
Basisschaden, bevor der Wert ganzzahlig aufgelöst wird.

### Resistenzen

Positive Werte reduzieren Schaden dieses Typs. Negative Werte sind
Verwundbarkeiten.

| Typ | Rating | Effektiv |
|---|---:|---:|
| Feuer | 0 | 0 % |
| Wasser | +10 | +8,8 % Minderung |
| Erde | +5 | +4,7 % Minderung |
| Luft | −10 | −10 % Verwundbarkeit |

### Schadensberechnung

1. Ein Angriff verteilt seinen Grundschaden über sein Schadenstyp-Profil.
2. Für jeden Anteil wird die passende Resistenz angewendet.
3. Danach wirkt allgemeine Verteidigung mit derselben degressiven Kurve und
   einem Cap von 90 Prozent.
4. Ein vorhandenes Schild absorbiert den verbleibenden Schaden.

Positive Resistenz nutzt ein Cap von 75 Prozent; negative Resistenz bleibt bis
−100 Prozent linear. Ein Profil ohne Eintrag für einen Typ ist neutral.

## 3. Schadenstypen

Das Set ist geschlossen und besitzt eine feste technische Reihenfolge:

| Reihenfolge | Typ | Aktuelle Beispiele |
|---:|---|---|
| 1 | Feuer | Streuimpuls |
| 2 | Wasser | Impuls |
| 3 | Erde | Teile der Bakteriengruppe |
| 4 | Luft | Durchdringender Impuls |

`blood`, `holy` und `undead` sind pensionierte Legacy-Authoring-IDs. Sie sind
nicht aktiv und werden nicht neu verwendet.

Gemischte Profile werden vor der Trefferberechnung auf zusammen 100 Prozent
normalisiert.

## 4. Einsatzplanung

| Platz | Anzahl | Aktueller Inhalt |
|---|---:|---|
| Behandlung | genau 1 | Impuls, Streuung oder Durchdringung |
| Aktive Fähigkeit | vor Fall 1 bis 1, danach bis 2 | Stoß und/oder Fetter lazer |
| Passivmodul | 0 | nicht Teil des aktuellen Spiels |
| Reserve | 0 | nur altes Schemafeld |

Technisch existiert noch eine Kapazität von 8. Jede aktuelle Behandlung und
aktive Fähigkeit kostet 2; ein vollständiger produktiver Plan benötigt daher
6. Da keine Passivmodule verfügbar sind, ist die verbleibende Kapazität zurzeit
kein spielerischer Entscheidungswert.

Der Standardplan ist zunächst nur Impuls. Alte
Save-Felder für Passive und Reserve werden bei einem effektiven Plan bereinigt,
ohne stabile IDs aus älteren Spielständen umzubenennen.

## 5. Behandlungen

| Behandlung | Verfügbarkeit | Typ | Schaden | Intervall | Reichweite | Projektile | Treffer je Projektil |
|---|---|---|---:|---:|---:|---:|---:|
| Impuls | sofort | Wasser | 10 | 0,965 s | Stufe 16 | 1 | 1 |
| Streuimpuls | Forschung für 300 | Feuer | 5 je Strahl | 1,00 s | Stufe 15 | 3 | 1 |
| Durchdringender Impuls | Forschung für 500 | Luft | 9 je Treffer | 1,65 s | Stufe 17 | 1 | 4 |

Besonderheiten:

- **Impuls** verfolgt ohne Talent automatisch die nächsten gültigen
  Ziele. Der Run-Ausbau `Zusätzliches Projektil` kann bis zu fünf weitere
  eigenständige Projektile erzeugen.
- **Streuimpuls** erzeugt Strahlen bei −14, 0 und +14 Grad. Jeder Strahl wird
  unabhängig aufgelöst und endet am ersten getroffenen Gegner. Das Rangtalent
  kann jeden Strahl bis zu drei zusätzliche Gegner durchdringen lassen.
- **Durchdringender Impuls** ist zunächst ein einmaliger Linientreffer. Das
  Rangtalent `Anhaltender Laser` macht daraus einen 0,5 oder 1,0 Sekunden langen
  Strahl mit Trefferticks alle 0,25 Sekunden.
- `Manuelle Zielsteuerung` richtet alle drei Behandlungen zur Maus statt zum
  nächsten Gegner aus.
- Die Forschung `Stärkere Behandlung` addiert 2 Prozentpunkte Schaden je Rang
  auf den unveränderten Behandlungsbasiswert. Nach maximal 6 Prozent wird der
  resultierende Schaden einmal ganzzahlig gerundet.

## 6. Aktive Fähigkeiten

| Fähigkeit | Status | Zielart | Abklingzeit | Werte | Schadenstyp |
|---|---|---|---:|---|---|
| Stoß | Forschung für 30 | Zielkreis | 14 s | 0 Schaden, Radiusstufe 5, 120 Rückstoß | keiner |
| Fetter lazer | nach erstem Sieg in Fall 1 | Zielrichtung | 18 s | 30 Schaden, Reichweitenstufe 21, 38 Breite | Wasser |
| Fokusfeld | sichtbar gesperrt | Zielkreis | 16 s | Radiusstufe 6, 7 s, Behandlungsschaden ×1,25 | keiner |
| Notfallhilfe | sichtbar gesperrt | selbst | 28 s | +14 Leben, +8 Schild | keiner |
| Schildfeld | sichtbar gesperrt | Zielkreis | 20 s | Radiusstufe 6, 6 s, Gegnertempo und -schaden ×0,65 | keiner |
| Erfahrungszug | sichtbar gesperrt | Zielkreis | 18 s | Radiusstufe 8, +6 Befundfortschritt | keiner |

Nur Ausbauten für tatsächlich ausgerüstete aktive Fähigkeiten gelangen in den
Run-Pool. Für die vier gesperrten Fähigkeiten existieren derzeit keine
zugehörigen Run-Ausbaustufen.

## 7. Passivmodule

**Aktive Anzahl: 0.** Passivmodule erscheinen weder als wählbare noch als
ausgegraute Produktkarten. Alte Felder und einzelne Kompatibilitätsmethoden im
Code sind kein aktiver Balanceinhalt und dürfen nicht als versteckte Boni
interpretiert werden.

## 8. Forschung

Neun kaufbare Forschungen wirken global oder schalten eine Komponente frei.
Ein zehntes Forschungsfeld zeigt den nicht käuflichen Fall-1-Meilenstein für
`Fetter lazer`.

| Forschung | Ränge | Kosten je Rang | Wirkung je Rang | Maximum |
|---|---:|---|---|---|
| Mehr Leben | 3 | 50 / 350 / 800 | +3 maximales Leben | +9 Leben |
| Stärkere Behandlung | 3 | 63 / 425 / 950 | +2 % Behandlungsschaden | +6 % vor Ganzzahlauflösung |
| Mehr Erfahrung | 3 | 63 / 425 / 950 | +5 % Erfahrung | +15 % |
| Mehr Verteidigung | 3 | 75 / 450 / 1000 | +2 Verteidigung | +6 |
| Lebensregeneration | 3 | 75 / 450 / 1000 | +0,25 Leben/s | +0,75 Leben/s |
| Mehr Galopp | 3 | 75 / 450 / 1000 | +3 % Galopp, ganzzahlig | Galopp 196 |
| Streuimpuls | 1 | 300 | Behandlung freischalten | freigeschaltet |
| Durchdringender Impuls | 1 | 500 | Behandlung freischalten | freigeschaltet |
| Stoß | 1 | 30 | aktive Fähigkeit freischalten | freigeschaltet |
| Fetter lazer | 1 | Abschluss Fall 1 | aktive Fähigkeit und zweiten Aktivslot freischalten | freigeschaltet |

Der reguläre kaufbare Vollausbau kostet insgesamt **9.481 Forschungspunkte**. Ein neuer
Spielstand startet mit 0 Forschung. Introabschluss oder Überspringen vergeben einmalig
exakt 30 Forschung und keinen Talentpunkt. Der Introboss erhöht diesen Sondergrant
nicht; 30 entspricht genau dem Kaufpreis von Stoß. Der erste
Talentpunkt wird mit dem Abschluss von Fall 2 verdient. Forschungs- und
Talentreset erstatten beziehungsweise befreien alle investierten Punkte. Die
Einführung verwendet ihre feste Lehrkonfiguration.

Der Talentbaum ist bis zum ersten erfolgreichen Abschluss von Fall 2 vollständig
gesperrt; Introabschluss, Intro-Skip und Fall 1 umgehen die Sperre nicht. Vor dem ersten Sieg in Fall 1 zeigt `Fetter lazer` Fragezeichen,
Schloss und die Meilensteinbedingung; gespeicherte Forschungsränge umgehen sie
nicht.

## 9. Behandlungs-Talentbaum

| Talent | Max. Rang | Kosten | Voraussetzung | Wirkung |
|---|---:|---:|---|---|
| Behandlungsgrundlage | 1 | 1 | keine | +2 Schaden aller drei Grundbehandlungen. |
| Durchdringende Streuung | 3 | 1 je Rang | Behandlungsgrundlage | +1 möglicher Gegner je Streuimpuls-Strahl und Rang. |
| Manuelle Zielsteuerung | 1 | 1 | Behandlungsgrundlage | Alle Behandlungen schießen zur Maus. |
| Anhaltender Laser | 2 | 1 je Rang | Behandlungsgrundlage | +0,5 s Strahldauer je Rang; Tick alle 0,25 s. |

Der vollständige Baum kostet **7 Talentpunkte**. Bei 0,5 Sekunden Dauer trifft
eine Phase zu 0,00 und 0,25 Sekunden; bei 1,0 Sekunde zu 0,00, 0,25, 0,50 und
0,75 Sekunden. `piercing_return` bleibt entfernt und reserviert. Savegame-
Version 6 und Talentbaum-Revision 4 setzen Revision-3-Belegungen atomar zurück
und bewahren Meisterschaft sowie Forschung.

Der Baum kann über den Fortschrittsscreen zurückgesetzt werden.

## 10. Run-Ausbaustufen

Schaden, Attack Speed und Galopp besitzen je eine endlos sammelbare Familie.
Common gewährt +3, Magic +5 und Rare +7; bei gleicher Relevanz gilt für
Angebote immer Common häufiger als Magic häufiger als Rare. Vollständige
Dreierfamilien verwenden 70 / 25 / 5. Pro Level-up kann dieselbe
Komponente-Wert-Familie höchstens einmal erscheinen. Karten zeigen nur den
gemeinsamen Rundenzähler. Der Rahmen signalisiert Common in Elfenbein, Magic in
Kobalt und Rare in Gold.

### Allgemeine Behandlung

| Ausbau | Seltenheiten | Wirkung | Grenze | Voraussetzung |
|---|---|---|---|---|
| Behandlungsschaden | Common / Magic / Rare | +3 / +5 / +7 Schaden | unbegrenzt | ausgewählte Behandlung |
| Attack Speed | Common / Magic / Rare | +3 / +5 / +7 Prozentpunkte | unbegrenzt, linear | ausgewählte Behandlung |
| Zusätzliches Projektil | Rare | +1 Projektil | +5, Basis 1 → maximal 6 | Impuls |

Das frühere allgemeine Reichweitenupgrade ist nicht mehr im aktiven Katalog.
Projektilkarten werden nach jeder Wahl seltener; ihr internes Cap wird nicht auf
der Karte angezeigt.

### Abwehrzellen

| Ausbau | Seltenheiten/Ränge | Wirkung | Grenze | Voraussetzung |
|---|---|---|---|---|
| Abwehrzellen | 1 Wahl | System aktivieren | 2 Zellen | keine |
| Abwehrzellenschaden | Common / Magic / Rare | +3 / +5 / +7 Schaden | unbegrenzt | Abwehrzellen |
| Attack Speed | Common / Magic / Rare | +3 / +5 / +7 Prozentpunkte | unbegrenzt, linear | Abwehrzellen |
| Größere Abwehrzellen | 3 Wahlen | +1 Radius | Radius 7 | Abwehrzellen |
| Mehr Abwehrzellen | 2 Wahlen | +1 Projektil | 4 Zellen | Abwehrzellen |

### Behandlungsspezifisch

| Ausbau | Wahlen | Pro Wahl | Maximum | Voraussetzung |
|---|---:|---|---|---|
| Dichter Streuimpuls | 3 | +1 Projektil | 6 Projektile | Streuimpuls |
| Tieferer Impuls | 2 | +2 maximale Treffer | 8 Treffer | Durchdringender Impuls |

### Aktive Fähigkeiten

| Ausbau | Seltenheiten/Wahlen | Wirkung | Grenze | Voraussetzung |
|---|---|---|---|---|
| Breiter Stoß | 2 Wahlen | +1 Radius | Radius 7 | Stoß ausgerüstet |
| Lazerschaden | Common / Magic / Rare | +3 / +5 / +7 Schaden | unbegrenzt | Fetter lazer ausgerüstet |
| Breiterer Lazer | 2 Wahlen | +16 Breite | 70 Breite | Fetter lazer ausgerüstet |
| Galopp | Common / Magic / Rare | +3 / +5 / +7 Galopp | unbegrenzt | keine |

Stoß besitzt 0 Schaden und hat keinen Schadensausbau. Ein späterer Talentknoten
darf diese Familie ausdrücklich freischalten; in diesem Meilenstein existiert
sie nicht.

Die erste Auswahl eines normalen Levelaufstiegs enthält, solange noch ein
passender Rang verfügbar ist, mindestens einen Ausbau der ausgerüsteten
Behandlung. Ein einmaliger Reroll schließt die vorherigen Karten aus, garantiert
derzeit aber nicht erneut einen Behandlungsausbau.

## 11. Abwehrzellen im Kampf

Nach Wahl des Ausbaus `Abwehrzellen` gelten:

| Wert | Basis | Voll ausgebaut |
|---|---:|---:|
| Zellen | 2 | 4 |
| Schaden je Treffer | 5 Wasser | 17 Wasser |
| Trefferkörper je Zelle | feste sichtbare Zellgröße | unverändert |
| Orbit-Radius um Doctor Milos | Radius 4 | Radius 7 |
| Orbit-Geschwindigkeit | 1,7 rad/s | 1,7 rad/s |
| Trefferintervall | 0,2 s je Zelle (5/s) | 0,2 s je Zelle (5/s) |
| Ziele je Zelle und Tick | höchstens 1 | höchstens 1 |

Schaden entsteht ausschließlich, wenn der tatsächliche Kreis einer einzelnen
Zelle einen Gegner geometrisch berührt. Ein gemeinsamer unsichtbarer
Avatar-Radius verursacht keinen Schaden. Jede Zelle besitzt ihren eigenen
Cooldown und verwendet einen generationssicheren Gegnerhandle.

Die technische Untergrenze bleibt 0,1 Sekunden je Zelle und ist für spätere
Attack-Speed-Ausbaupfade reserviert.

## 12. Gegner

### Unskalierte Grundwerte

| Gegner | Leben | Tempo | Berührungsschaden | Projektil | Schadenstyp | Erfahrung | Größenklasse | Resistenzen (Rating; positiv effektiv) |
|---|---:|---:|---:|---:|---|---:|---:|---|
| Bakterium | 22 | 85 | 2 | – | 100 % Feuer | 1 | Klein | Wasser +10 (+8,8 %), Erde −10 |
| Bakteriengruppe | 74 | 85 | 5 | – | 60 % Erde, 40 % Feuer | 4 | Mittel | Erde +20 (+15,8 %), Feuer −15 |
| Kleiner Herd | 180 | 38 | 0 | 2 alle 2,6 s | 100 % Luft | 8 | Groß | Luft +25 (+18,8 %), Wasser −20 |
| Bakterienkern | 900 | 66 | 6 | 4 alle 0,89 s in Fall 2 | 40 % Feuer, 60 % Luft | 20 | Boss | Feuer +15 (+12,5 %), Luft +25 (+18,8 %), Wasser −15 |
| Infektionsherd | 2.200 | 72 | 9 | 2 × 4 alle 1,6 s | 40 % Feuer, 60 % Luft | 30 | Boss | Feuer +15 (+12,5 %), Luft +25 (+18,8 %), Wasser −15 |

Der kleine Herd ist ein **mobiles** Nebenziel. Beim Befund `Verdeckte Nester`
erscheint er mit 180 Leben auf einem der katalogisierten Spawnringe, bewegt
sich mit seinem fallskalierten Tempo auf Doctor Milos zu und setzt nach 20
Sekunden vier Bakterien an seiner aktuellen Position frei, falls er lebt.
Der geskriptete mobile Eventherd in Fall 1 bildet die einzige Ausnahme: Er
verwendet ganzzahliges Basistempo 60, feuert alle 1,39 Sekunden und seine
normalen Projektile besitzen 1,5-fache Geschwindigkeit sowie 1,5-fache
Querbreite und Trefferfläche. Ein Treffer mit Stoß sperrt seinen Beschuss zehn
Sekunden; Bewegung und sonstiger Status laufen unverändert weiter. Andere kleine
Herde behalten das Tabellenprofil. Das mobile Fall-2-Event besitzt 1.800
gemeinsames Leben, erscheint als Verbund kleiner Bakterien mit neun gleich
gefüllten symbolischen Lebensbalken und nimmt ausschließlich von `Fetter lazer`
zehnfachen Schaden.

Der Rauten-Infektionsherd feuert fortlaufend zwei Projektile mit 212,5 Tempo auf
gespiegelten, gegenüber dem vorherigen Stand um 25 Prozent weiter ausgelenkten
Bahnen. Bei 70 und 40 Prozent Leben
erscheinen jeweils vier schießende Bakterien. Nach Phase zwei folgen alle 20
Sekunden weitere vier; ihre Projektile fliegen mit 322,5 Tempo. Der Fall-1-
Bakterienkern aus Fall 1 ruft ab Bossspawn alle 15 Sekunden vier gewöhnliche kleine
Bakterien. Seine Aura besitzt 120 Prozent Bildschirmdurchmesser beziehungsweise
60 Prozent der kürzeren Bildschirmkante als Radius und erhöht Tempo und Schaden
naher Nichtbosse um 45 Prozent. Gegnerschaden wird mit dem Fallfaktor multipliziert und
anschließend gegen Resistenzen, Verteidigung und Schild von Doctor Milos
aufgelöst. Nach einem gültigen Treffer schützt die globale 0,5-Sekunden-Frist
vor einem sofortigen weiteren Gegnertreffer.

Der Bakterienkern aus Fall 2 schießt alle 0,89 Sekunden ein Projektil. Nach 50
Prozent der kürzeren sichtbaren Bildschirmkante biegt es um 90 Grad nach links
oder rechts ab, nach weiteren 20 Prozent erneut in dieselbe Richtung. Die Seite
wechselt deterministisch zwischen den Schüssen. Alle 15 Sekunden sowie in seiner
Lebensphase entstehen vier schießende Bakterien; ein Stoß beendet ihren Beschuss
für den restlichen Lebenszyklus.

## 13. Fälle und Fortschrittskurven

### Hauptfälle

Alle Kurven laufen über die ersten 300 Sekunden bis zum Bossspawn und bleiben
danach auf ihrem Endwert. Es gibt keine Ablaufzeit.

| Fall | Titel | Standardintervall | Leben | Tempo | Schaden | Gruppen | Bossleben | Phasenadds | Forschung |
|---:|---|---|---|---:|---:|---|---:|---|---:|
| 1 | Früher Verlauf | 1,16125 → 0,26875 s | 1,05 → 1,525 | 1,04 | 1,15 | 6 → 23 % | 0,75 | 2 / – | 0,85 |
| 2 | lol - name fehlt | 1,03375 → 0,23375 s | 1,15 → 1,70 | 1,08 | 1,25 | 10 → 28 % | 1,00 | 3 / – | 1,00 |
| 3 | Fortschreitender Verlauf | 0,9075 → 0,200 s | 1,25 → 1,875 | 1,12 | 1,35 | 14 → 33 % | 0,60 | 3 / 3 | 1,175 |
| 4 | Die Ausbreitung | 0,780 → 0,165 s | 1,35 → 2,05 | 1,16 | 1,45 | 18 → 38 % | 0,75 | 4 / 4 | 1,35 |
| 5 | Kritischer Verlauf | 0,720 → 0,150 s | 1,45 → 2,225 | 1,20 | 1,55 | 21,5 → 43 % | 1,05 | 5 / 6 | 1,525 |
| 6 | Schwerer Verlauf | 0,660 → 0,135 s | 1,55 → 2,40 | 1,24 | 1,65 | 25 → 48 % | 1,35 | 6 / 8 | 1,70 |

Die Standardzufuhr erscheint als klar erkennbare Pakete. Die seit dem letzten
Paket vergangene aktive Simulationszeit sammelt mit Faktor 1,10 Guthaben aus der
weiterhin anfangs gedehnten Intervallkurve; spätestens nach 4,5 Sekunden folgt
das nächste. Sind nach mindestens zwei Sekunden 70 Prozent des aktuellen
Wellengewichts besiegt, darf es früher folgen und fällt entsprechend kleiner
aus. Damit ist die Gesamtzufuhr moderat zehn Prozent schneller, unabhängig von
der Tötungsgeschwindigkeit; starke Builds verändern den Rhythmus, vervielfachen
aber weder Gegner, EXP noch Levelprogression.

| Fall | Körper im ersten Timeout-Paket | Körper im späten Timeout-Paket (ca.) |
|---:|---:|---:|
| 1 | 4 | 23 |
| 2 | 4 | 26 |
| 3 | 5 | 31 |
| 4 | 6 | 37 |
| 5 | 6 | 41 |
| 6 | 7 | 45 |

Die exakte späte Zahl bleibt seed-stabil und enthält die bestehende
22-Prozent-Chance auf einen zweiten Körper je Slot. `+10 % mehr Monsterspawn`
vergrößert das Paket über die Intervallkurve. Ein Paket nutzt abhängig von
seiner Größe ein bis drei druckarme Offscreen-Fronten und materialisiert
höchstens vier Körper je Fixed Tick. Unter vier freien Gewichtspunkten öffnet
keine Restwelle. Startgegner bilden Welle 0; Introgegner, Bosse,
Phasenverstärkungen, kleine Herde und deren geskriptete Freisetzungen behalten
ihre ausdrücklichen Zeitpunkte. Das Aktivlimit von 145 gewichteten
Nahkampfeinheiten sammelt keinen späteren Spawnrückstau.

Das Intro ist ereignisgesteuert, beginnt ebenfalls mit 50 Leben und besitzt
weder Zeitlimit noch zufällige Fallparameter. Der erste Erreger bleibt nach
seiner Materialisierung drei Sekunden ohne Autoangriff beobachtbar. Danach
bestätigt ein Linksklick den Angriff. Genau drei normale Ein-Punkt-Erfahrungen lösen
eine Auswahl aus drei gültigen Ausbauten für `treatment_precision` aus; nach der
Auswahl wartet der einfache Altboss erneut in einer Linksklick-Pause. Er besitzt
effektiv 198 Leben und sein einzelnes normales Projektil verursacht effektiv 3
Schaden. Der erste Sieg kehrt direkt zum Campus zurück und vergibt exakt 30
Forschung; der Intro-Skip vergibt ebenfalls exakt 30. Beide vergeben keinen
Talentpunkt.

Alle positiven Run-Forschungseinnahmen werden zentral mit 3,75 multipliziert;
die separate Introgrundbelohnung beträgt exakt 30 und verwendet keinen
Bossmultiplikator. Kosten und Rückerstattungen bleiben
unverändert. Zusätzlich gilt am Rundenende der
Bossmultiplikator `1 + 0,25 × besiegte Bosse`; gerundet wird genau einmal am Ende.

### Variationsregel

- Ein Fall ohne früheren Sieg startet ohne Merkmal und ohne Befund.
- Der erste Sieg selbst enthält daher noch keine Zufallsparameter.
- Ab dem nächsten Versuch werden genau ein Merkmal und ein Befund
  deterministisch aus dem gespeicherten Fallseed gewählt.
- Nur ein Sieg rotiert diesen Seed. Niederlage, Abbruch und Neustart behalten
  dieselbe Kombination.

### Fallmerkmale

| Merkmal | Wirkung |
|---|---|
| Resistente Erreger | +20 effektive Resistenzpunkte aller Typen |
| Gepanzerte Erreger | +10 Gegnerverteidigung |
| Schnelle Erreger | +15 % Gegnergalopp |
| Robuste Erreger | +15 % Leben regulärer Gegner und Bosse |
| Aggressive Erreger | +15 % Gegnerschaden |
| Doppelherd | zwei Bosse |
| Hohe Keimlast | +10 % Spawnrate |
| Lerngewinn | +10 % Erfahrung |

### Befunde und Reaktionen

| Befund | Grundwirkung | Reaktion 1 | Reaktion 2 | Reaktion 3 |
|---|---|---|---|---|
| Gruppenbildung | +18 Prozentpunkte Bakteriengruppen | +20 % Schaden gegen Gruppen | Gruppen-Kontrolle ×1,30 | −25 % Gruppenschaden |
| Verdeckte Nester | Beim Aufdecken 2 kleine Herde; nach 20 s je 4 Bakterien | +25 % Schaden gegen Herde | Reichweite ×1,20 und +1 Treffer | Herde geben +4 Erfahrung |

## 14. Level und Erfahrung

- Ein Run beginnt auf Level 0 mit einem Ziel von 5 Erfahrung.
- Nach einem Levelaufstieg lautet das nächste Ziel
  `round(6 + Level^1,35 × 3,2)`.
- Die ersten Ziele sind dadurch 5, 9, 14, 20, 27 und 34 Erfahrung.
- Bakterium, Gruppe, kleiner Herd und Boss geben unskaliert 1, 4, 8 und 30
  Erfahrung. Forschung multipliziert den Gewinn und führt Bruchteile über mehrere
  Aufnahmen verlustfrei fort.
- Ein regulärer Aufstieg pausiert die Runde, zeigt drei Ausbauten und setzt die
  Simulation erst nach der Auswahl fort.

## 15. Noch nicht als Balance entschieden

- Zahlen und Kurven sind ein implementierter Teststand, keine bestätigte
  Zielschwierigkeit.
- Schadenstypen und Resistenzen funktionieren technisch, besitzen aber noch
  keinen ausgearbeiteten strategischen Freischalt- oder Konterkreislauf.
- Die verbleibende Loadoutkapazität hat ohne Passivmodule noch keine Funktion.
- Der einmalige Reroll garantiert aktuell keinen erneuten Behandlungsausbau.
- Fokusfeld, Notfallhilfe, Schildfeld und Erfahrungszug besitzen Werte und Handler,
  sind aber nicht Teil der aktuellen auswählbaren Balance.
- Passivmodule und die früheren drei Talentäste sind ausdrücklich kein
  ruhender Balancekatalog, sondern entfernt. Eine spätere Rückkehr wäre ein
  neues Design und keine bloße Freischaltung alter Werte.
