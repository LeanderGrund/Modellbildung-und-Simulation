# S-Bahn-Ring – Woche 2

Die Aufgaben aus `SBahn2.pdf` sind vollständig in MATLAB bearbeitet. Die
dreiseitige Ausarbeitung steht in
[`ergebnisse/Ausarbeitung_SBahn2.pdf`](ergebnisse/Ausarbeitung_SBahn2.pdf).
Eine bearbeitbare Textfassung und alle Diagramme liegen daneben.

## Interaktives Live Script

**`trafic_flow.mlx`** bietet einen Einzellauf und eine Verkehrsstromuntersuchung
mit nativen Checkboxen und Zahlenfeldern. Es verwendet den lokalen
Woche-2-Modellkern und speichert Grafiken, Rohdaten und Eingaben in neuen
Unterordnern von `ergebnisse/trafic_flow/`. Die Untersuchung erzeugt ausschließlich
eine Heatmap für Zugzahl und Maximalgeschwindigkeit. Die vollständige Bedienung,
Störungsregeln und Testhinweise stehen in [TRAFIC_FLOW.md](TRAFIC_FLOW.md).

Die erweiterten Zugzahl-, Haltezeit- und Störungsreihen mit blockiertem
Stillstand je Zugumlauf sind in [TRAFIC_FLOW_STUDIEN.md](TRAFIC_FLOW_STUDIEN.md)
beschrieben. Sie lassen sich mit `run_trafic_flow_studien` neu berechnen.

## Start

In MATLAB **`SBahn2.m` ausführen**. Das Skript berechnet beide Aufgaben,
speichert die Ergebnisse und erzeugt anschließend den Bericht.

Alternativ:

```matlab
ergebnisse = run_sbahn2;
```

Danach im Terminal:

```powershell
py tools/erstelle_bericht.py
```

MATLAB R2026a und Python mit `numpy`, `scipy`, `matplotlib` wurden verwendet.
Die eigentliche Simulation braucht nur MATLAB. Die Berichtserzeugung liest
ausschließlich bereits berechnete Daten und benötigt keine Internetverbindung.
Die Skripte bestimmen ihre Pfade relativ zum Projekt; `Woche 1` muss neben
`Woche 2` erhalten bleiben. Erneutes Ausführen ersetzt die Ergebnisdateien.

## Inhalt und Vorgehen

- **Aufgabe 1:** Vorab festgelegte Kalibrierung auf die Zeit von Abfahrt
  Beusselstraße bis zur Rückkehrankunft. Neun Geschwindigkeitsstufen werden
  vollständig durchsucht; reine Fahrzeiten aller 27 Stationsabschnitte werden
  anschließend geprüft und nicht zur Nachoptimierung verwendet.
- **Aufgabe 2:** Acht Zugzahlen von 12 bis 40 bei unverändertem GTFS-Halteprofil;
  sechs GTFS-Profile mit Zuschlägen von 0, 6, 12, 18, 24 und 30 s je Station
  bei festem N=36. Jeweils eine Stunde Einschwingen
  und drei Stunden Messung. Durchsatz am festen Abfahrtsdetektor Station 1.
  Rückstaus sind im Raum-Zeit-Diagramm gesondert markiert.
- **Vergleichbarkeit:** Die Zugzahlstudie beginnt bei N=12; der Ausgangsfall
  wird als grüner Stern markiert. N=36 und GTFS+0 sind in beiden Studien
  hinsichtlich vollständiger Trajektorien und Kennzahlen identisch und als
  violette Rauten markiert. Die Achsenskalierungen der Parameterdiagramme sind gleich.
- **Geschwindigkeitsgrafik:** Neun vollständig simulierte Geschwindigkeitsgrenzen
  werden mit der GTFS-Fahrzeit verglichen. Die Grafik zeigt Fahrzeit, Referenz,
  absoluten Fehler, ursprüngliche Grenze und das in MATLAB ermittelte Optimum.
- **Sanity Checks:** `sanity_check.m` prüft jeden vollständigen Lauf unabhängig
  anhand der gespeicherten Zustände. Zusätzlich laufen die umfangreichen
  Stations-, Haltezeit-, Bremsweg- und Blockprüfungen aus Woche 1 automatisch.
- **Kein Zufall:** Zusatzhalte, Zufallsbremsen und Sperren sind in den Studien
  ausgeschaltet. Ein Lauf pro Einstellung genügt. Die Spalte `headway_std_s`
  beschreibt zeitliche Zugabstände, keine Streuung zwischen Wiederholungen.

## Wiederverwendung von Woche 1

`modell/+sbahn2` ist die lokale Weiterführung von
`../Woche 1/NaSch-SBahn/+sbahn`. Der Bewegungsalgorithmus, synchrone Updates,
Zugkörper und Blockfreigaben wurden übernommen. Die Daten werden direkt aus
dem vorhandenen Datenstand `ringbahn_2026-10-14` gelesen. Die Woche-2-Studien
verwenden ihre eigene Paketkopie. Seit 28.10.2026 kann die Geschwindigkeitsgrenze
zusätzlich im ursprünglichen `SBahn_demo.mlx` eingegeben werden; dafür wurden
auch `sbahn.defaultConfig` und `sbahn.prepare` um `cruiseSpeedKmh` ergänzt.
Die Standardgrenze bleibt 80 km/h. Die Herkunftsprüfsummen gespeicherter
Auswertungen beziehen sich auf den jeweiligen damaligen Quellstand.

Außer dem Paketnamen ändern sich sechs Dateien:

| Datei | Änderung |
| --- | --- |
| `defaultConfig.m` | `cruiseSpeedKmh`, `dataFolder`, `dwellOffsetSeconds` und `initialPhaseSearch`; Standards bleiben 80 km/h, +0 s, keine Phasensuche |
| `prepare.m` | Effektive Geschwindigkeitsgrenze und gleichmäßiger Zuschlag zum Halteprofil; Werteprüfung |
| `private/initialize.m` | Optional die kleinste gemeinsame Verschiebung der freien Zugphasen mit gültiger Körper-/Blockbelegung suchen |
| `private/loadRoute.m` | Vorhandenen Datenordner verwenden und an Route weiterreichen |
| `private/loadDwellProfile.m` | Datenordner aus Route verwenden |
| `private/loadBlocks.m` | Datenordner aus Konfiguration verwenden |

Der Modellstandard von 80 km/h wird weiterhin auf 22 m/s = 79,2 km/h
abgerundet. Kalibriert wird die **effektive Fahrgeschwindigkeit**, während
die Sicherheitsobergrenze bei 80 km/h bleibt. Das ist eine Modellannahme,
keine Messung der Fahrzeughöchstgeschwindigkeit. Ohne diese Änderung ergibt
die lokale Weiterführung dieselben Trajektorien, Ereignisse und Kennzahlen
wie Woche 1; Regressionstests prüfen beide Fahrmodelle.

Bei GTFS+6 bis GTFS+30 würden einige ursprünglich gewählte Startzustände
denselben Block belegen. Die Studien aktivieren deshalb `initialPhaseSearch`:
Die zeitlich gleichmäßigen Abstände bleiben erhalten, nur der gemeinsame
Zeitursprung wird verschoben. Für die sechs Profile ergeben sich 0, 2, 6, 11,
15 und 25 s. Zugzahl, Strecke und Blocklängen bleiben gleich. Der Standard des
Modellkerns ist weiterhin die unveränderte Initialisierung aus Woche 1.

`dwellOffsetSeconds` verlängert den **geplanten** Aufenthalt je Station.
Er ist eine deterministische Änderung des Halteprofils und kein zufälliger
Zusatzhalt; `extraWaitSteps` bleibt in den Studien null.

## Prüfungen

```matlab
addpath('modell');
testergebnisse = runtests('modell/tests');
assertSuccess(testergebnisse);
```

Die übernommenen 65 Tests decken Fahrdynamik, Stationen, Blockabschnitte und
Störungen ab. Die zusätzlichen Tests prüfen die Geschwindigkeitsvorgabe,
deren Grenzen, die Übereinstimmung mit Woche 1, GTFS-Zuschläge und die sichere
Startphasensuche. Insgesamt bestehen 71 Tests. Ergebnisse und Protokoll
stehen in `ergebnisse/matlab_tests.csv` und `ergebnisse/matlab_tests.log`.
`tools/pruefe_ergebnisse.m` prüft außerdem absichtlich verfälschte Geschwindigkeiten
und Positionen: Beide Fehler müssen von den Sanity Checks erkannt werden.
Die zusätzliche Messfensterkontrolle vergleicht drei einzelne Messstunden
im Sättigungsbereich. Außerdem werden alle 25 aktuellen Läufe und 377
Zahlenwerte gegen die Rohdaten geprüft: Detektor und Stillstand werden aus
Positionen/Halteuhren unabhängig rekonstruiert und mit Kennzahlen, CSV und
Diagrammexport verglichen. Der gemeinsame N=36-/GTFS+0-Punkt muss bitgenau
übereinstimmen. Diese Prüfungen wurden ausgeführt und bestehen.

## Zahlen direkt aus MATLAB in die Grafiken

`ergebnisse = run_sbahn2` liefert die Kurvenkoordinaten unter
`ergebnisse.plotData` zurück. Dieselbe Struktur wird als `diagrammdaten.mat`
gespeichert. `tools/erstelle_bericht.py` lädt diese numerischen Vektoren und
zeichnet sie unverändert. Die tatsächlich gezeichneten Linienkoordinaten
werden gegen die exportierten MATLAB-Vektoren geprüft; Python berechnet
keinen Durchsatz, keine Stillstandskennzahl und kein Optimum neu.

`diagrammwerte.csv` enthält die drei Parameterserien in einer gemeinsamen
Tabelle: `x`, `y_primary`, `y_reference`, `y_secondary`. Bei Geschwindigkeit
sind die Einheiten km/h und Sekunden; bei Zugzahl bzw. Haltezuschlag sind die
y-Einheiten Züge/h und s/(Zug·h). Alle Werte erzeugt MATLAB.

## Gespeicherte Auswertungsdaten

| Datei/Ordner unter `ergebnisse/` | Inhalt |
| --- | --- |
| `versuchsplan.json` | Vor der Suche definierte Vergleichsgrößen und Messkonventionen |
| `parameter.json` | Aktualisierte tatsächlich verwendete Parameter |
| `kalibrierung.csv` | Alle neun Kandidaten und Zielfunktionswerte |
| `diagrammdaten.mat` | Direkt zurückgegebene MATLAB-Zahlen für alle Kurven und das Raum-Zeit-Diagramm |
| `diagrammwerte.csv` | Numerische Koordinaten der drei Parameterserien |
| `diagrammwerte_pruefung.csv` | Unabhängiger Abgleich mit den vollständigen Simulationsdaten |
| `laufverzeichnis.csv` | Verbindliche Liste der 25 aktuellen Läufe |
| `referenzvergleich.csv` | Vorher/Nachher und Fehlermaße |
| `abschnittsvalidierung.csv` | Alle 27 Abschnitte vor und nach der Kalibrierung |
| `zugzahlstudie.csv`, `haltezeitstudie.csv` | Parameter, Durchsatz, Wartezeit und Zugabstände |
| `sanity_checks.csv` | Zwölf Prüfgruppen für jeden der 25 Auswertungsläufe |
| `messfensterkontrolle.csv` | Drei einzelne Messstunden für N=32, N=36 und N=40 |
| `laeufe/*.mat` | Vollständige Trajektorien, Konfiguration, Ereignisse, Kennzahlen und Prüfungen |
| `auswertung.mat`, `raumzeit.mat` | Gemeinsame Auswertung und Daten für das Raum-Zeit-Diagramm |
| `diagramme/` | Vier Diagramme einschließlich Geschwindigkeitskalibrierung, jeweils PNG und PDF |
| `archiv/vor_anpassung/` | Frühere einheitliche Haltezeitläufe und Zugzahlen unter 12; nicht Teil der aktuellen Auswertung |
| `quellcode_herkunft.json` | SHA-256 von übernommenem und fortgeführtem Code |

`run_sbahn2.m` kommentiert die Zeit- und Messkonventionen. Insbesondere wird
der unbekannte Endpunkthalt des GTFS-Beispieltrips nicht als Nullhalt
interpretiert: Zum Vergleich mit den 3558 Referenzsekunden wird der 42-s-Halt
an Station 1 vom vollen Modellumlauf abgezogen. Quellen und Lizenzangaben
stehen in der Ausarbeitung und im Daten-README aus Woche 1.

Codex unterstützte die lokale Weiterführung, Versuchsplanung, Prüfungen,
Auswertung und Text. Alle angegebenen Zahlen wurden tatsächlich in MATLAB
berechnet. Die dreiseitige PDF enthält die geforderte kurze Dokumentation.
