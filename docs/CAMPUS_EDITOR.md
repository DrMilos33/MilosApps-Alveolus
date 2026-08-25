# Campus im Godot-Editor bearbeiten

Der Campus ist nicht mehr ausschließlich in GDScript zusammengesetzt. Seine
sichtbare Struktur liegt in der normalen Godot-Szene
`res://scenes/ui/campus_layout.tscn` und kann im 2D-Editor angeklickt,
verschoben, dupliziert und gespeichert werden.

## Szene öffnen

1. Godot 4.7.1 Standard öffnen und `project.godot` importieren, falls das
   Projekt noch nicht in der Projektliste steht.
2. Links im **FileSystem** zu `scenes/ui/campus_layout.tscn` navigieren.
3. Die Datei doppelklicken und oben den Arbeitsbereich **2D** wählen.
4. Mit **F** auf einen ausgewählten Knoten fokussieren. Mit **W** wird das
   Verschieben-Werkzeug aktiviert.
5. **F6** startet ausschließlich diese Szene als visuelle Vorschau. Die
   komplette klickbare Campusnavigation wird wie bisher mit **F6/F5** über
   `scenes/main.tscn` getestet.

## Was wo bearbeitet wird

- `GroundTiles`: Jede Gras- oder Wegplatte ist ein eigenes `Sprite2D`.
  Anklicken und verschieben oder mit `Ctrl+D` duplizieren. Im Inspector kann
  unter **Texture** ein anderes importiertes Kenney-Tile abgelegt werden.
- `Decorations`: Bäume, Garten, Brunnen, Steine und Zaun sind eigenständige
  `Sprite2D`-Knoten. Ihre Position und Skalierung sind direkt bearbeitbar.
- `BuildingSlots`: Jeder Knoten zeigt im Editor das komplette Gebäude. Immer
  den ganzen Slot verschieben, nicht nur eine einzelne Dach- oder Wandebene.
  Das goldene Kreuz markiert den unteren Mittelpunkt. Genau dieser Punkt wird
  automatisch als Position für Grafik, Hoverkontur und Klickfläche verwendet.
- `Sky`, `Horizon` und `HeaderVeil`: Farben und Höhe des Hintergrunds sowie
  der obere Lesbarkeitsbereich.

## Neue Dekoration einsetzen

1. Das gewünschte PNG aus einem dokumentierten Assetpaket nach
   `assets/vendor/...` übernehmen und die Quelle in `THIRD_PARTY_ASSETS.md`
   ergänzen.
2. Das PNG aus dem Godot-FileSystem in `Decorations` ziehen. Godot erzeugt
   daraus automatisch ein `Sprite2D`.
3. Für den bisherigen isometrischen Maßstab zunächst `0.448` bis `0.474`
   verwenden und anschließend visuell feinjustieren.
4. Auf die Reihenfolge im Szenenbaum achten: weiter hinten beziehungsweise
   weiter unten liegende Objekte müssen meist später im Baum stehen, damit sie
   vorne gezeichnet werden.

## Gebäude verschieben

1. Unter `BuildingSlots` beispielsweise `practice` auswählen.
2. Den Knoten mit dem Verschieben-Werkzeug an die neue Position ziehen.
3. Szene mit `Ctrl+S` speichern.
4. Das Spiel starten. `CampusScene.building_anchor()` liest die Position direkt
   aus dieser Szene; es gibt dafür keine zweite, manuell zu pflegende
   Koordinatenliste mehr.

Die Skripte `campus_layout.gd` und `campus_building_slot.gd` kümmern sich nur
um Eingabeverhalten und Editorvorschauen. Die eigentliche Komposition bleibt
in der `.tscn`-Datei sichtbar und bearbeitbar. Bewegte Doctor-Figuren gehören
nicht mehr zur Campuskomposition.
