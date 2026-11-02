# trafic_flow.mlx

`trafic_flow.mlx` in MATLAB öffnen, die Bedienfelder einstellen und das gesamte
Live Script mit **Run** ausführen. Benötigt wird MATLAB mit Live Editor; erstellt
und geprüft mit R2026a. Es werden nur lokale Strecken- und Fahrplandaten verwendet.

## Betriebsarten und Eingaben

Die Checkbox **Verkehrsstromuntersuchung** schaltet zwischen den Betriebsarten um.
Die übrigen gemeinsamen Eingaben gelten für beide Betriebsarten.

| Parameter | Bedeutung |
| --- | --- |
| Anzahl der Züge | Zugzahl im Einzellauf; in der Untersuchung gilt der Zugzahlbereich |
| Einschwingzeit / Messdauer [min] | Gesamtdauer ist die Summe; Durchsatz wird nur während der Messdauer ermittelt |
| Wahrscheinlichkeit p | Dieselbe Wahrscheinlichkeit für beide unabhängigen Störungsarten, zwischen 0 und 1 |
| Zeitspanne Stationszusatzhalt [s] | Ganzzahliger Höchstwert der zufälligen zusätzlichen Haltezeit |
| Langsames Abbremsen / beta [1/s] | Zusätzliche Geschwindigkeitsanpassung an einen langsameren Vorgänger |
| Zusätzliche Wartezeit / fester GTFS-Zuschlag [s] | Checkbox aktiviert einen festen Zuschlag auf jeden geplanten Stationshalt |
| Geschwindigkeit Minimum / Maximum / Schritt [km/h] | Geschwindigkeitsbereich der Untersuchung, innerhalb 3,6 bis 80 km/h |
| Zugzahl Minimum / Maximum / Schritt | Ganzzahlige Zugzahlen der Untersuchung |

Fest eingestellt sind reale Ringbahn S41, geografische Darstellung,
Beschleunigen und Bremsen mit höchstens ±1 m/s², OSM-Signalabschnitte,
GTFS-Stationshalte, 0,05 s Bildpause, 10 Schritte Bildabstand, Zufallsstartwert 42,
148 m Zuglänge und das Raster Δx = 1 m / Δt = 1 s. Der eingetragene
Zielblockabstand von 500 m ist bei OSM-Signalabschnitten ohne Wirkung.
Der Einzellauf verwendet 80 km/h Eingabe, entsprechend 22 m/s = 79,2 km/h.

Die Bereichsobergrenzen werden eingeschlossen. Ist der Bereich kein ganzzahliges
Vielfaches der Schrittweite, ist der letzte Schritt kürzer. Geschwindigkeiten
werden auf ganze m/s abgerundet; mehrere Eingaben derselben Stufe ergeben nur
einen Untersuchungspunkt. Die Heatmap beschriftet die tatsächlich verwendeten
Geschwindigkeiten. Ihre Zeilen und Spalten entsprechen den diskreten
Untersuchungspunkten, auch bei ungleichmäßigen letzten Schritten.

## Störungen und Antizipation

**Zufallsbremsung:** Jede tatsächliche Einfahrt der Zugspitze in einen neuen
Block löst genau eine Bernoulli-Prüfung mit Wahrscheinlichkeit p aus. Das gilt
auch für mehrere kurze Blöcke innerhalb eines Zeitschritts und den Ringübergang.
Der Start innerhalb eines Blocks zählt nicht als Einfahrt. Bei einem Treffer
wird `floor(v_Eintritt/2)` als Bremsziel in m/s gespeichert. Ab dem Folgeschritt
wird mit −1 m/s² gebremst. Nach Erreichen des Ziels darf der Zug sofort wieder
mit höchstens +1 m/s² beschleunigen, sofern Stationen, Blockbelegung und Verkehr
es erlauben. Ein weiterer Treffer kann ein noch niedrigeres Ziel setzen.
Sicherheitsregeln können eine weitere Geschwindigkeitsreduktion verlangen.

**Zufälliger Stationszusatzhalt:** Bei jeder Ankunft wird unabhängig einmal mit
p geprüft. Bei einem Treffer wird eine ganzzahlige Dauer aus der diskreten
Gleichverteilung `U{0,...,Zeitspanne}` gezogen. Diese zusätzliche Zeit wird nach
dem geplanten Aufenthalt abgewartet. Beim Simulationsstart bereits laufende
Halte werden nicht nachträglich verlängert. Positive Zusatzhalte und deren
Zeiten werden protokolliert; ein Treffer mit Dauer null verändert den Halt nicht.

**Gesamthalt:** GTFS-Halt + aktivierter fester Zuschlag + zufälliger Zusatz.
Der feste Zuschlag gehört zum geplanten Halteprofil und wird in der freien
Referenzumlaufzeit berücksichtigt. Die Zufallsstörungen bleiben bei der
Berechnung dieses ungestörten Referenzumlaufs ausgeschaltet.

**Antizipation:** Wenn der in Fahrtrichtung räumlich nächste Zug langsamer ist,
gilt die zusätzliche Beschleunigung `a = beta * (v_Vorgänger - v_Zug)`, begrenzt
auf mindestens −1 m/s². Bruchteile einer Geschwindigkeitsstufe werden über
aufeinanderfolgende Schritte aufsummiert. Andernfalls gilt die normale
Beschleunigung bis höchstens +1 m/s². Bei einem einzigen Zug ist diese Regel
wirkungslos. Stationen und die konservative Bremsreserve vor belegten Blöcken
oder Zugenden begrenzen die Bewegung zusätzlich.

## Auswertung und Dateien

Der Durchsatz ist die Anzahl der **Abfahrten an Station 1 (Beusselstraße)** im
halboffenen Messintervall `[Einschwingzeit, Einschwingzeit + Messdauer)`, geteilt
durch die Messdauer in Stunden. Er wird in Zügen/h ausgegeben. Andere bisherige
Einzellaufkennzahlen beziehen sich auf die gesamte simulierte Zeit und sind
entsprechend beschriftet. Unvollständige Umläufe liefern weiterhin NaN.

Im Einzellauf bleiben geografische Animation, Raum-Zeit-Diagramm, Fahrdynamik
von Zug 1, mittlere Netzgeschwindigkeit, Kennzahlen, Stationstabelle,
GTFS-Fahrzeitvergleich und Störungsauswertung erhalten. Vollständige Ereignisse
werden gespeichert; im Live Script werden höchstens die ersten 20 Zeilen je
Ereignisprotokoll angezeigt.

In der Untersuchung wird genau **ein Lauf je Kombination** berechnet. Es
entsteht ausschließlich die Heatmap mit Geschwindigkeit auf der x-Achse,
Zugzahl auf der y-Achse und zeitlich gemitteltem Durchsatz als Farbwert.
Unzulässige Kombinationen, etwa ohne sichere Startbelegung, werden grau/NaN
mit Fehlergrund gespeichert. Sie werden nicht als Nulldurchsatz interpretiert.
Die gemeinsame Startphase wird bei Bedarf auf eine sichere Belegung verschoben;
die Zugzahl und die zeitlich gleichmäßigen freien Startphasen bleiben erhalten.

Jeder Lauf bekommt einen neuen Ordner unter `ergebnisse/trafic_flow/`:

- `grafiken/`: alle zugehörigen Grafiken, jeweils als PNG und MATLAB-FIG;
- `parameter.json`: Eingaben und feste Basiskonfiguration;
- `ergebnis.mat`: Auswertung, im Einzellauf auch vollständige Trajektorien;
- `LAUF.md`: Messdefinition und kurze Laufdokumentation;
- Einzellauf: CSV-Tabellen für Parameter, Kennzahlen, Stationen, GTFS-Vergleich,
  Störungen, Stationsereignisse und sämtliche Blockeinfahrten;
- Untersuchung: `verkehrsstrom.csv` und `laeufe/*.mat` mit den vollständigen
  Einzelläufen und ihren tatsächlich verwendeten Konfigurationen.

## Gespeicherte Tests

Der [Testbericht vom 29.10.2026](ergebnisse/trafic_flow/test_20261029_143513/TESTBERICHT.md)
dokumentiert 78 bestandene Modelltests, beide ausgeführten Betriebsarten und
die fünf gespeicherten Grafiken.

`ergebnisse/trafic_flow/LETZTER_TEST.txt` verweist auf den zuletzt erfolgreich
abgeschlossenen Test. In diesem Ordner erläutert `TESTBERICHT.md` die Eingaben,
Ergebnisse und Prüfungen beider Betriebsarten. Der Test führt den von MATLAB
aus dem ausgelieferten `.mlx` exportierten Code aus. Die Animation wird dabei
für die Batchausführung deaktiviert, ihr geografischer Endzustand bleibt erhalten.

Wiederholen:

```matlab
addpath('tools');
test_trafic_flow;
```

Die gespeicherten Grafikdateien lassen sich zusätzlich mit
`addpath('tools'); check_trafic_flow_graphics` auf Achsen- und Titelfarben prüfen.

Der Test führt auch die bestehenden Modell- und Woche-1-Regressionstests aus.
Für programmgesteuerte Läufe können `trafic_flow_defaults` und
`run_trafic_flow` verwendet werden, beispielsweise:

```matlab
eingaben = trafic_flow_defaults;
eingaben.study = true;
ergebnis = run_trafic_flow(eingaben);
```

## Quelltext und Live-Script-Erzeugung

Die lesbare Vorlage liegt in `tools/trafic_flow_source.m`. Die ausgelieferte
Datei enthält native Live-Editor-Checkboxen, Zahlenfelder und eine
Parameterübersicht als formatierte Tabelle. Nach Änderungen an der Vorlage
kann sie im Projektordner neu erzeugt werden:

```matlab
matlab.internal.liveeditor.openAndSave( ...
    fullfile(pwd,'tools','trafic_flow_source.m'), ...
    fullfile(pwd,'trafic_flow.mlx'));
```

Danach in PowerShell `py tools/build_trafic_flow.py` ausführen. Der Python-Schritt
ergänzt die nativen Bedienelemente und die Parametertabelle. Die erzeugte Datei
wird anschließend mit `test_trafic_flow` durch MATLAB eingelesen und geprüft.
Die normale Benutzung benötigt Python nicht.
