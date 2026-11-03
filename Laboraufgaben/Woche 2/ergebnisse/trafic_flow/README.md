# Gespeicherte trafic_flow-Tests

Die [gemeinsame PDF mit fünf Heatmaps](vergleich_20261102_b7d516/Verkehrsstrom_Gesamtvergleich.pdf)
enthält die Wiederholungen bei beta = 0,20 beziehungsweise p = 0,3, die neue
Haltezuschlag-Heatmap und die beiden bisherigen Vergleichsreihen. Alle 216 neuen
und 168 bisherigen Diagrammpunkte sind aus den gespeicherten Positionen geprüft.
Parameter, Quelldateien und Wiederaufnahme stehen in
[`STATUS.md`](vergleich_20261102_b7d516/STATUS.md).

Die [neuen p- und beta-Heatmaps bei 80 km/h](heatmaps_20261102_aaeb14/Verkehrsstrom_p_und_beta.pdf)
sind mit Parametern und vollständigen Durchsatzwerten dokumentiert. Die beiden
Unterordner `zugzahl_p/` und `zugzahl_beta/` enthalten CSV, MAT-Rohdaten sowie
die jeweiligen Grafiken als PNG und FIG.

Die erweiterten [Versuchsreihen vom 01.11.2026 als PDF](studie_20261101_150306/Verkehrsfluss_Untersuchungen.pdf)
enthalten Zugzahl-, Haltezeit- und Störungsreihen für beide Fahrweisen sowie
die Heatmap mit langsamem Abbremsen. Parameter, Zahlenwerte und blockierter
Stillstand je Zugumlauf sind dokumentiert; eine Ergebnisinterpretation ist
nicht enthalten. Alle 166 Konfigurationen sind berechnet und geprüft.

Der vollständige [Testbericht vom 29.10.2026](test_20261029_143513/TESTBERICHT.md)
enthält beide Betriebsarten, Parameter und Prüfergebnisse.

- 78 Modelltests bestanden.
- Einzellauf: 12 Züge, 79,2 km/h effektiv, vier Grafiken.
- Verkehrsstrom: 8 / 12 / 16 Züge × 36 / 57,6 / 79,2 km/h, eine Heatmap.
- Beide Fälle: 60 min Einschwingen, 180 min Messung, p=0,1, Zufallszusatz 0…30 s,
  Antizipation mit beta=0,25 1/s und fester GTFS-Zuschlag +6 s.
- Alle Grafiken liegen als PNG und FIG vor; Rohdaten und Eingaben als MAT/CSV/JSON.

[Einzellaufgrafiken](test_20261029_143513/einzellauf/grafiken/) ·
[Heatmap](test_20261029_143513/verkehrsstrom/grafiken/01_Verkehrsstromuntersuchung.png)

`LETZTER_TEST.txt` verweist nach weiteren Testaufrufen auf den jeweils neuesten
erfolgreichen Lauf. Neue Aufrufe überschreiben keine gespeicherten Testfälle.
