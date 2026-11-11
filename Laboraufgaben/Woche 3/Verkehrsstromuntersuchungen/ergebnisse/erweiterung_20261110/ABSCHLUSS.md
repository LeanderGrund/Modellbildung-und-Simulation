# Erweiterte Untersuchungen – abgeschlossen am 11.11.2026

Die [siebenseitige PDF](Woche3_Beta_und_Haltezeiten.pdf) enthält die Parameter,
beide Kurvenscharen, Weg-Zeit-Diagramme bei N = 28 mit 0 s und 18 s Zuschlag
sowie vollständige Wertetabellen. Eine identische Kopie liegt direkt im
Woche-3-Projektordner. Der Bericht enthält keine Ergebnisinterpretation.

## Parameter

- N = 20, 28, 36 und 44; jeweils eine eigene Farbe und ein eigenes Punktsymbol.
- p = 0,2 für beide unabhängigen Zufallsstörungsarten.
- Beta-Reihe: 0 bis 0,50 in 0,05-Schritten; fester Stationszuschlag 0 s.
- Haltezeitreihe: 0, 6, 12, 18, 24, 30, 36, 42 und 45 s zusätzlich auf jeden
  GTFS-Stationshalt; beta = 0,20 1/s. Die neun ganzzahligen Stufen enthalten
  die beiden Grenzen und 18 s; der letzte Abstand beträgt 3 s.
- 80 km/h Vorgabe, 79,2 km/h effektiv; Raster 1 m / 1 s; Zuglänge 148 m.
- Reale S41; 117 OSM-Signalabschnitte; GTFS-Stationshalte.
- Antizipation anhand des Zugendes des nächsten Vorgängers in höchstens
  zwei vorausliegenden Blöcken; nur bei langsamerem Vorgänger.
- Zufälliger Stationszusatz weiterhin diskret gleichverteilt zwischen
  0 und 120 s bei einem Treffer mit p, unabhängig vom festen Zuschlag.
- 60 min Einschwingen und 180 min Messung; Startwert 42; ein Lauf je Fall.
- Weg-Zeit-Diagramme: alle 28 Züge bei beta = 0,20 im Messfenster Minute 60–240,
  aus denselben Trajektorien wie die jeweiligen Durchsatzpunkte.

## Einheitliche Startaufstellung

Für N = 44 findet die ursprüngliche Suche aus freien Zeitphasen bereits
ohne Haltezuschlag keine sichere gemeinsame Anfangsbelegung. Für sämtliche
erweiterten Reihen wurde deshalb die geprüfte ruhende Blockaufstellung
verwendet: Zugspitzen gleichmäßig über Blocknummern verteilt, jeweils am
Blockende; Anfangsgeschwindigkeit null. Die vollständigen Zugkörper und die
exklusive Blockbelegung werden geprüft. Die N = 28-Reihe wurde ebenfalls
neu gerechnet, um unterschiedliche Startmethoden innerhalb der neuen
Kurvenscharen zu vermeiden. Die Einschwingzeit bleibt 60 min.

Die neue Initialisierungsoption liegt ausschließlich in `+sbahn3x`.
Die Bewegungs-, Sicherheits-, Störungs- und Antizipationsregeln bleiben
gegenüber `+sbahn3` erhalten. Die bisherigen Modelle, Rohdaten und die
bisherige PDF wurden nicht überschrieben. Einzelheiten stehen in
`../../ERWEITERUNG.md` und im gespeicherten Quellstand.

## Prüfungen und Herkunft

Alle 76 verschiedenen Konfigurationen haben die Modellprüfungen bestanden.
Die 44 Beta-Punkte und 36 Haltezeitpunkte ergeben zusammen 80 dargestellte
Punkte. Die vier Schnittpunkte bei beta = 0,20 und Zuschlag 0 s verwenden
jeweils dieselbe Rohdatei; sie sind in `shared_point` gekennzeichnet.

Die unabhängige Auswertung hat alle 76 Rohdatensätze geprüft und sämtliche
80 Diagrammpunkte ihren Konfigurationen und Trajektorien zugeordnet:

- Anfangspositionen und Nullgeschwindigkeit entsprechend der gemeinsamen
  Methode; keine sich überschneidenden Zugkörper oder Anfangsblöcke.
- Abfahrten aller Züge an Station 1 im halboffenen Fenster `[3600,14400)` s;
  Durchsatz = Detektorzahl / 3 h. Kennzahlen, CSV, MATLAB-Matrizen und
  gezeichnete Koordinaten stimmen überein.
- Für jeden Zug und jeden Zeitschritt: Vorgänger, Zugende, zyklischer
  Blockabstand, Antizipationsberechtigung und Bremsbruchteile rekonstruiert.
- Höchstens 1 m/s² Geschwindigkeitsänderung; blockierter Stillstand enthält
  keine Bewegung und keine geplanten Stationswartezeiten.
- Eingabedaten-Prüfsummen und Modellquellen gegen den gespeicherten
  Quellstand abgeglichen.
- Zehn Grenzfalltests der Antizipation und sechs kurze Prüfungen der
  Aufstellung bis N = 44 und 45 s Zuschlag bestanden.

`rohdatenaudit.csv`, `bericht_pruefung.json`, `blockpruefung.csv` und
`initialisierung_pruefung.csv` dokumentieren die Prüfungen. Die PDF wurde
zusätzlich auf Lesbarkeit, Beschriftungen und Farbzuordnung kontrolliert.

Die Messung begann am 10.11.2026; der Ergebnisordner behält dieses Datum.
`parameter.json`, `laufindex.csv`, `beta.csv`, `haltezeiten.csv`,
`alle_punkte.csv`, `ergebnis.mat` und `laeufe/*.mat` enthalten Parameter,
Kennzahlen und vollständige Trajektorien. `grafiken/` enthält alle sieben
Berichtsseiten einzeln als PNG und PDF. `quellstand/` sichert die Quellen.
