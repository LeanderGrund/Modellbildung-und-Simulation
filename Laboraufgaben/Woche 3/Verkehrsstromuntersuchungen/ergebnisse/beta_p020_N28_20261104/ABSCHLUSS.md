# Woche 3 – abgeschlossen am 04.11.2026

Die [vierseitige PDF](Woche3_Beta_zwei_Bloecke.pdf) enthält die verwendeten
Parameter, den Durchsatz über beta, das Weg-Zeit-Diagramm bei beta = 0,20 und
die vollständige Wertetabelle. Es ist keine Ergebnisinterpretation enthalten.
Eine identische Kopie liegt direkt im Projektordner `Verkehrsstromuntersuchungen/`.

## Verwendete Parameter

- p = 0,2 für Zufallsbremsungen und zufällige Stationszusatzhalte.
- N = 28; beta = 0:0,05:0,50 1/s, einschließlich beta = 0.
- 80 km/h Vorgabe, 79,2 km/h effektiv; Raster 1 m / 1 s; Zuglänge 148 m.
- Antizipation nur, wenn das **Zugende** des räumlich nächsten Vorgängers
  im ersten oder zweiten OSM-Block vor dem Block der eigenen Zugspitze liegt.
  Das Zugende ist die hinterste belegte Rasterzelle. Der Ringschluss wird
  zyklisch berücksichtigt. Die 117 OSM-Blöcke haben unterschiedliche Längen.
- beta = 0 hat keinerlei zusätzliche Antizipationswirkung; insbesondere
  bleibt die normale Beschleunigung möglich.
- GTFS-Stationshalte, fester Zuschlag 0 s; zufälliger Zusatz bei einem Treffer
  diskret gleichverteilt zwischen 0 und 120 s.
- 60 min Einschwingen, 180 min Messung; Zufallsstartwert 42.
- Genau ein Lauf je beta, insgesamt elf verschiedene Simulationsläufe.
- Weg-Zeit-Diagramm: beta = 0,20; alle 28 Züge von Minute 60 bis 240.
  Die Linien zeigen die Position der Zugspitzen und werden am Ringschluss
  unterbrochen. Es werden die Trajektorien der Durchsatzmessung verwendet.
- Die Untersuchung zusätzlicher fester Haltezeiten wurde vorerst ausgelassen.

## Prüfungen

`blockpruefung.csv` dokumentiert zehn bestandene Prüfungen: Zugende im ersten,
zweiten und dritten Block; exakter Übergang vom zweiten zum dritten Block;
dieselben Grenzfälle am Ringschluss; beta = 0; kleine beta-Werte und das
Zurücksetzen von Bremsbruchteilen außerhalb des Bereichs.

Alle elf Läufe haben die Modellprüfungen bestanden. `rohdatenaudit.csv`
dokumentiert die unabhängige Nachzählung der Abfahrten im halboffenen Fenster
`[3600,14400)` s. Die Detektorzahlen, Kennzahlen, MATLAB-Vektoren, CSV und
gezeichnete Kurve stimmen überein. Vorgängerreihenfolge, Zugende, Blockabstand,
Antizipationsberechtigung und Bremsbruchteile wurden zusätzlich für jeden Zug
und jeden Zeitschritt rekonstruiert. Die Beschleunigungsgrenzen und die Trennung
von geplantem Halt und blockiertem Stillstand wurden geprüft.

Für beta = 0 stimmen die vollständigen Trajektorien, Geschwindigkeiten,
Halteuhren, Blockierungen und Zufallsbremsereignisse exakt mit dem früheren
Woche-2-Lauf ohne Antizipation bei N = 28 und p = 0,2 überein. Die Herkunft
dieses zusätzlichen Vergleichs steht in `beta0_referenzpruefung.json`.

`bericht_pruefung.json` bestätigt den erfolgreichen Berichtslauf und die vier
PDF-Seiten. Alle vier Seiten wurden visuell auf Lesbarkeit und Beschriftungen
kontrolliert. `matlab.log` dokumentiert die elf berechneten Punkte.

## Dateien und Modellkopie

`laeufe/beta_01.mat` bis `beta_11.mat` enthalten vollständige Trajektorien,
die tatsächlich verwendeten Konfigurationen, Kennzahlen und Modellprüfungen.
`parameter.json`, `beta.csv` und `ergebnis.mat` enthalten die Zusammenfassung.
`grafiken/` enthält alle Berichtsseiten einzeln als PNG und PDF.

Die neue Modellkopie liegt unter `modell/+sbahn3/` im Projektordner;
`quellstand/` sichert die zur Berechnung verwendeten Modell- und Skriptdateien.
Die Änderung der Antizipation steht in `private/advance.m`. Die Ausgangsdateien
unter Woche 2 und die dortige Abgabe wurden nicht verändert.
