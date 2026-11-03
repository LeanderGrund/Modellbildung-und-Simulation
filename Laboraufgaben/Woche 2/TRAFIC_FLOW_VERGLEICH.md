# Vergleich der Verkehrsstrom-Heatmaps

`run_trafic_flow_vergleich` berechnet die beiden angeforderten Wiederholungen
und die neue Untersuchung des Haltezeitzuschlags. Die zwei bisherigen Heatmaps
werden aus `ergebnisse/trafic_flow/heatmaps_20261102_aaeb14/` übernommen.
Der Modellkern ist gegenüber diesen Messungen unverändert.

Die [abgeschlossene gemeinsame PDF vom 02.11.2026](ergebnisse/trafic_flow/vergleich_20261102_b7d516/Verkehrsstrom_Gesamtvergleich.pdf)
enthält alle fünf Heatmaps, ihre Parameter und Wertetabellen auf elf Seiten.
Alle 384 dargestellten Diagrammpunkte sind aus den gespeicherten Positionen
nachgeprüft. Rohdaten, Grafiken und Prüfprotokolle liegen im selben Ergebnisordner.

| Reihe | x-Achse | y-Achse | Feste Parameter | Punkte |
| --- | --- | --- | --- | ---: |
| Bisherige p-Untersuchung | p = 0:0,1:1 | N = 12:4:40 | Langsames Abbremsen aus; beta ohne Wirkung | 88 |
| Wiederholung p | p = 0:0,1:1 | N = 12:4:40 | Langsames Abbremsen an; beta = 0,20 1/s | 88 |
| Bisherige beta-Untersuchung | beta = 0,05:0,05:0,50 1/s | N = 12:4:40 | Langsames Abbremsen an; p = 0 | 80 |
| Wiederholung beta | beta = 0,05:0,05:0,50 1/s | N = 12:4:40 | Langsames Abbremsen an; p = 0,3 | 80 |
| Haltezeitzuschlag | 0:6:30 s je Station | N = 12:4:40 | Langsames Abbremsen an; p = 0,3; beta = 0,20 1/s | 48 |

Alle Reihen verwenden 80 km/h als Eingabe (79,2 km/h im Raster), eine Stunde
Einschwingen und drei Stunden Messung, Zufallsstartwert 42, OSM-Signalabschnitte
und das GTFS-Halteprofil der S41. Beide unabhängigen Störungsarten verwenden
dasselbe p. Ein zufälliger Stationszusatz ist gleichverteilt zwischen 0 und
120 ganzen Sekunden. Der feste Stationszuschlag beträgt in den ersten vier
Reihen null. Die fünfte Reihe addiert ihren x-Wert auf **jeden** GTFS-Halt;
die zufälligen Zusatzhalte kommen unabhängig hinzu.

Die 216 neuen Diagrammpunkte entsprechen 200 unabhängig berechneten
Konfigurationen: Für jede der acht Zugzahlen ist der Punkt p = 0,3,
beta = 0,20 1/s, fester Zuschlag = 0 s in allen drei neuen Heatmaps identisch.
Die beiden weiteren Verwendungen behalten ihre ursprünglichen Rohdaten und
eine `reuse_source`-Herkunftsangabe. Identische Modellkonfiguration und
identisches Messfenster werden vor einer Übernahme geprüft. Es gibt genau
einen Lauf pro Konfiguration, keine Wiederholung über verschiedene Startwerte.

## Ausführen und PDF erstellen

In MATLAB aus dem Projektordner:

```matlab
ausgabe = run_trafic_flow_vergleich;
disp(ausgabe)
```

Danach in PowerShell mit dem ausgegebenen Ordner:

```powershell
py tools/bericht_trafic_flow_vergleich.py <Ausgabeordner>
```

Eine unterbrochene Berechnung kann mit
`run_trafic_flow_vergleich("<vorhandener Ausgabeordner>")` fortgesetzt werden.
Vier lokale MATLAB-Basissitzungen bearbeiten die Punkte; die Parallel Computing
Toolbox wird nicht benötigt. Vor den Hauptläufen werden sechs kurze Punkte
der neuen Halteachse aus dem von MATLAB importierten Live-Script-Code sowie
die Wiederverwendung über verschiedene Achsen und
die Ablehnung abweichender Konfigurationen geprüft.

Die vollständige PDF enthält eine Parameterseite, fünf Heatmaps mit gemeinsamer
Farbskala und fünf Wertetabellen. Sie enthält keine Ergebnisinterpretation.
Der Bericht zählt die Abfahrten aus den gespeicherten Positionen im Messfenster
`[3600,14400)` s erneut nach. CSV und MATLAB-Matrix müssen übereinstimmen;
gemeinsame Schnittpunkte werden verglichen. Unzulässige Startbelegungen werden
als fehlende Werte mit Fehlergrund dokumentiert.

`--plan-only` erzeugt stattdessen eine ausdrücklich als vorläufig gekennzeichnete
PDF mit dem Messplan und ausschließlich den zwei bereits vorhandenen Heatmaps.
Sie enthält keine neuen Messwerte. Der aktuelle Ausführungsstand steht im
jeweiligen Ergebnisordner.
