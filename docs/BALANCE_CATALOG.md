# ALVEOLUS – aktueller Werte- und Ausbaukatalog

**Stand:** 18. August 2026  
**Geprüfte Codebasis:** Architektur-Arbeitsbaum auf Basis von `eb82d72`
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
- Abwehrstoß und Behandlungslinie sind auswählbar. Vier weitere aktive
  Fähigkeiten bleiben mit ihren Werten sichtbar, aber gesperrt.
- Es gibt derzeit **keine Passivmodule** im aktiven Produktkatalog.
- Dauerhafte Progression besteht aus acht globalen Forschungen und vier
  Rangtalenten in einem Behandlungsbaum.
- Ein Run enthält 18 verschiedene Ausbauten mit insgesamt 46 möglichen Rängen.
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
| Bewegungstempo | 338 |
| Körpergröße | Mittel (separate Größenklasse) |
| Probenradius | Stufe 6 |
| Verteidigung | 0 |
| Regeneration | 0 Leben/s |
| Schild | 0 |
| Erfahrungsmultiplikator | 1,00 |
| Globale Schutzzeit nach einem Gegnertreffer | 0,68 s |

Forschung erhöht diese Basis auf höchstens 109 Leben, 6 Verteidigungsrating
(effektiv 5,6 % Minderung), 0,75 Leben/s Regeneration, 1,15-fache Erfahrung
und 368,42 Bewegung. Die Behandlung erhält zusätzlich bis zu 6 Prozent Schaden.

### Resistenzen

Positive Werte reduzieren Schaden dieses Typs. Negative Werte sind
Verwundbarkeiten.

| Typ | Rating | Effektiv |
|---|---:|---:|
| Feuer | 0 | 0 % |
| Wasser | +10 | +8,8 % Minderung |
| Erde | +5 | +4,7 % Minderung |
| Wind | −10 | −10 % Verwundbarkeit |

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
| 3 | Erde | Abwehrstoß, Teile der Bakteriengruppe |
| 4 | Wind | Durchdringender Impuls |

`blood`, `holy` und `undead` sind pensionierte Legacy-Authoring-IDs. Sie sind
nicht aktiv und werden nicht neu verwendet.

Gemischte Profile werden vor der Trefferberechnung auf zusammen 100 Prozent
normalisiert.

## 4. Einsatzplanung

| Platz | Anzahl | Aktueller Inhalt |
|---|---:|---|
| Behandlung | genau 1 | Impuls, Streuung oder Durchdringung |
| Aktive Fähigkeit | 0 bis 2 | Abwehrstoß und/oder Behandlungslinie |
| Passivmodul | 0 | nicht Teil des aktuellen Spiels |
| Reserve | 0 | nur altes Schemafeld |

Technisch existiert noch eine Kapazität von 8. Jede aktuelle Behandlung und
aktive Fähigkeit kostet 2; ein vollständiger produktiver Plan benötigt daher
6. Da keine Passivmodule verfügbar sind, ist die verbleibende Kapazität zurzeit
kein spielerischer Entscheidungswert.

Der Standardplan ist Impuls, Abwehrstoß und Behandlungslinie. Alte
Save-Felder für Passive und Reserve werden bei einem effektiven Plan bereinigt,
ohne stabile IDs aus älteren Spielständen umzubenennen.

## 5. Behandlungen

| Behandlung | Verfügbarkeit | Typ | Schaden | Intervall | Reichweite | Projektile | Treffer je Projektil |
|---|---|---|---:|---:|---:|---:|---:|
| Impuls | sofort | Wasser | 16 | 0,82 s | Stufe 16 | 1 | 1 |
| Streuimpuls | Forschung für 60 | Feuer | 7 je Strahl | 1,00 s | Stufe 15 | 3 | 1 |
| Durchdringender Impuls | Forschung für 100 | Wind | 14 je Treffer | 1,65 s | Stufe 17 | 1 | 4 |

Besonderheiten:

- **Impuls** verfolgt ohne Talent automatisch das nächste gültige
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
| Abwehrstoß | auswählbar | Zielkreis | 14 s | 38 Schaden, Radiusstufe 5, 75 Rückstoß | Erde |
| Behandlungslinie | auswählbar | Zielrichtung | 18 s | 50 Schaden, Reichweitenstufe 21, 38 Breite | Wasser |
| Fokusfeld | sichtbar gesperrt | Zielkreis | 16 s | Radiusstufe 6, 7 s, Behandlungsschaden ×1,25 | keiner |
| Notfallhilfe | sichtbar gesperrt | selbst | 28 s | +14 Leben, +8 Schild | keiner |
| Schildfeld | sichtbar gesperrt | Zielkreis | 20 s | Radiusstufe 6, 6 s, Gegnertempo und -schaden ×0,65 | keiner |
| Probenzug | sichtbar gesperrt | Zielkreis | 18 s | Radiusstufe 8, +6 Befundfortschritt | keiner |

Nur Ausbauten für tatsächlich ausgerüstete aktive Fähigkeiten gelangen in den
Run-Pool. Für die vier gesperrten Fähigkeiten existieren derzeit keine
zugehörigen Run-Ausbaustufen.

## 7. Passivmodule

**Aktive Anzahl: 0.** Passivmodule erscheinen weder als wählbare noch als
ausgegraute Produktkarten. Alte Felder und einzelne Kompatibilitätsmethoden im
Code sind kein aktiver Balanceinhalt und dürfen nicht als versteckte Boni
interpretiert werden.

## 8. Forschung

Alle acht Forschungen wirken global und benötigen kein ausgerüstetes Modul.

| Forschung | Ränge | Kosten je Rang | Wirkung je Rang | Maximum |
|---|---:|---|---|---|
| Mehr Leben | 3 | 20 / 45 / 80 | +3 maximales Leben | +9 Leben |
| Stärkere Behandlung | 3 | 25 / 55 / 95 | +2 % Behandlungsschaden | +6 % |
| Mehr Erfahrung | 3 | 25 / 55 / 95 | +5 % Erfahrung aus Proben | +15 % |
| Mehr Verteidigung | 3 | 30 / 60 / 100 | +2 Verteidigung | +6 |
| Lebensregeneration | 3 | 30 / 60 / 100 | +0,25 Leben/s | +0,75 Leben/s |
| Bewegungstraining | 3 | 30 / 60 / 100 | +3 % Bewegung | +9 % |
| Streuimpuls | 1 | 60 | Behandlung freischalten | freigeschaltet |
| Durchdringender Impuls | 1 | 100 | Behandlung freischalten | freigeschaltet |

Der reguläre Vollausbau kostet insgesamt **1.225 Forschungspunkte**. Im lokalen
Testmodus stehen 1.000.000.000 Punkte zur Verfügung; Forschung lässt sich dort
vollständig zurücksetzen. Die Einführung verwendet ihre feste Lehrkonfiguration
und übernimmt diese Metawerte nicht.

## 9. Behandlungs-Talentbaum

| Talent | Max. Rang | Kosten | Voraussetzung | Wirkung |
|---|---:|---:|---|---|
| Behandlungsgrundlage | 1 | 1 | keine | +10 % Schaden aller drei Grundbehandlungen. |
| Durchdringende Streuung | 3 | 1 je Rang | Behandlungsgrundlage | +1 möglicher Gegner je Streuimpuls-Strahl und Rang. |
| Manuelle Zielsteuerung | 1 | 1 | Behandlungsgrundlage | Alle Behandlungen schießen zur Maus. |
| Anhaltender Laser | 2 | 1 je Rang | Behandlungsgrundlage | +0,5 s Strahldauer je Rang; Tick alle 0,25 s. |

Der vollständige Baum kostet **7 Talentpunkte**. Bei 0,5 Sekunden Dauer trifft
eine Phase zu 0,00 und 0,25 Sekunden; bei 1,0 Sekunde zu 0,00, 0,25, 0,50 und
0,75 Sekunden. `piercing_return` bleibt entfernt und reserviert. Savegame-
Version 6 und Talentbaum-Revision 4 setzen Revision-3-Belegungen atomar zurück
und bewahren Meisterschaft sowie Forschung.

Im lokalen Testmodus stehen 1.000.000.000 Talentpunkte zur Verfügung und der
Baum kann zurückgesetzt werden.

## 10. Run-Ausbaustufen

### Allgemeine Behandlung

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Stärkerer Impuls | 3 | +7 Schaden | +21 Schaden | beliebige Behandlung |
| Schnellere Impulse | 3 | Intervall ×0,84 | Intervall ×0,5927 | beliebige Behandlung |
| Mehr Reichweite | 2 | +3 Stufen | +6 Stufen | beliebige Behandlung |
| Zusätzliches Ziel | 2 | +1 Ziel | +2 Ziele | Impuls |

### Abwehrzellen

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Abwehrzellen | 1 | System aktivieren | 2 Zellen | keine |
| Stärkere Abwehrzellen | 3 | +6 Schaden | 27 Schaden | Abwehrzellen |
| Größere Abwehrzellen | 3 | +1 Radiusstufe | Stufe 4 | Abwehrzellen |
| Mehr Abwehrzellen | 2 | +1 Zelle | 4 Zellen | Abwehrzellen |

### Behandlungsspezifisch

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Ruhiger Fokus | 3 | Schaden ×1,18 | Schaden ×1,6430 | Impuls |
| Dichter Streuimpuls | 3 | +1 Projektil | 6 Projektile | Streuimpuls |
| Kräftigere Streuung | 3 | +3 Schaden | 16 Schaden je Projektil | Streuimpuls |
| Tieferer Impuls | 2 | +2 maximale Treffer | 8 Treffer | Durchdringender Impuls |
| Stärkere Linie | 3 | +5 Schaden | 29 Schaden je Treffer | Durchdringender Impuls |

### Aktive Fähigkeiten

| Ausbau | Max. Rang | Pro Rang | Voll ausgebaut | Voraussetzung |
|---|---:|---|---|---|
| Kräftiger Abwehrstoß | 3 | +12 Schaden | 74 Schaden | Abwehrstoß ausgerüstet |
| Breiter Abwehrstoß | 2 | +1 Radiusstufe | Radiusstufe 7 | Abwehrstoß ausgerüstet |
| Stärkere Behandlungslinie | 3 | +16 Schaden | 98 Schaden | Behandlungslinie ausgerüstet |
| Breitere Behandlungslinie | 2 | +16 Breite | 70 Breite | Behandlungslinie ausgerüstet |
| Beweglichkeit | 3 | Bewegung ×1,05 | Bewegung ×1,1576 | Bewegung |

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
| Schaden je Treffer | 9 Wasser | 27 Wasser |
| Trefferradius je Zelle | Stufe 1 | Stufe 4 |
| Orbit-Radius um Doctor Milos | interne feste Geometrie | unverändert |
| Orbit-Geschwindigkeit | 1,7 rad/s | 1,7 rad/s |
| Kürzestes Trefferintervall | 0,1 s je Zelle | 0,1 s je Zelle |
| Ziele je Zelle und Tick | höchstens 1 | höchstens 1 |

Schaden entsteht ausschließlich, wenn der tatsächliche Kreis einer einzelnen
Zelle einen Gegner geometrisch berührt. Ein gemeinsamer unsichtbarer
Avatar-Radius verursacht keinen Schaden. Jede Zelle besitzt ihren eigenen
Cooldown und verwendet einen generationssicheren Gegnerhandle.

## 12. Gegner

### Unskalierte Grundwerte

| Gegner | Leben | Tempo | Schaden | Schadenstyp | Proben | Größenklasse | Resistenzen (Rating; positiv effektiv) |
|---|---:|---:|---:|---|---:|---:|---|
| Bakterium | 22 | 66 | 2,2 | 100 % Feuer | 1 | Klein | Wasser +10 (+8,8 %), Erde −10 |
| Bakteriengruppe | 74 | 50 | 5 | 60 % Erde, 40 % Feuer | 4 | Mittel | Erde +20 (+15,8 %), Feuer −15 |
| Kleiner Herd | 180 | 24 | 0 | 100 % Wind | 8 | Groß | Wind +25 (+18,8 %), Wasser −20 |
| Infektionsherd | 2.200 | 34 | 9 | 40 % Feuer, 60 % Wind | 30 | Boss | Feuer +15 (+12,5 %), Wind +25 (+18,8 %), Wasser −15 |

Der kleine Herd ist ein **mobiles** Nebenziel. Beim Befund `Verdeckte Nester`
erscheint er mit 180 Leben auf einem der katalogisierten Spawnringe, bewegt
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
weder Zeitlimit noch zufällige Fallparameter. Der erste Erreger bleibt nach
seiner Materialisierung drei Sekunden ohne Autoangriff beobachtbar. Danach
bestätigt ein Linksklick den Angriff. Genau drei normale Ein-Punkt-Proben lösen
eine Auswahl aus drei gültigen Ausbauten für `treatment_precision` aus; nach der
Auswahl wartet der Boss erneut in einer Linksklick-Pause.

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
