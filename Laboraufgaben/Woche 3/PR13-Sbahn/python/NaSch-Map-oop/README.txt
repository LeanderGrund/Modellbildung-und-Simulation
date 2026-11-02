NaSch-Map-oop – Lernziel

Diese Version erweitert die einzelne Road zu einem Straßennetz. Das Netz besteht aus Road-Objekten, die über elementare Knoten verbunden werden.

Zentrale Dateien:
- +nasch/Road.m: nichtperiodische Straße mit der temporären Fortsetzung temp.
- +nasch/Map.m: erzeugt Straßen und Knoten und koordiniert einen vollständigen Netz-Zeitschritt.
- +nasch/+node/: Source, Sink, Connector, Diverge und Merge.
- +nasch/+editor/: optionaler Karteneditor und Übersetzung eines digraph in Map-Konstruktordaten.
- +nasch/+plot/: Auswertung von Map- und Road-Historien.

Ein Aufruf von map.update() führt genau einen Zeitschritt aus. Die Reihenfolge ist für das gesamte Netz:
1. Knoten vorbereiten: freie Fortsetzungen bestimmen.
2. Alle Straßen genau einmal aktualisieren.
3. Fahrzeuge über die Knoten übertragen.
4. Zustände aller Straßen speichern.

Wichtiger Unterschied zur periodischen Einzelstraße:
Die periodische Randbedingung wird durch temp ersetzt. Die Länge von temp beschreibt die freie Fortsetzung hinter dem Straßenende; nach dem Road-Update kann temp ein Fahrzeug enthalten, das die Straße verlassen hat.

Der Editor ist ein Hilfswerkzeug und nicht Teil des eigentlichen Simulationsalgorithmus. Jeder Editor-Knoten wird derzeit als Roundabout in ein flaches Netz aus elementaren Knoten umgesetzt.
