# ALVEOLUS – aktueller Werte- und Ausbaukatalog

**Stand:** 18. August 2026  
**Geprüfte Codebasis:** Arbeitsbaum auf Basis von `15cef65`  
**Zweck:** Verbindliche Ist-Aufnahme für die nächste Balanceiteration.

Dieses Dokument beschreibt implementierte Werte und Auswahlregeln. Es ist noch
kein finales Ziel-Balancing. Der Erwerbsrhythmus durch Praxis, Offline-Zeit und
Klinikaufträge ist nicht Teil dieser Aufnahme; die Wirkung gekaufter Forschung
im Kampf ist dagegen vollständig enthalten.

## 1. Aktueller Produktumfang

- Ein Einsatzplan enthält genau eine Behandlung und bis zu zwei aktive
  Fähigkeiten.
- Es gibt drei Behandlungen. Präziser Impuls ist sofort verfügbar; Streuimpuls
  und Durchdringender Impuls werden durch Forschung freigeschaltet.
- Abwehrstoß und Behandlungslinie sind auswählbar. Vier weitere aktive
  Fähigkeiten bleiben mit ihren Werten sichtbar, aber gesperrt.
- Es gibt derzeit **keine Passivmodule** im aktiven Produktkatalog.
- Dauerhafte Progression besteht aus sieben globalen Forschungen und vier
  Rangtalenten in einem Behandlungsbaum.
- Ein Run enthält 17 verschiedene Ausbauten mit insgesamt 43 möglichen Rängen.
- Alle Hauptfälle haben kein Zeitlimit. Der Boss erscheint nach 180 Sekunden.

Die spielernahen Begriffe sind **Leben**, **Schaden**, **Regeneration**,
**Schild** und **Verteidigung**. Alte interne Namen wie `stability`,
`contact_damage` oder `support_effect` bleiben nur dort bestehen, wo stabile
IDs oder Save-Kompatibilität sie noch erfordern.

## 2. Doctor Milos

### Grundwerte in Hauptfällen

| Wert | Basis |
|---|---:|
| Leben | 100 |
| Bewegungstempo | 275 px/s |
| Körperradius | 23 px |
| Probenradius | 185 px |
| Verteidigung | 0 |
| Regeneration | 0 Leben/s |
| Schild | 0 |
| Erfahrungsmultiplikator | 1,00 |
| Globale Schutzzeit nach einem Gegnertreffer | 0,68 s |

Forschung erhöht diese Basis auf höchstens 109 Leben, 6 Verteidigung,
0,75 Leben/s Regeneration und 1,15-fache Erfahrung. Die Behandlung erhält
zusätzlich bis zu 6 Prozent Schaden.

### Resistenzen

Positive Werte reduzieren Schaden dieses Typs. Negative Werte sind
Verwundbarkeiten.

| Feuer | Wasser | Erde | Wind | Blut | Holy | Undead |
|---:|---:|---:|---:|---:|---:|---:|
| +5 % | +10 % | +5 % | 0 % | 0 % | +15 % | −10 % |

### Schadensberechnung

1. Ein Angriff verteilt seinen Grundschaden über sein Schadenstyp-Profil.
2. Für jeden Anteil wird die passende Resistenz angewendet.
3. Danach wirkt allgemeine Verteidigung mit
   `100 / (100 + Verteidigung)`.
4. Ein vorhandenes Schild absorbiert den verbleibenden Schaden.

Resistenzen sind auf −100 bis +95 Prozent begrenzt. Ein Profil ohne Eintrag für
einen Typ behandelt diesen Typ neutral.

## 3. Schadenstypen

Das Set ist geschlossen und besitzt eine feste technische Reihenfolge:

| Reihenfolge | Typ | Aktuelle Beispiele |
|---:|---|---|
| 1 | Feuer | Streuimpuls |
| 2 | Wasser | Präziser Impuls |
| 3 | Erde | Abwehrstoß, Teile der Bakteriengruppe |
| 4 | Wind | Durchdringender Impuls |
| 5 | Blut | Bakterium, Teile von Gruppe und Boss |
| 6 | Holy | Behandlungslinie, Abwehrzellen |
| 7 | Undead | Kleiner Herd, Teile des Bosses |

Gemischte Profile werden vor der Trefferberechnung auf zusammen 100 Prozent
normalisiert.

## 4. Einsatzplanung

| Platz | Anzahl | Aktueller Inhalt |
|---|---:|---|
| Behandlung | genau 1 | Präzise, Streuung oder Durchdringung |
| Aktive Fähigkeit | 0 bis 2 | Abwehrstoß und/oder Behandlungslinie |
| Passivmodul | 0 | nicht Teil des aktuellen Spiels |
| Reserve | 0 | nur altes Schemafeld |

Technisch existiert noch eine Kapazität von 8. Jede aktuelle Behandlung und
aktive Fähigkeit kostet 2; ein vollständiger produktiver Plan benötigt daher
6. Da keine Passivmodule verfügbar sind, ist die verbleibende Kapazität zurzeit
kein spielerischer Entscheidungswert.

Der Standardplan ist Präziser Impuls, Abwehrstoß und Behandlungslinie. Alte
Save-Felder für Passive und Reserve werden bei einem effektiven Plan bereinigt,
ohne stabile IDs aus älteren Spielständen umzubenennen.

## 5. Behandlungen

| Behandlung | Verfügbarkeit | Typ | Schaden | Intervall | Reichweite | Projektile | Treffer je Projektil |
|---|---|---|---:|---:|---:|---:|---:|
| Präziser Impuls | sofort | Wasser | 18 | 0,82 s | 470 | 1 | 1 |
| Streuimpuls | Forschung für 60 | Feuer | 8 je Strahl | 1,00 s | 440 | 3 | 1 |
| Durchdringender Impuls | Forschung für 100 | Wind | 14 je Treffer | 1,10 s | 520 | 1 | 4 |

Besonderheiten:

- **Präziser Impuls** verfolgt ohne Talent automatisch das nächste gültige
  Ziel. Der Run-Ausbau `Zusätzliches Ziel` kann bis zu drei Ziele erzeugen.
- **Streuimpuls** erzeugt Strahlen bei −14, 0 und +14 Grad. Jeder Strahl wird
  unabhängig aufgelöst und endet am ersten getroffenen Gegner. Das Rangtalent
  kann jeden Strahl bis zu drei zusätzliche Gegner durchdringen lassen.
- **Durchdringender Impuls** ist zunächst ein einmaliger Linientreffer. Das
  Rangtalent `Anhaltender Laser` macht daraus einen 0,5 oder 1,0 Sekunden langen
  Strahl mit Trefferticks alle 0,25 Sekunden.
- `Manuelle Zielsteuerung` richtet alle drei Behandlungen zur Maus statt zum
  nächsten Gegner aus.
- Die Forschung `Stärkere Behandlung` multipliziert den Grundschaden der
  ausgewählten Behandlung vor den Run-Ausbaustufen mit bis zu 1,06.

## 6. Aktive Fähigkeiten

| Fähigkeit | Status | Zielart | Abklingzeit | Werte | Schadenstyp |
|---|---|---|---:|---|---|
| Abwehrstoß | auswählbar | Zielkreis | 14 s | 42 Schaden, 150 Radius, 75 Rückstoß | Erde |
| Behandlungslinie | auswählbar | Zielrichtung | 18 s | 55 Schaden, 620 Reichweite, 38 Breite | Holy |
| Fokusfeld | sichtbar gesperrt | Zielkreis | 16 s | 165 Radius, 7 s, Behandlungsschaden ×1,25 | keiner |
| Notfallhilfe | sichtbar gesperrt | selbst | 28 s | +14 Leben, +8 Schild | keiner |
| Schildfeld | sichtbar gesperrt | Zielkreis | 20 s | 185 Radius, 6 s, Gegnertempo und -schaden ×0,65 | keiner |
| Probenzug | sichtbar gesperrt | Zielkreis | 18 s | 230 Radius, +6 Befundfortschritt | keiner |

Nur Ausbauten für tatsächlich ausgerüstete aktive Fähigkeiten gelangen in den
Run-Pool. Für die vier gesperrten Fähigkeiten existieren derzeit keine
zugehörigen Run-Ausbaustufen.

## 7. Passivmodule

**Aktive Anzahl: 0.** Passivmodule erscheinen weder als wählbare noch als
ausgegraute Produktkarten. Alte Felder und einzelne Kompatibilitätsmethoden im
Code sind kein aktiver Balanceinhalt und dürfen nicht als versteckte Boni
interpretiert werden.

## 8. Forschung

Alle sieben Forschungen wirken global und benötigen kein ausgerüstetes Modul.

| Forschung | Ränge | Kosten je Rang | Wirkung je Rang | Maximum |
|---|---:|---|---|---|
| Mehr Leben | 3 | 20 / 45 / 80 | +3 maximales Leben | +9 Leben |
| Stärkere Behandlung | 3 | 25 / 55 / 95 | +2 % Behandlungsschaden | +6 % |
| Mehr Erfahrung | 3 | 25 / 55 / 95 | +5 % Erfahrung aus Proben | +15 % |
| Mehr Verteidigung | 3 | 30 / 60 / 100 | +2 Verteidigung | +6 |
| Lebensregeneration | 3 | 30 / 60 / 100 | +0,25 Leben/s | +0,75 Leben/s |
| Streuimpuls | 1 | 60 | Behandlung freischalten | freigeschaltet |
| Durchdringender Impuls | 1 | 100 | Behandlung freischalten | freigeschaltet |

Der reguläre Vollausbau kostet insgesamt **1.035 Forschungspunkte**. Im lokalen
Testmodus stehen 1.000.000.000 Punkte zur Verfügung; Forschung lässt sich dort
vollständig zurücksetzen. Die Einführung verwendet ihre feste Lehrkonfiguration
und übernimmt diese Metawerte nicht.

## 9. Behandlungs-Talentbaum

| Talent | Max. Rang | Kosten | Voraussetzung | Wirkung |
|---|---:|---:|---|---|
| Manuelle Zielsteuerung | 1 | 1 | keine | Alle Behandlungen schießen zur Maus. |
| Durchdringende Streuung | 3 | 1 je Rang | Manuelle Zielsteuerung | +1 möglicher Gegner je Streuimpuls-Strahl und Rang. |
| Anhaltender Laser | 2 | 1 je Rang | Manuelle Zielsteuerung | +0,5 s Strahldauer je Rang; Tick alle 0,25 s. |
| Rückkehrender Laser | 1 | 1 | Anhaltender Laser | Nach der Vorwärtsphase läuft dieselbe Strahlphase rückwärts. |

Der vollständige Baum kostet **7 Talentpunkte**. Bei 0,5 Sekunden Dauer trifft
eine Phase zu 0,00 und 0,25 Sekunden; bei 1,0 Sekunde zu 0,00, 0,25, 0,50 und
0,75 Sekunden. Der Rückweg wiederholt diese Tickfolge. Savegame-Version 6 und
Talentbaum-Revision 3 erstatten alte, nicht mehr passende Talentbelegungen und
bewahren Meisterschaft.

Im lokalen Testmodus stehen 1.000.000.000 Talentpunkte zur Verfügung und der
Baum kann zurückgesetzt werden.

## 10. Run-Ausbaustufen

### Allgemeine Behandlung

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Stärkerer Impuls | 3 | +8 Schaden | +24 Schaden | beliebige Behandlung |
| Schnellere Impulse | 3 | Intervall ×0,84 | Intervall ×0,5927 | beliebige Behandlung |
| Mehr Reichweite | 2 | +85 Reichweite | +170 | beliebige Behandlung |
| Zusätzliches Ziel | 2 | +1 Ziel | +2 Ziele | Präziser Impuls |

### Abwehrzellen

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Abwehrzellen | 1 | System aktivieren | 2 Zellen | keine |
| Stärkere Abwehrzellen | 3 | +6 Schaden | 28 Schaden | Abwehrzellen |
| Größere Abwehrzellen | 3 | +4 Trefferradius | 27 Radius | Abwehrzellen |
| Mehr Abwehrzellen | 2 | +1 Zelle | 4 Zellen | Abwehrzellen |

### Behandlungsspezifisch

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Ruhiger Fokus | 3 | Schaden ×1,18 | Schaden ×1,6430 | Präziser Impuls |
| Dichter Streuimpuls | 3 | +1 Projektil | 6 Projektile | Streuimpuls |
| Kräftigere Streuung | 3 | +3 Schaden | 17 Schaden je Projektil | Streuimpuls |
| Tieferer Impuls | 2 | +2 maximale Treffer | 8 Treffer | Durchdringender Impuls |
| Stärkere Linie | 3 | +5 Schaden | 29 Schaden je Treffer | Durchdringender Impuls |

### Aktive Fähigkeiten

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Kräftiger Abwehrstoß | 3 | +14 Schaden | 84 Schaden | Abwehrstoß ausgerüstet |
| Breiter Abwehrstoß | 2 | +30 Radius | 210 Radius | Abwehrstoß ausgerüstet |
| Stärkere Behandlungslinie | 3 | +18 Schaden | 109 Schaden | Behandlungslinie ausgerüstet |
| Breitere Behandlungslinie | 2 | +16 Breite | 70 Breite | Behandlungslinie ausgerüstet |

Die Spalte `Voll ausgebaut` zeigt jeden Ausbau isoliert auf seinem jeweiligen
Grundwert. Kombinierte Additionen, Forschungsmultiplikatoren und weitere
Ausbauten werden im tatsächlichen Build gemeinsam aufgelöst; die Tabelle ist
daher keine Obergrenze für den fertigen Run-Schaden.

Die erste Auswahl eines normalen Levelaufstiegs enthält, solange noch ein
passender Rang verfügbar ist, mindestens einen Ausbau der ausgerüsteten
Behandlung. Ein einmaliger Reroll schließt die vorherigen Karten aus, garantiert
derzeit aber nicht erneut einen Behandlungsausbau.

## 11. Abwehrzellen im Kampf

Nach Wahl des Ausbaus `Abwehrzellen` gelten:

| Wert | Basis | Voll ausgebaut |
|---|---:|---:|
| Zellen | 2 | 4 |
| Schaden je Treffer | 10 Holy | 28 Holy |
| Trefferradius je Zelle | 15 | 27 |
| Orbit-Radius um Doctor Milos | 98 px | 98 px |
| Orbit-Geschwindigkeit | 1,7 rad/s | 1,7 rad/s |
| Kürzestes Trefferintervall | 0,1 s je Zelle | 0,1 s je Zelle |
| Ziele je Zelle und Tick | höchstens 1 | höchstens 1 |

Schaden entsteht ausschließlich, wenn der tatsächliche Kreis einer einzelnen
Zelle einen Gegner geometrisch berührt. Ein gemeinsamer unsichtbarer
Avatar-Radius verursacht keinen Schaden. Jede Zelle besitzt ihren eigenen
Cooldown und verwendet einen generationssicheren Gegnerhandle.

## 12. Gegner

### Unskalierte Grundwerte

| Gegner | Leben | Tempo | Schaden | Schadenstyp | Proben | Radius | Resistenzen |
|---|---:|---:|---:|---|---:|---:|---|
| Bakterium | 22 | 92 | 2,2 | 100 % Blut | 1 | 18 | Wasser +10 %, Erde −10 % |
| Bakteriengruppe | 74 | 55 | 5 | 60 % Erde, 40 % Blut | 4 | 30 | Erde +20 %, Feuer −15 % |
| Kleiner Herd | 180 | 12 | 0 | 100 % Undead | 8 | 38 | Undead +25 %, Holy −20 % |
| Infektionsherd | 2.200 | 34 | 9 | 40 % Blut, 60 % Undead | 30 | 72 | Blut +15 %, Undead +25 %, Holy −15 % |

Der kleine Herd ist ein **mobiles** Nebenziel. Beim Befund `Verdeckte Nester`
erscheint er mit 180 Leben in 390 beziehungsweise 475 Pixel Abstand, bewegt
sich mit seinem fallskalierten Tempo auf Doctor Milos zu und setzt nach 20
Sekunden vier Bakterien an seiner aktuellen Position frei, falls er lebt.

Der Boss löst bei 70 und 40 Prozent Leben je einen fallabhängigen
Bakterienschub aus. Gegnerschaden wird mit dem Fallfaktor multipliziert und
anschließend gegen Resistenzen, Verteidigung und Schild von Doctor Milos
aufgelöst. Nach einem gültigen Treffer schützt die globale 0,68-Sekunden-Frist
vor einem sofortigen weiteren Gegnertreffer.

## 13. Fälle und Fortschrittskurven

### Hauptfälle

Alle Kurven laufen über die ersten 180 Sekunden bis zum Bossspawn und bleiben
danach auf ihrem Endwert. Es gibt keine Ablaufzeit.

| Wert | Fall 1 | Fall 2 | Fall 3 |
|---|---:|---:|---:|
| Titel | lol - name fehlt | Die Ausbreitung | Schwerer Verlauf |
| Startleben | 100 | 100 | 100 |
| Boss erscheint | 180 s | 180 s | 180 s |
| Normales Spawnintervall | 0,62 → 0,14 s | 0,52 → 0,11 s | 0,44 → 0,09 s |
| Gegnerleben-Faktor | 1,15 → 1,70 | 1,35 → 2,05 | 1,55 → 2,40 |
| Gegnertempo-Faktor | 1,08 | 1,16 | 1,24 |
| Gegnerschaden-Faktor | 1,25 | 1,45 | 1,65 |
| Gruppenwahrscheinlichkeit | 10 → 28 % | 18 → 38 % | 25 → 48 % |
| Bossleben-Faktor | 0,75 | 1,05 | 1,35 |
| Effektives Bossleben | 1.650 | 2.310 | 2.970 |
| Minions bei 70 / 40 % | 3 / 4 | 4 / 6 | 6 / 8 |
| Forschungsbelohnung-Faktor | 1,00 | 1,35 | 1,70 |
| Befundziel | 30 | 42 | 55 |

Das Intro ist ereignisgesteuert, beginnt ebenfalls mit 100 Leben und besitzt
weder Zeitlimit noch zufällige Fallparameter. Sein Boss folgt nach der dritten
Lektion statt nach 180 Sekunden.

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
| Hohe Keimlast | Spawnintervall ×0,85; Gegnerleben ×0,90 |
| Bewegliche Erreger | Gegnertempo ×1,18; Gegnerschaden ×0,90 |
| Widerstandsfähige Erreger | Gegnerleben ×1,25; Gegnertempo ×0,90 |
| Empfindlich | Gegnerschaden ×1,15; Regeneration ×1,20 |

### Befunde und Reaktionen

| Befund | Grundwirkung | Reaktion 1 | Reaktion 2 | Reaktion 3 |
|---|---|---|---|---|
| Gruppenbildung | +18 Prozentpunkte Bakteriengruppen | +20 % Schaden gegen Gruppen | Gruppen-Kontrolle ×1,30 | −25 % Gruppenschaden |
| Beschleunigte Ausbreitung | +15 % Ausbreitung ab Runmitte | Behandlungsintervall ×0,88 | aktive Cooldowns ×0,90 | +25 % Schaden auf markierte Ziele |
| Belastungsschübe | alle 25 s für 4 s: +30 % Gegnerschaden | +12 Schild | Regeneration ×1,30 | −25 % Schaden während Schüben |
| Verdeckte Nester | +2 kleine Herde | +25 % Schaden gegen Herde | Reichweite ×1,20 und +1 Treffer | Herde geben +4 Proben und reduzieren beide aktiven Restzeiten um 1 s |

## 14. Level und Proben

- Ein Run beginnt auf Level 0 mit einem Ziel von 5 Proben.
- Nach einem Levelaufstieg lautet das nächste Ziel
  `round(6 + Level^1,35 × 3,2)`.
- Die ersten Ziele sind dadurch 5, 9, 14, 20, 27 und 34 Proben.
- Bakterium, Gruppe, kleiner Herd und Boss geben unskaliert 1, 4, 8 und 30
  Proben. Forschung multipliziert den Gewinn und führt Bruchteile über mehrere
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
- Fokusfeld, Notfallhilfe, Schildfeld und Probenzug besitzen Werte und Handler,
  sind aber nicht Teil der aktuellen auswählbaren Balance.
- Passivmodule und die früheren drei Talentäste sind ausdrücklich kein
  ruhender Balancekatalog, sondern entfernt. Eine spätere Rückkehr wäre ein
  neues Design und keine bloße Freischaltung alter Werte.
