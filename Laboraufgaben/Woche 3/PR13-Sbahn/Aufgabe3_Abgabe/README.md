# Abgabe – Aufgabe 3 aus Arbeitsblatt 3

`Brandbrief_Aufgabe3.pdf` ist die Lösung: ein hypothetischer, nicht versandter
Brief an die Berliner Senatsverwaltung, begrenzt auf zwei Seiten. Enthalten
sind Betriebsproblem und Änderungsvorschlag, ein grafischer Modellvergleich,
Nutzen/Aufwand/Grenzen sowie eine begründete Empfehlung. Die bearbeitbare
Fassung steht in `Brandbrief_Aufgabe3.md`.

Der Brief verwendet ausschließlich die schon vorhandene Untersuchung vom
10.11.2026 (`Verkehrsstromuntersuchungen/ergebnisse/erweiterung_20261110`).
Die verwendeten acht Ergebnisse stehen mit Herkunft und Parametern in
`belege/`. Es wurden für diese reduzierte Abgabe keine neuen Simulationen
berechnet. Die zuvor zusätzlich gestartete Messreihe gehört nicht zur Abgabe.

## Eine Simulation manuell ausführen

1. ZIP vollständig entpacken; die Ordnerstruktur beibehalten.
2. In MATLAB `SIMULATION_STARTEN.m` öffnen.
3. Die Parameter am Dateianfang einstellen und das gesamte Skript ausführen.
   Es wird **genau eine** Kombination berechnet.

Voreinstellung: N = 28, beta = 0,20 1/s, p = 0,20, kein fester Haltezuschlag,
240 Minuten Dauer, davon 60 Minuten Einschwingen, Startwert 42.
Für das Basismodell `beta = 0` setzen und erneut manuell starten.
Für einen kurzen eigenen Probelauf müssen sowohl Dauer als auch
Einschwingzeit entsprechend verkleinert werden.

| Parameter | Bedeutung |
|---|---|
| `zugzahl` | Anzahl der Züge auf dem geschlossenen Ring |
| `beta`, `antizipationAktiv` | Stärke bzw. Aktivierung der Zusatzbremsregel |
| `stoerwahrscheinlichkeit` | Jeweils p für Blockbremsung und Stationszusatz |
| `zusaetzlicheHaltezeit_s` | Fester Zuschlag zu jedem GTFS-Stationshalt |
| `maximalerZufallshalt_s` | Obergrenze des zufälligen Stationszusatzes |
| `maximalgeschwindigkeit_kmh` | Geschwindigkeitsvorgabe, im Raster abgerundet |
| `simulationsdauer_min` | Dauer dieses einzelnen Laufs |
| `einschwingzeit_min` | Beginn der Durchsatzmessung innerhalb dieses Laufs |
| `zufallsstartwert` | Startwert des lokalen Zufallsgenerators |
| `animationAnzeigen` | Laufende geografische Darstellung ein-/ausschalten |

Feste Modellgrundlage: S41-Geometrie, 27 Stationen, 117 aus OSM abgeleitete
Signalabschnitte, 148 m Zuglänge, Raster 1 m/1 s, Beschleunigen/Bremsen mit
höchstens 1 m/s², GTFS-Stationshalte. Die ruhende Startaufstellung verteilt
die Zugspitzen gleichmäßig über Blocknummern; siehe `private/initialize.m`.
Bei p-Treffer wird an einer Blockeinfahrt auf die halbe Einfahrgeschwindigkeit
abgebremst; an einer Stationsankunft wird ein diskret gleichverteilter
Zufallszusatz von 0 bis zur angegebenen Obergrenze ausgelost.

Die Antizipation wirkt nur auf langsamere Vorgänger, deren **Zugende** im
ersten oder zweiten Block voraus liegt. Ihre Verzögerung lautet
`a = max(-1, beta*(v_Vorgänger-v_Zug))`; Bruchteile werden über Zeitschritte
aufgesammelt. Bei beta = 0 entfällt die Zusatzregel. Signal- und
Sicherheitsregeln gelten weiterhin. beta hat hier die Einheit **1/s**.

Das Skript zeigt Weg-Zeit-Diagramm, mittlere Geschwindigkeit, Fahrbewegung
von Zug 1 und geografischen Endzustand. Es speichert diesen einen Lauf und
seine Grafiken im neu angelegten Ordner `ausgaben/<Zeitstempel>/`.
Der Durchsatz zählt Abfahrten an Station 1 nach der Einschwingzeit.

## Dateien und Voraussetzungen

- `modell/+sbahn3x/`: unveränderter Laufzeit-Modellkern der vorhandenen Studie.
- `daten/`: sämtliche lokalen Strecken-/Fahrplandaten einschließlich Herkunft.
- `belege/`: nur die für den Brief verwendeten Bestandswerte und die Abbildung.
- `quellen.json`: Quellen des Briefs.

Benötigt wird MATLAB; vorhandener Modellkern geprüft mit R2026a.
Zusatztoolboxen, Python, Internetzugriff oder benachbarte Projektordner sind
für die manuelle Simulation nicht erforderlich. Der neue Starter wurde
statisch geprüft; auf einen weiteren Simulationslauf wurde entsprechend
der Vorgabe verzichtet. Die Sicherheitsprüfungen innerhalb eines einzelnen
Laufs sind Bestandteil des Modells. Skripte zum automatischen Erstellen
von Parameterreihen oder Testfällen sind nicht enthalten.

## KI-Unterstützung und Nachvollziehbarkeit

Codex wurde für Aufgabenanalyse, Quellenrecherche, Brief, Auswahl bereits
vorhandener Messwerte, manuellen Starter und Zusammenstellung eingesetzt.
Der Modellkern und die mitgelieferten Daten wurden inhaltlich nicht verändert;
Testreihen-Starter und separate Testfunktionen wurden aus dem Paket weggelassen.
Die acht Briefwerte wurden mit den schon vorliegenden Rohdaten und
Prüfprotokollen abgeglichen. Die PDF wurde auf zwei Seiten und lesbare
Darstellung geprüft; das ZIP auf vollständige Dateien und Prüfsummen.
Die Grenzen des Einzellaufvergleichs sind im Brief ausdrücklich benannt.
