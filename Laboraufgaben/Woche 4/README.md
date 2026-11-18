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

## Einzelne Demos zu Aufgabe 1

Diese Aufrufe werden direkt im Hauptordner `Woche 4` ausgeführt:

```matlab
a = demo_aufgabe1("a");         % 1a: Zufallsstart, N0=0.2, Seed 2101
b = demo_aufgabe1("b");         % 1b: Gleiter ohne Störung, Seed 2102
c = demo_aufgabe1("c");         % 1c: Gleiterstart, pDeath=0.001, Seed 2103
d = demo_aufgabe1("d");         % 1d: leeres Feld, pBirth=0.001, Seed 2104
beide = demo_aufgabe1("d_beide"); % 1d: Geburt und Sterben je 0.001, Seed 2105
```

Jeder Aufruf simuliert standardmäßig 2000 Schritte auf einem periodischen Feld mit 100 × 100 Zellen. Ein Fenster zeigt das Zellfeld und die zugehörige Zellzahl über der Zeit. Die Animation läuft mit höchstens 30 Bildern pro Sekunde und endet auch beim Schließen des Fensters. Die Ergebnisse werden zurückgegeben; vorhandene Ergebnisdateien werden durch die Demos nicht ersetzt.

In `demos_aufgabe1.m` stehen dieselben Aufrufe als einzeln ausführbare Editorabschnitte. Für einen gezielten Versuch nur den jeweiligen Abschnitt ausführen (Strg+Enter).

```matlab
c = demo_aufgabe1("c",fps=60);            % schnellere Animation
c = demo_aufgabe1("c",steps=500);         % nur 500 Schritte
c = demo_aufgabe1("c",seed=42);           % anderer Zufallsverlauf
c = demo_aufgabe1("c",plot=false);        % vollständiger Lauf ohne Animation
c.history                               % t, living, changed
c.peakPopulation                        % Standardlauf 1c: 56
c.peakStep                              % Standardlauf 1c: 218
```

Mit `siz=[50 50]` lässt sich auch die Feldgröße ändern. Änderungen an Seed oder Feldgröße verändern bei den stochastischen Versuchen den konkreten Verlauf. Die Standardkonfigurationen entsprechen `gol/aufgabe1.m` und der Ausarbeitung. Bei 1c verändert das zusätzliche Sterben die Gleiterstruktur; die normale Life-Regel kann anschließend vorübergehendes Wachstum erzeugen. Bei 1d ist ausschließlich spontane Geburt aktiv, bei `d_beide` zusätzliches Sterben. Das feste Gleitermuster und die mittige Platzierung stehen in `gol/myInit.m`.

## Einzelne Demos zu Aufgabe 2

Im Hauptordner `Woche 4` können die Abschnitte in `demos_aufgabe2.m` einzeln mit Strg+Enter gestartet werden. Die Aufrufe sind auch direkt im Command Window möglich:

```matlab
a = demo_aufgabe2("a");                       % Kollision und Streaming
b1 = demo_aufgabe2("b",scenario="leer");        % leeres Feld
b2 = demo_aufgabe2("b",scenario="voll");        % alle vier Kanäle voll
b3 = demo_aufgabe2("b",scenario="rand",N=1);    % Rechteck am linken Rand
b4 = demo_aufgabe2("b",scenario="mitte");       % Rechteck in der Mitte
b5 = demo_aufgabe2("b",scenario="donut");       % Kreisring in der Mitte
c = demo_aufgabe2("c");                       % echte Laufzeitmessungen
d1 = demo_aufgabe2("d",model="i");             % gegebener Block-CA
d2 = demo_aufgabe2("d",model="ii");            % diskretes Quadrat
d3 = demo_aufgabe2("d",model="iii");           % kontinuierliches Quadrat
d4 = demo_aufgabe2("d",model="iv");            % gleichverteilte Kreisscheibe
```

**2a:** Ein tatsächlicher Schritt von `myUpdate` wird mit der erwarteten Kollision und Versetzung verglichen. Drei Bilder zeigen die Phasen; `occupation=[1 1 0 0]` wählt andere Anfangskanäle und `seed=2202` einen anderen Zufallsverlauf.

**2b:** Standardmäßig werden 1000 Schritte auf 200 × 200 Orten mit periodischen Rändern simuliert. Die Bilder zeigen die Belegung pro Ort, die Mittelwerte über 10 × 10 Orte und die Gesamtteilchenzahl. Das leere Feld und das in allen Kanälen volle Feld müssen unverändert bleiben. Bei Rechteck und Donut bleibt die Teilchenzahl ebenfalls konstant. Der Ring hat Innenradius 0,1 und Außenradius 0,2 der kürzeren Gitterseite; er verbreitert sich nach innen und außen. Im linken Randrechteck sichert `N=1` einen sichtbaren Übertritt zum rechten Rand bereits nach einem Schritt. Geprüft wird `b3.checks.periodicBoundaryObserved`; die Zeitreihe steht in `b3.history`. `N` bezeichnet die Belegungswahrscheinlichkeit je Kanal innerhalb des Startmusters und wird bei Leer-/Vollfeld nicht verwendet.

```matlab
r = demo_aufgabe2("b",scenario="donut",steps=2000,dt=10,fps=60);
r = demo_aufgabe2("b",scenario="rand",N=1,steps=20,dt=1,plot=false);
```

`steps` bezeichnet die Gesamtzahl der Zeitschritte, `dt` die Schritte pro Bild beziehungsweise Messpunkt. Die Feldgröße (`siz`), Boxgröße (`cg`), Belegung (`N`), Geschwindigkeit (`fps`) und der Seed (`seed`, Standard 2200) können geändert werden. Feldgrößen werden wie in der Vorlage auf ganze Boxen aufgerundet. Fensterschließen beendet die Feldanimation. In der Mitte liegt das schon in der Ausarbeitung verwendete Rechteck; für den Randversuch wird dieses Muster an den linken Rand verschoben.

**2c:** Gemessen wird `myUpdate`, ohne Initialisierung oder Grafik, mit Aufwärmläufen und fünf Wiederholungen. Variiert werden die Seitenlängen `[50 100 200 400 800]` bei 100 Schritten und die Schrittzahlen `[10 30 100 300 1000]` auf 200 × 200 Orten. Tabellen, Einzelmessungen und Fitexponenten werden zurückgegeben. Eigene Messreihen sind beispielsweise mit `sides=[50 100 200]`, `stepCounts=[10 30 100]`, `fixedSteps=100`, `fixedSize=[200 200]` und `repeats=3` möglich. Kleine Messreihen liefern wegen fester Kosten und Messrauschen unter Umständen stark schwankende Exponenten.

**2d:** Jeder Aufruf berechnet standardmäßig 20.000 unabhängige Wege mit 1000 Schritten in unbeschränkten Koordinaten. Die Grafik zeigt einen alle zehn Schritte abgetasteten Beispielweg, die Endpunkte von bis zu 2000 Wegen, die mittlere quadratische Entfernung gegen ihre Theorie und die Verteilung der ersten Schritte. Beim CA wird die exakte Einteilchen-Richtungsregel verwendet. Die mittleren quadratischen Entfernungen sind theoretisch `n`, `4*n/3`, `2*n/3` und `n/2`. In der Kreisscheibe wird der Radius als `sqrt(rand)` gezogen, damit die Fläche gleichverteilt ist.

```matlab
r = demo_aufgabe2("d",model="iv",seed=42,sampleEvery=5,plot=false);
r.sampledPositions         % t, x, y des abgetasteten Beispielwegs
r.history                  % gemessene und theoretische MSD für alle Schritte
r.checks                   % Schrittregeln und statistischer MSD-Vergleich
```

Die vier separaten Walk-Demos verwenden Seeds 2400 bis 2403; die Verläufe sind reproduzierbar, aber nicht für alle Modelle identisch mit den Einzelwegen des gemeinsamen Ausarbeitungslaufs. Die Optionen `steps`, `ensemble`, `sampleEvery`, `seed` und `tolerance` sind veränderbar. Der statistische Vergleich verwendet standardmäßig 4 % relative Toleranz; bei kleinen Ensembles können trotz korrekter Regeln größere Abweichungen auftreten. Die Schrittbedingungen werden separat geprüft. Alle Aufrufe unterstützen `plot=false`, geben ihre Daten zurück und überschreiben keine Ergebnisdateien.

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
