# Woche 4: Diffusions-Blockautomat

## Ergebnisse reproduzieren

MATLAB R2026a im Ordner `Woche 4` öffnen und ausführen:

```matlab
results = run_diffusion1;
```

Der Aufruf führt 15 Regeltests, die Life-Versuche, die Diffusionssimulation, echte Laufzeitmessungen und vier Random-Walk-Ensembles mit jeweils 20.000 Wegen aus. Der zusätzliche MSD-Vergleich muss bei allen vier Modellen die vorgegebene Toleranz erfüllen. Daten und Diagramme unter `ergebnisse/` werden dabei ersetzt. Die Berechnung benötigt keine zusätzlichen MATLAB-Toolboxen.

Nur die Regeltests starten:

```matlab
pruefe_diffusion1
```

Animationen: im Unterordner `gol` mit `demo(30)`, im Unterordner `diff-2d` mit `demo`. Beide Modellordner enthalten gleichnamige Funktionen und sollten nicht gemeinsam über `genpath` zum MATLAB-Pfad hinzugefügt werden. Die Versuche 1a bis 1d werden vollständig vom Hauptaufruf ausgeführt.

## Ausarbeitung

- `Diffusion1_Loesung.md`: Erklärung, Annahmen, Formeln und Interpretation aller Teilaufgaben.
- `output/pdf/Diffusion1_Loesung.pdf`: gesetzte Fassung mit Diagrammen.
- `ergebnisse/pruefbericht.json`: Testmeldungen und Rechner-/Versionsangaben des geprüften Laufs.
- `ergebnisse/diffusion1_ergebnisse.mat`: Ergebnisse des vollständigen MATLAB-Laufs.
- `ergebnisse/`: CSV-Tabellen, JSON-Zusammenfassungen und PNG-Diagramme.

Die mitgelieferten Laufzeiten wurden am 18. November 2026 auf einem Mac mit Apple Silicon gemessen. Laufzeitmessungen hängen vom Rechner und der aktuellen Last ab. Bei einem neuen Lauf müssen Tabellen und Interpretation des Lösungstexts mit den neuen Ergebnissen abgeglichen werden.

PDF nach Änderungen am Text neu erstellen (im Ordner `Woche 4`):

```sh
python3 -m venv .venv-pdf
source .venv-pdf/bin/activate
pip install -r requirements-pdf.txt
python3 erstelle_pdf.py
```

Für die Weitergabe genügen die beiden Modellordner, die beiden MATLAB-Dateien im Hauptordner, das Aufgabenblatt, der Lösungstext, die PDF und die Ergebnisdateien. Eine virtuelle Python-Umgebung muss nicht mitgegeben werden.
