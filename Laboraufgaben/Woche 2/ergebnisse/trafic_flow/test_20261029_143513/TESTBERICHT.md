# Testbericht: trafic_flow.mlx

Ausgeführt am 29-Oct-2026 14:36:41 (Europe/Berlin) mit MATLAB 26.1.0.3276743 (R2026a) Update 3.

## Automatisierte Prüfungen

78 Modelltests bestanden; 0 fehlgeschlagen. Enthalten sind die bestehenden Regressionen gegenüber Woche 1 sowie die neuen Störungs- und Antizipationstests.

Das native Live Script wurde durch MATLAB nach .m konvertiert. Beide Testfälle führen diesen Code mit Testeingaben aus; die Live-Eingaben werden dabei bis zur Modellkonfiguration geprüft.

## Gemeinsame Testeingaben

60 min Einschwingen + 180 min Messung, p = 0,1 für beide unabhängigen Störungsarten, Stationszusatz U{0,...,30} s, Antizipation aktiviert mit beta = 0,25 1/s, fester GTFS-Zuschlag aktiviert mit +6 s, Zufallsstartwert 42.

Die zeitaufwendige Animation wurde nur für die Batchprüfung deaktiviert; der geografische Endzustand wurde erzeugt und gespeichert. Im Live Script bleibt die Animation eingeschaltet (0,05 s Pause, 10 Schritte Bildabstand).

Grafiken verwenden unabhängig vom MATLAB-Design helle Hintergründe und schwarze Beschriftungen. Die Achsenfarben wurden ebenfalls geprüft.

## Einzellauf

12 Züge, 80 km/h Eingabe / 79.2 km/h effektiv. Durchsatz 5.333 Züge/h aus 16 gezählten Abfahrten.

2535 Blockeinfahrten geprüft, 272 Zufallsbremsungen ausgelöst, 62 positive Stationszusatzhalte, 34020 Antizipations-Bremssekunden. 10 vollständige Ringfahrten für den GTFS-Vergleich.

Vier Grafiken: geografischer Endzustand, Raum-Zeit, Geschwindigkeit/Beschleunigung von Zug 1, mittlere Geschwindigkeit. Jeweils PNG und FIG unter [einzellauf/grafiken](einzellauf/grafiken/).

## Verkehrsstromuntersuchung

Neun Kombinationen: 8 / 12 / 16 Züge und effektiv 36,0 / 57,6 / 79,2 km/h. Genau ein Lauf je Kombination. Die zusätzlich angefragten 80 km/h ergeben dieselbe Rasterstufe wie 79,2 km/h und werden zusammengefasst.

| Züge | 36,0 km/h | 57,6 km/h | 79,2 km/h |
|---:|---:|---:|---:|
| 8 | 3.333 | 4.000 | 4.000 |
| 12 | 4.667 | 5.333 | 5.333 |
| 16 | 7.000 | 7.000 | 7.000 |

Alle Angaben in Zügen/h. Genau eine Grafik, die [Heatmap](verkehrsstrom/grafiken/01_Verkehrsstromuntersuchung.png), wurde erzeugt. Ihre Bildmatrix stimmt mit den gespeicherten Durchsätzen überein.

## Unabhängige Ergebnisprüfung

Für alle zehn Simulationen wurden die Abfahrten an Station 1 aus den Ereignisprotokollen im halboffenen Messfenster [3600,14400) s erneut gezählt. Der Durchsatz stimmt damit überein. GTFS+6, beide p-Werte, beta, Beschleunigungsgrenzen, Ausgabeanzahl sowie PNG-/FIG-Export wurden geprüft. Der Modellkern prüft zudem Körper- und Blockbelegung, Bremsreserven, Stationsreihenfolge und Mindesthaltezeiten.

Dieser kleine Test belegt Funktion und reproduzierbare Auswertung. Er schätzt keine Zufallsunsicherheit und ersetzt keine umfassende Kapazitätsstudie.

Alle fünf gespeicherten FIG-Dateien wurden zusätzlich erneut geöffnet, mit hellen Hintergründen und schwarzen Beschriftungen exportiert und geprüft. Das umfasst die übergeordneten Titel der Diagramme. Die Ergebnisse stehen in `grafikpruefung.csv`. Die numerischen Simulationsergebnisse bleiben dabei identisch.

## Dateien und Wiederholung

- `modelltests.csv` / `.mat`: vollständige Modelltestergebnisse.
- `testfaelle.csv`: beide Oberflächentestfälle mit Laufzeiten.
- `matlab.log`: Testprotokoll.
- `trafic_flow_import.m`: von MATLAB aus dem ausgelieferten Live Script exportierter Code.
- `einzellauf/` und `verkehrsstrom/`: Eingaben, Ereignisse/Rohdaten, Grafiken und jeweilige `LAUF.md`.

Wiederholen im Projektordner: `addpath('tools'); test_trafic_flow`. Erstellt einen neuen Testordner und überschreibt keine früheren Testdaten.

Laufzeiten: Einzellauf 26.6 s, Untersuchung 42.0 s.
