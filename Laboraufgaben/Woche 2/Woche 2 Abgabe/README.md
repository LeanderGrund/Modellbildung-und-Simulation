# Woche 2 Abgabe – S-Bahn-Simulation

Dieses Paket enthält das Live Script, den Modellkern und sämtliche für den
normalen Betrieb benötigten Strecken- und Fahrplandaten. Es läuft unabhängig
vom ursprünglichen Projektordner und einem benachbarten Ordner „Woche 1“.

## Start

1. Die ZIP-Datei vollständig entpacken.
2. In MATLAB den entpackten Ordner `Woche 2 Abgabe` als aktuellen Ordner wählen.
3. `trafic_flow.mlx` öffnen, Eingaben einstellen und das gesamte Live Script
   mit **Run** ausführen.

Verwendet und geprüft wurde MATLAB R2026a. Die Simulation benötigt nur MATLAB;
Python und die Parallel Computing Toolbox werden für den normalen Live-Script-
Betrieb nicht benötigt. Die mitgelieferten Daten werden lokal gelesen.

Nach einem Lauf werden Grafiken als PNG und MATLAB-FIG sowie Eingaben und
Rohdaten in einem neuen Unterordner von `ergebnisse/trafic_flow/` gespeichert.
Dieser Ausgabeordner wird bei Bedarf automatisch angelegt.

## Enthaltene Dateien

| Datei / Ordner | Aufgabe |
| --- | --- |
| `trafic_flow.mlx` | Bedienoberfläche für Einzellauf und Verkehrsstromuntersuchung |
| `trafic_flow_defaults.m` | Standardwerte der Eingaben |
| `run_trafic_flow.m` | Konfiguration, Simulation, Auswertung, Grafiken und Speicherung |
| `trafic_flow_parallel_worker.m` | Optionaler Helfer für ausdrücklich aktivierte parallele API-Läufe unter Windows |
| `modell/+sbahn2/` | Vollständiger Modellkern einschließlich privater Funktionen, Laufprüfungen und Darstellung |
| `daten/ringbahn_2026-10-14/` | Verwendete S41-Strecken-, Signal- und GTFS-Fahrplandaten mit Herkunftsangaben |
| `SHA256SUMS.txt` | Prüfsummen aller mitgelieferten Dateien außer der Prüfsummenliste selbst |

Die vier Untersuchungsachsen im Live Script sind Maximalgeschwindigkeit,
Störungswahrscheinlichkeit p, Antizipationsfaktor beta und Haltezeitzuschlag.
Die y-Achse ist jeweils die Zugzahl. Der Einzellauf bietet zusätzlich Animation
und die weiteren Diagramme und Tabellen.

Die Fahrregeln stehen hauptsächlich in `modell/+sbahn2/private/advance.m`;
Abstände und Blockgrenzen in `private/trafficLimits.m`. Die Antizipation
verwendet bei langsamerem Vorgänger `a = beta * (v_Vorgänger - v_Zug)` mit
beta in 1/s und höchstens 1 m/s² Verzögerung. Bruchteile werden im
1-m-/1-s-Raster über Zeitschritte aufsummiert.

## Datenpfad und Umfang

In der Abgabekopie wurde ausschließlich der Standard-Datenpfad in
`modell/+sbahn2/defaultConfig.m` auf den mitgelieferten Ordner `daten/`
umgestellt. Die übrigen Modell-, Start- und Hilfsdateien entsprechen den
Originaldateien. Auch die im Live Script gespeicherten Eingabewerte bleiben
erhalten. Die Simulationsregeln wurden nicht verändert.

Der Datenordner enthält die zehn vom Modell gelesenen CSV-Dateien unverändert
sowie Herkunftsinformationen. Testmessungs-Skripte, Unit-Tests, Werkzeuge zur
Datenaufbereitung, frühere Messergebnisse und PDF-Berichte sind nicht Teil
dieser Abgabe. Die Funktionen `private/verify*.m` gehören dagegen zum normalen
Simulationsablauf und sind mitgeliefert.
