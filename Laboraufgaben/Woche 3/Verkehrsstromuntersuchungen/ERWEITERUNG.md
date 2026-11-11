# Woche 3: Erweiterung um vier Zugzahlen und zusätzliche Stationshalte

Die Dokumentation wird mit `run_woche3_erweiterung.m` und
`bericht_woche3_erweiterung.py` berechnet. Der Bericht heißt
`Woche3_Beta_und_Haltezeiten.pdf` und umfasst sieben Seiten:
Parameter, zwei Kurvenscharen, zwei Weg-Zeit-Diagramme und zwei Wertetabellen.
Es ist keine Ergebnisinterpretation enthalten.

## Messreihen

| Untersuchung | x-Werte | Kurven | Weitere Festlegung |
| --- | --- | --- | --- |
| Durchsatz über beta | 0:0,05:0,50 1/s (11 Punkte) | N = 20, 28, 36, 44 | Fester Stationszuschlag 0 s |
| Durchsatz über Stationszuschlag | 0, 6, 12, 18, 24, 30, 36, 42, 45 s (9 Punkte) | N = 20, 28, 36, 44 | beta = 0,20 1/s |

Die neun Haltezeitstützstellen sind ganzzahlig im 1-s-Raster und enthalten
die Grenzen 0 und 45 s sowie den gewünschten Punkt 18 s. Die ersten sieben
Schritte betragen 6 s, der letzte 3 s. Die x-Koordinaten im Liniendiagramm
entsprechen den tatsächlichen Sekundenwerten.

Die Farbzuordnung bleibt zwischen beiden Diagrammen gleich: N = 20 orange,
N = 28 blau, N = 36 grün und N = 44 violett. Zusätzlich unterscheiden sich
die Punktsymbole. Die beiden Kurvenscharen verwenden dieselbe Durchsatzachse.

Beide Weg-Zeit-Diagramme zeigen alle 28 Züge bei beta = 0,20: einmal mit
0 s und einmal mit 18 s festem Stationszuschlag. Verwendet werden die
vollständigen Trajektorien der zugehörigen Durchsatzmessung im Messfenster
von Minute 60 bis 240. Der Ringschluss unterbricht die Linien.

## Gemeinsame Parameter und Messdefinition

- p = 0,2 für die beiden unabhängigen Zufallsstörungsarten.
- 80 km/h Vorgabe, 79,2 km/h effektiv; Zuglänge 148 m; Raster 1 m / 1 s.
- Reale S41, GTFS-Stationshalte, 117 unterschiedlich lange OSM-Signalabschnitte.
- Antizipation am **Zugende** des räumlich nächsten Vorgängers, höchstens
  im ersten oder zweiten Block vor dem Block der eigenen Zugspitze.
- Die zusätzliche Bremsregel greift nur bei langsamerem Vorgänger:
  `a = max(-1, beta * (v_Vorgänger - v_Zug))`, beta in 1/s.
- beta = 0 hat keine zusätzliche Bremswirkung und verhindert die normale
  Beschleunigung nicht. Bruchteile positiver beta-Werte werden integriert;
  außerhalb des Bereichs wird der Bruchteil zurückgesetzt.
- Feste zusätzliche Haltezeiten werden auf **jeden** GTFS-Stationshalt addiert.
  Bei einer zufälligen Stationsstörung kommen weiterhin unabhängig 0 bis 120
  ganze Sekunden aus einer diskreten Gleichverteilung hinzu.
- 60 min Einschwingen und 180 min Messung, Zufallsstartwert 42.
- Durchsatz: Summe der Abfahrten aller Züge an Station 1 im halboffenen
  Messfenster `[3600,14400)` s, geteilt durch drei Stunden.
- Ein Lauf je Konfiguration, keine Variation des Zufallsstartwerts.

Es entstehen 44 beta-Punkte und 36 Haltezeitpunkte. Die vier Fälle mit
beta = 0,20 und Zuschlag = 0 s sind in beiden Reihen physikalisch identisch
und verwenden jeweils dieselbe Rohdatei. Daher benötigen 80 Diagrammpunkte
76 verschiedene Simulationsläufe.

## Einheitliche neue Initialisierung

Die bisherige Suche nach einer gemeinsamen Verschiebung freier Zeitphasen
findet für N = 44 bereits bei Zuschlag 0 s keine sichere Blockbelegung.
Die Originalfehlermeldung steht in `vorpruefung_freie_phasen_20261110.log`.
Dies ist eine Grenze der bisherigen Startaufstellung, keine zusätzliche
Begrenzung der angeforderten Zugzahl in den neuen Messungen.

Für die Erweiterung wird deshalb bei **allen** vier Zugzahlen eine ruhende
Blockaufstellung verwendet. Mit B = 117 Blöcken werden die Blocknummern
`1 + floor((0:N-1)*B/N)` ausgewählt und die Zugspitzen jeweils auf die letzte
Zelle ihres Blocks gesetzt. Alle Anfangsgeschwindigkeiten sind null.
Mindestens zwei Blocknummern Abstand sowie die vollständige Prüfung der
Zugkörper stellen eine exklusive Blockbelegung sicher. Ein Zug, der genau
an einer Station startet, erhält den geplanten Stationshalt.

Die bisherige N = 28-Kurve wird mit dieser Startmethode ebenfalls neu
berechnet. Sie wird nicht mit alten Rohdaten anderer Anfangsbedingungen
gemischt. Die alten Skripte, die Modellkopie `+sbahn3`, die bisherigen
Rohdaten und die bisherige PDF bleiben erhalten. Die neue Option liegt in
der separaten Modellkopie `modell/+sbahn3x/`; die Bewegungs-, Brems-,
Störungs- und Antizipationsregeln wurden gegenüber `+sbahn3` nicht geändert.

## Ausführen

In MATLAB aus dem Projektordner:

```matlab
ausgabe = run_woche3_erweiterung;
disp(ausgabe)
```

Danach im Terminal:

```powershell
py bericht_woche3_erweiterung.py <Ausgabeordner>
```

Die vorhandene Berechnung kann mit
`run_woche3_erweiterung("ergebnisse/erweiterung_20261110")` fortgesetzt werden.
Vor der Übernahme gespeicherter Läufe werden Modellquellen, vollständige
Konfiguration und Einschwing-/Messfenster geprüft. Vier lokale MATLAB-
Basissitzungen bearbeiten die Fälle; die Parallel Computing Toolbox wird
nicht benötigt.

## Ergebnisse und Prüfungen

`parameter.json` dokumentiert die Eingaben. `beta.csv` enthält 44 Punkte,
`haltezeiten.csv` 36 Punkte, `alle_punkte.csv` die 80 dargestellten Punkte.
`laufindex.csv` und `laeufe/*.mat` enthalten die 76 verschiedenen Läufe mit
vollständigen Trajektorien, Modellkonfigurationen und Prüfberichten.
`shared_point` kennzeichnet die vier gemeinsam verwendeten Schnittpunkte.

`blockpruefung.csv` dokumentiert zehn Grenzfallprüfungen der unveränderten
Antizipationsregel. `initialisierung_pruefung.csv` dokumentiert sechs kurze
Prüfungen der neuen Aufstellung, einschließlich N = 44 mit 45 s Zuschlag.
Jeder vollständige Simulationslauf durchläuft zusätzlich die Modellprüfungen.
Die Berichtserstellung zählt die Abfahrten erneut aus den Zugpositionen und
rekonstruiert für jeden Zug und jeden Zeitschritt das Vorgänger-Zugende,
den Blockabstand und die Bremsbruchteile.

`rohdatenaudit.csv` und `bericht_pruefung.json` dokumentieren diese Prüfung.
`grafiken/` enthält alle sieben Berichtsseiten als PNG und einzelne PDFs.
`quellstand/` sichert die verwendeten Quellen und Eingabedaten-Prüfsummen.
