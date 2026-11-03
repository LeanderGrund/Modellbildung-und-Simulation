# Abgeschlossen am 02.11.2026

Die vollständige Auswertung steht in
[`Verkehrsstrom_Gesamtvergleich.pdf`](Verkehrsstrom_Gesamtvergleich.pdf):
elf Seiten mit Parametern, fünf Heatmaps und fünf Wertetabellen, ohne
Ergebnisinterpretation. Alle Heatmaps verwenden dieselbe Farbskala.

| Reihe | x-Werte | Zugzahlen (y) | Feste Parameter | Punkte |
| --- | --- | --- | --- | ---: |
| Bisherige p-Reihe | 0:0,1:1 | 12:4:40 | Langsames Abbremsen aus | 88 |
| Neue p-Reihe | 0:0,1:1 | 12:4:40 | Langsames Abbremsen an; beta = 0,20 1/s | 88 |
| Bisherige beta-Reihe | 0,05:0,05:0,50 1/s | 12:4:40 | Langsames Abbremsen an; p = 0 | 80 |
| Neue beta-Reihe | 0,05:0,05:0,50 1/s | 12:4:40 | Langsames Abbremsen an; p = 0,3 | 80 |
| Neue Haltezuschlag-Reihe | 0:6:30 s je Station | 12:4:40 | Langsames Abbremsen an; p = 0,3; beta = 0,20 1/s | 48 |

Gemeinsam: 80 km/h Vorgabe, 79,2 km/h effektiv, 60 min Einschwingen und
180 min Messung, Zufallsstartwert 42, zufälliger Stationszusatz 0 bis 120 s,
S41 mit GTFS-Stationshalten und OSM-Signalabschnitten. Die ersten vier Reihen
haben keinen festen Haltezuschlag. `versuchsplan.json` enthält die Parameter
und Herkunftspfade. Die beiden bisherigen Reihen werden unverändert aus
`../heatmaps_20261102_aaeb14/` übernommen.

216 neue Diagrammpunkte wurden erfolgreich bereitgestellt: 200 neue
Simulationsläufe und 16 weitere Verwendungen gemeinsamer Schnittpunkte.
Diese identischen Punkte für die acht Zugzahlen tragen `reuse_source` mit
ihrem Herkunftspfad. Genau ein Lauf pro Konfiguration; keine Variation des
Zufallsstartwerts. Rohdaten und Eingaben stehen unter `p_beta020/`, `beta_p030/`
und `halte_p030_beta020/` als MAT, CSV und JSON. Die drei neuen MATLAB-Grafiken
liegen dort jeweils in `grafiken/` als PNG und FIG; `pdf_grafiken/` enthält
alle elf Berichtsseiten als PNG und einzelne PDFs.

## Prüfungen

- Sämtliche 216 neuen Diagrammpunkte haben die Modellprüfungen bestanden.
- `rohdatenaudit.csv` dokumentiert die Nachzählung aller 384 dargestellten
  Punkte aus den gespeicherten Zugpositionen im Messfenster `[3600,14400)` s.
  Detektorzahl, Kennzahlen, CSV und Heatmap-Matrix stimmen überein.
- Gemeinsame Schnittpunkte der drei neuen Reihen stimmen exakt überein.
  Acht unabhängig neu berechnete Punkte bei p = 0 und beta = 0,20 stimmen
  zusätzlich exakt mit der bisherigen beta-Reihe überein.
- Sechs kurze Haltezuschlagspunkte wurden über den von MATLAB importierten
  Code der aktualisierten `.mlx` ausgeführt. Achsenübergreifende Übernahme
  identischer Konfigurationen und Ablehnung veränderter Konfigurationen
  wurden geprüft. Die Rohdaten liegen unter `funktionspruefung/`.
- Der native Live Editor enthält 26 Bedienelemente und vier Achsenauswahlen.
  Die zuvor gespeicherten Benutzerwerte wurden beibehalten.
- Der Modellkern ist in allen 21 MATLAB-Dateien identisch zum bisherigen
  Vergleich. `modell_hashes.json` und `quellstand/` dokumentieren die Quellen.
- Die PDF hat elf Seiten; die neuen Heatmaps und eine Wertetabelle wurden
  zusätzlich visuell auf Beschriftung und Lesbarkeit kontrolliert.

`abschluss.json`, `matlab.log` und `batch.log` dokumentieren den erfolgreichen
MATLAB-Lauf. Der ursprüngliche Lizenzfehler 15 wurde vor dem Start behoben;
`vorpruefung.log` und die deutlich als vorläufig gekennzeichnete
`Messplan_und_bisherige_Heatmaps.pdf` bleiben als früherer Arbeitsstand erhalten.

## Wiederholen oder fortsetzen

Im Projektordner in MATLAB:

```matlab
ausgabe = run_trafic_flow_vergleich( ...
    "ergebnisse/trafic_flow/vergleich_20261102_b7d516");
```

Anschließend in PowerShell:

```powershell
py tools/bericht_trafic_flow_vergleich.py ergebnisse/trafic_flow/vergleich_20261102_b7d516
```

Der bestehende Ordner wird mit strikter Konfigurationsprüfung fortgesetzt.
Für eine vollständige Neuberechnung `run_trafic_flow_vergleich` ohne Argument
ausführen und den ausgegebenen neuen Ordner an das Python-Skript übergeben.
`ausgangsstand/` sichert die Dateien vor den Änderungen.
