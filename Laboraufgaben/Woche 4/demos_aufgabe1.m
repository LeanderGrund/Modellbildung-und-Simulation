% DEMOS_AUFGABE1 Im MATLAB-Editor einzelne Abschnitte ausfuehren (Strg+Enter).
% Jeder Aufruf oeffnet eine Animation und gibt die vollstaendige Zeitreihe zurueck.
% Fenster schliessen beendet die jeweilige Animation vorzeitig.
% Standard: 100 x 100 Zellen, 2000 Schritte, 30 Bilder/s, periodische Raender.

%% Aufgabe 1a: Zufallsstart mit 20 Prozent lebenden Zellen, ohne Stoerung
a = demo_aufgabe1("a");

%% Aufgabe 1b: Gleiter mit fuenf Zellen, ohne zusaetzliches Sterben/Geburt
b = demo_aufgabe1("b");

%% Aufgabe 1c: Gleiterstart, zusaetzliches Sterben mit pDeath = 0.001
% Seed 2103: erstes Sterben bei t=153, Maximum 56 bei t=218, leer ab t=483.
c = demo_aufgabe1("c");

%% Aufgabe 1d: Leeres Feld, spontane Geburt mit pBirth = 0.001
d = demo_aufgabe1("d");

%% Aufgabe 1d, kombinierte Variante: Geburt und Sterben jeweils mit p = 0.001
d_beide = demo_aufgabe1("d_beide");

%% Vergleich fuer 1c: Gleiche Regeln, anderer Seed und doppelte Geschwindigkeit
% Der konkrete Verlauf aendert sich; die Wahrscheinlichkeiten bleiben gleich.
c_anderer_seed = demo_aufgabe1("c",seed=42,fps=60);

%% Schneller Vergleich ohne Animation: dieselben fuenf Versuche wie im Bericht
teile = ["a","b","c","d","d_beide"];
vergleich = cell(size(teile));
for k = 1:numel(teile)
    vergleich{k} = demo_aufgabe1(teile(k),plot=false);
end
% Beispiel: gesamte Zeitreihe des dritten Versuchs anzeigen.
disp(vergleich{3}.history);
