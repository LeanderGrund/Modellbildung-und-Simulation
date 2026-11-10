# Woche 3: Antizipation über höchstens zwei Blöcke

Untersuchungen bei p = 0,2, N = 28 und 80 km/h Vorgabe (79,2 km/h im Raster).
Die Beta-Regel greift ausschließlich, wenn das Zugende des räumlich nächsten
Vorgängers im ersten oder zweiten OSM-Block vor der eigenen Zugspitze liegt.
Das Zugende ist die hinterste vom Vorgänger belegte Rasterzelle. Der
Ringschluss wird dabei berücksichtigt. Es werden die tatsächlichen
OSM-Abschnitte gezählt; ihre Länge ist unterschiedlich.

Die Bremsregel bleibt `a = beta * (v_Vorgänger - v_Zug)`, begrenzt auf
höchstens 1 m/s² Verzögerung. Bruchteile werden im 1-m-/1-s-Raster
aufsummiert. Außerhalb des Bereichs wird der Bruchteil zurückgesetzt und
die reguläre Beschleunigung gilt. Die Sicherheitsregeln für Zugkörper,
Blockbelegung, Stationen und Bremswege gelten weiterhin unabhängig davon.

## Messreihen

| Reihe | Variable | Feste Parameter |
| --- | --- | --- |
| Beta | 0:0,05:0,50 1/s | p = 0,2; N = 28; fester Stationszuschlag = 0 s |

β = 0 bewirkt keine zusätzliche Bremsung und keine Beschleunigungssperre.
Es ist die Referenz ohne zusätzliche Antizipationswirkung. Die Untersuchung
des festen Haltezeitzuschlags wird auf Wunsch vorerst übersprungen.

Jeweils 60 min Einschwingen und 180 min Messung, Zufallsstartwert 42.
Beide unabhängigen Störungsarten verwenden p = 0,2. Der zufällige
Stationszusatz ist bei einem Treffer gleichverteilt zwischen 0 und
120 ganzen Sekunden und kommt zusätzlich zum festen Stationszuschlag hinzu.
Ein Lauf je Konfiguration, ohne Wiederholungen über mehrere Zufallsstartwerte:
elf Kurvenpunkte aus elf Simulationsläufen.

Das Weg-Zeit-Diagramm zeigt alle 28 Züge im Messfenster von 60 bis 240 min,
bei beta = 0,20 und 0 s festem Stationszuschlag. Am Ringschluss werden Linien
unterbrochen. Es verwendet die gespeicherten Trajektorien der zugehörigen
Durchsatzmessung. Die Position bezeichnet die Zugspitze; der Antizipationsbereich
bezieht sich dagegen auf das Zugende des Vorgängers.

## Ausführen

In MATLAB aus diesem Ordner:

```matlab
ausgabe = run_woche3_untersuchungen;
disp(ausgabe)
```

Danach im Terminal:

```powershell
py bericht_woche3.py <Ausgabeordner>
```

Die vierseitige PDF, die beiden Diagramme, Wertetabelle, Parameter und Rohdaten liegen im
ausgegebenen Unterordner von `ergebnisse/`. Ein bestehender Ordner kann als
Argument an `run_woche3_untersuchungen` übergeben werden; vor der Übernahme
erfolgreicher Läufe wird die vollständige Konfiguration geprüft.

`modell/+sbahn3/` ist die für Woche 3 gesicherte Modellkopie. Die zugrunde
liegenden Woche-2-Dateien werden nicht verändert. Die benötigten Daten sind
unter `daten/` mit Herkunftsangaben enthalten. MATLAB R2026a wird verwendet;
die PDF-Erstellung benötigt Python mit NumPy, SciPy und Matplotlib.

Der Bericht dokumentiert Parameter und Ergebnisse ohne Ergebnisinterpretation.
