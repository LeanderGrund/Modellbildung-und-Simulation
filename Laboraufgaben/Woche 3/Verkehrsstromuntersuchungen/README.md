# Woche 3: Verkehrsstromuntersuchungen

Die aktuelle [PDF mit beiden Kurvenscharen und Weg-Zeit-Diagrammen](Woche3_Beta_und_Haltezeiten.pdf)
enthält die abgeschlossene Erweiterung für **N = 20, 28, 36 und 44** bei p = 0,2.
Auf sieben Seiten sind Parameter, Diagramme und vollständige Wertetabellen
dokumentiert, ohne Ergebnisinterpretation.

| Untersuchung | Werte | Weitere Festlegung |
| --- | --- | --- |
| Durchsatz über beta | 0:0,05:0,50 1/s | Fester Haltezuschlag 0 s |
| Durchsatz über zusätzlichen Stationshalt | 0, 6, 12, 18, 24, 30, 36, 42, 45 s | beta = 0,20 1/s |
| Weg-Zeit-Diagramme | N = 28; Zuschlag 0 s und 18 s | beta = 0,20 1/s |

Beide Kurvenscharen zeigen vier verschiedenfarbige Linien für die Zugzahlen.
Die neun Haltezeitstufen enthalten beide Grenzen und 18 s; der letzte Schritt
beträgt 3 s. Es werden feste zusätzliche Sekunden auf jeden GTFS-Stationshalt
addiert. Zufällige Stationszusätze mit p = 0,2 bleiben unabhängig davon aktiv.

Alle 76 verschiedenen Läufe und die daraus dargestellten 80 Punkte sind
geprüft. Die vier gemeinsamen Punkte bei beta = 0,20 und Zuschlag = 0 s
verwenden jeweils dieselbe Rohdatei. Die vollständigen Ergebnisse stehen unter
[`ergebnisse/erweiterung_20261110/`](ergebnisse/erweiterung_20261110/);
[`ABSCHLUSS.md`](ergebnisse/erweiterung_20261110/ABSCHLUSS.md) dokumentiert die Prüfungen.
Der Ordner ist nach dem Beginn der Berechnung am 10.11.2026 benannt;
abgeschlossen wurde die Dokumentation am 11.11.2026.

## Einheitliche neue Startaufstellung

Für N = 44 findet die bisherige freie Phasenverteilung keine sichere
Anfangsbelegung. Deshalb verwenden alle erweiterten Reihen dieselbe geprüfte,
zunächst ruhende Blockaufstellung. Auch N = 28 wurde neu berechnet.
Die Simulationsdauer bleibt bei 60 min Einschwingen plus 180 min Messung.
Die Antizipation bezieht sich weiterhin auf das Zugende des Vorgängers
in höchstens zwei vorausliegenden OSM-Blöcken.

Die zusätzliche Initialisierungsoption liegt in `modell/+sbahn3x/`.
Die bisherigen Modelle, Skripte und Messungen bleiben separat erhalten.
Vollständige Methoden- und Dateidokumentation: [ERWEITERUNG.md](ERWEITERUNG.md).

## Wiederholen

In MATLAB aus diesem Ordner:

```matlab
ausgabe = run_woche3_erweiterung;
disp(ausgabe)
```

Danach im Terminal:

```powershell
py bericht_woche3_erweiterung.py <Ausgabeordner>
```

Ein vorhandener Ergebnisordner kann als Argument an das MATLAB-Skript
übergeben werden, um geprüfte identische Konfigurationen wiederzuverwenden.
Die Simulation verwendet vier lokale MATLAB-Basissitzungen ohne Parallel
Computing Toolbox. Für die PDF werden Python, NumPy, SciPy und Matplotlib
benötigt. Alle Strecken- und Fahrplandaten liegen lokal unter `daten/`.

## Bisheriger Stand

Die [ursprüngliche PDF mit einer N=28-Reihe](Woche3_Beta_zwei_Bloecke.pdf)
und die Rohdaten unter `ergebnisse/beta_p020_N28_20261104/` sind erhalten.
Die vorherige Anleitung steht unverändert in
[README_vor_erweiterung_20261111.md](README_vor_erweiterung_20261111.md).
