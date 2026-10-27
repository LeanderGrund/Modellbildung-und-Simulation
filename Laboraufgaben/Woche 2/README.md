# S-Bahn-Ring – Woche 2

Die Aufgaben aus `SBahn2.pdf` sind vollständig in MATLAB bearbeitet. Die
dreiseitige Ausarbeitung steht in
[`ergebnisse/Ausarbeitung_SBahn2.pdf`](ergebnisse/Ausarbeitung_SBahn2.pdf).
Eine bearbeitbare Textfassung und alle Diagramme liegen daneben.

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
- **Aufgabe 2:** Zehn Zugzahlen bei unverändertem GTFS-Halteprofil; acht
  einheitliche Haltezeiten bei festem N=36. Jeweils eine Stunde Einschwingen
  und drei Stunden Messung. Durchsatz am festen Abfahrtsdetektor Station 1.
  Rückstaus sind im Raum-Zeit-Diagramm gesondert markiert.
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
dem vorhandenen Datenstand `ringbahn_2026-10-14` gelesen. Das ursprüngliche
Projekt wurde nicht verändert.

Außer dem Paketnamen ändern sich fünf Dateien:

| Datei | Änderung |
| --- | --- |
| `defaultConfig.m` | `cruiseSpeedKmh` und `dataFolder`; Standard bleibt 80 km/h |
| `prepare.m` | Effektive Geschwindigkeitsgrenze statt fester 80-km/h-Vorgabe; Werteprüfung |
| `private/loadRoute.m` | Vorhandenen Datenordner verwenden und an Route weiterreichen |
| `private/loadDwellProfile.m` | Datenordner aus Route verwenden |
| `private/loadBlocks.m` | Datenordner aus Konfiguration verwenden |

Der Modellstandard von 80 km/h wird weiterhin auf 22 m/s = 79,2 km/h
abgerundet. Kalibriert wird die **effektive Fahrgeschwindigkeit**, während
die Sicherheitsobergrenze bei 80 km/h bleibt. Das ist eine Modellannahme,
keine Messung der Fahrzeughöchstgeschwindigkeit. Ohne diese Änderung ergibt
die lokale Weiterführung dieselben Trajektorien, Ereignisse und Kennzahlen
wie Woche 1; Regressionstests prüfen beide Fahrmodelle.

## Prüfungen

```matlab
addpath('modell');
testergebnisse = runtests('modell/tests');
assertSuccess(testergebnisse);
```

Die übernommenen 65 Tests decken Fahrdynamik, Stationen, Blockabschnitte und
Störungen ab. Die zusätzlichen Tests prüfen die Geschwindigkeitsvorgabe,
deren Grenzen und die Übereinstimmung mit Woche 1. Ergebnisse und Protokoll
stehen in `ergebnisse/matlab_tests.csv` und `ergebnisse/matlab_tests.log`.
`tools/pruefe_ergebnisse.m` prüft außerdem absichtlich verfälschte Geschwindigkeiten
und Positionen: Beide Fehler müssen von den Sanity Checks erkannt werden.
Die zusätzliche Messfensterkontrolle vergleicht drei einzelne Messstunden
im Sättigungsbereich. Beide Prüfungen wurden ausgeführt und bestehen.

## Gespeicherte Auswertungsdaten

| Datei/Ordner unter `ergebnisse/` | Inhalt |
| --- | --- |
| `versuchsplan.json` | Vor der Suche definierte Vergleichsgrößen und Messkonventionen |
| `parameter.json` | Aktualisierte tatsächlich verwendete Parameter |
| `kalibrierung.csv` | Alle neun Kandidaten und Zielfunktionswerte |
| `referenzvergleich.csv` | Vorher/Nachher und Fehlermaße |
| `abschnittsvalidierung.csv` | Alle 27 Abschnitte vor und nach der Kalibrierung |
| `zugzahlstudie.csv`, `haltezeitstudie.csv` | Parameter, Durchsatz, Wartezeit und Zugabstände |
| `sanity_checks.csv` | Zwölf Prüfgruppen für jeden der 20 Auswertungsläufe |
| `messfensterkontrolle.csv` | Drei einzelne Messstunden für N=32, N=36 und N=40 |
| `laeufe/*.mat` | Vollständige Trajektorien, Konfiguration, Ereignisse, Kennzahlen und Prüfungen |
| `auswertung.mat`, `raumzeit.mat` | Gemeinsame Auswertung und Daten für das Raum-Zeit-Diagramm |
| `diagramme/` | Die drei geforderten Diagramme als PNG und PDF |
| `quellcode_herkunft.json` | SHA-256 von übernommenem und fortgeführtem Code |

`run_sbahn2.m` kommentiert die Zeit- und Messkonventionen. Insbesondere wird
der unbekannte Endpunkthalt des GTFS-Beispieltrips nicht als Nullhalt
interpretiert: Zum Vergleich mit den 3558 Referenzsekunden wird der 42-s-Halt
an Station 1 vom vollen Modellumlauf abgezogen. Quellen und Lizenzangaben
stehen in der Ausarbeitung und im Daten-README aus Woche 1.

Codex unterstützte die lokale Weiterführung, Versuchsplanung, Prüfungen,
Auswertung und Text. Alle angegebenen Zahlen wurden tatsächlich in MATLAB
berechnet. Die dreiseitige PDF enthält die geforderte kurze Dokumentation.
