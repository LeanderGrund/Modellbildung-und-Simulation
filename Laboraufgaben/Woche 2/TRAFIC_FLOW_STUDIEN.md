# Verkehrsfluss-Versuchsreihen

Die [PDF vom 01.11.2026](ergebnisse/trafic_flow/studie_20261101_150306/Verkehrsfluss_Untersuchungen.pdf)
enthält die ausgeführten Untersuchungen mit Parametern und Wertetabellen.
Alle 166 Konfigurationen wurden erfolgreich berechnet und unabhängig anhand
der gespeicherten Rohdaten geprüft.

Die Versuche werden mit dem vorhandenen `sbahn2`-Modellkern berechnet. Das
Live Script und der Bewegungsalgorithmus werden dadurch nicht geändert.

```matlab
ausgabeordner = run_trafic_flow_studien;
```

Danach in PowerShell mit dem ausgegebenen Ordner:

```powershell
py tools/bericht_trafic_flow_studien.py ergebnisse/trafic_flow/studie_...
```

Der zweite Schritt prüft die gespeicherten Rohdaten unabhängig und erzeugt
`Verkehrsfluss_Untersuchungen.pdf`. Die PDF enthält Parameter, Diagramme und
Wertetabellen ohne Ergebnisinterpretation. Alle Berichtsseiten werden zusätzlich
als PNG und einzelne PDF-Dateien gespeichert.

## Versuchsplan

Gemeinsam: reale S41, geografischer Verlauf, dynamisches Fahrmodell,
OSM-Signalabschnitte, GTFS-Stationshalte, 1 m und 1 s Raster, 148 m Zuglänge,
80 km/h Eingabe / 79,2 km/h effektive Höchstgeschwindigkeit außerhalb der Heatmap,
beta = 0,25 1/s, Zufallsstartwert 42, 60 min Einschwingen und 180 min Messung.
Die Animation ist für die Berechnung ausgeschaltet.

Für ausgeschaltetes und eingeschaltetes langsames Abbremsen wird jeweils gerechnet:

| Reihe | Werte | Feste Werte |
| --- | --- | --- |
| Grenzsuche | jede ganze Zugzahl 1 bis 40 | p=0, Haltezuschlag 0 s |
| Zugzahl | 12, 16, 20, 24, 28, 32, 36, 40 | p=0, Haltezuschlag 0 s |
| Haltezuschlag | 0, 6, 12, 18, 24, 30 s je Station | N=jeweiliger Grenzpunkt, p=0 |
| Störungswahrscheinlichkeit | 0, 0,1, …, 1 | N=max(1, round(0,6·Grenzzugzahl)), Haltezuschlag 0 s, Zufallszusatz 0…120 s |

Die Heatmap verwendet eingeschaltetes langsames Abbremsen, N=12:4:40,
effektiv 36:7,2:79,2 km/h, p=0 und Haltezuschlag 0 s: 56 Kombinationen.
80 km/h und 79,2 km/h ergeben dieselbe Rasterstufe und nur einen Heatmap-Punkt.

Es gilt ein Lauf je Konfiguration. Gleiche Eingabekonfigurationen werden
zwischen den Reihen wiederverwendet. Falls der Grenzpunkt bei 40 liegt, wird
oberhalb von 40 bis zum ersten nicht mehr passenden oder ungültigen Punkt gesucht.

## Kennzahlen

- Durchsatz: Abfahrten an Station 1 im halboffenen Messfenster [3600,14400) s,
  geteilt durch drei Stunden. Die Zählung aus Positionen wird gegen das
  Abfahrtsprotokoll geprüft.
- Grenzzugzahl: größte gültige geprüfte Zugzahl, deren Abfahrtszählung gegenüber
  `3 h · 3600 · N / freier_Umlaufzeit_s` um höchstens eine Abfahrt zurückbleibt.
- Blockierter Stillstand: die vom Modell als blockiert markierten Sekunden
  ohne Bewegung und ohne laufende Stationshalteuhr. Stationshalte, zufällige
  Stationszusätze und langsames Folgen bei noch freiem Fahrweg sind ausgeschlossen.
- Blockierter Stillstand je Zug und Umlauf: Mittel über vollständige Zugumläufe
  zwischen zwei aufeinanderfolgenden Ankünften an Station 1, deren Anfang und
  Ende im Messfenster liegen. Ohne vollständigen Umlauf ist der Wert NaN.

`tools/test_study_metrics.m` prüft die Intervallgrenzen anhand bekannter
Ereignisse. Jede Simulation führt zusätzlich die Sicherheitsprüfungen des
Modellkerns aus. Der Python-Schritt zählt Durchsatz und blockierte Umlaufsekunden
aus den MAT-Dateien erneut und gleicht Diagrammkoordinaten mit den MATLAB-Werten ab.

## Gespeicherte Dateien

- `versuchsplan.json`, `basiskonfiguration.json`: Eingaben und feste Einstellungen.
- `grenzzugzahlen.csv`, `grenzsuche.csv`: Grenzpunkte und alle Prüfpunkte.
- Sechs Reihen-CSV-Dateien und `heatmap.csv`: verwendete Diagrammwerte.
- `laufverzeichnis.csv`: Zuordnung von Konfiguration, Kennzahlen und MAT-Datei.
- `laeufe/*.mat`: Rohdaten, Ereignisse, Kennzahlen, einzeln ausgewertete Umläufe.
- `quellstand/`: verwendete Modellfunktionen und Auswertungsskripte.
- `rohdatenaudit.csv`: unabhängige Ergebnisprüfung.
- `matlab.log`, `abschluss.json`: Ausführungsprotokoll und Abschlussstatus.
