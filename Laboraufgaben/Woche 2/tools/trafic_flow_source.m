%% S-Bahn S41: Einzellauf und Verkehrsstrom
% Einstellungen ändern und anschließend das vollständige Live Script mit
% „Run“ ausführen. Die Checkbox „Verkehrsstromuntersuchung“ wählt die Betriebsart.
% Der Einzellauf zeigt Animation, Raum-Zeit-Diagramm, Fahrdynamik, Netzmittel,
% Kennzahlen, Stationstabelle, GTFS-Vergleich und Störungsauswertung.
% Die Untersuchung erzeugt ausschließlich eine Heatmap, einen Lauf je Kombination.
%% Parameterübersicht
% PARAMETERTABELLE
%% Betriebsart und gemeinsame Eingaben
% Messdauer und Einschwingzeit ergeben zusammen die Simulationsdauer.
% Der Durchsatz zählt Abfahrten an Station 1 im Messfenster nach dem Einschwingen.

verkehrsstromuntersuchung = false;
anzahlZuege = 12;
einschwingzeitMinuten = 60;
messdauerMinuten = 120;
wahrscheinlichkeitP = 0.05;
zeitspanneSekunden = 120;
%% Langsames Abbremsen
% Die Checkbox aktiviert die zusätzliche Anpassung an einen langsameren
% Vorgänger: a = beta * (v_Vorgänger - v_Zug), beta in 1/s.
% Pro Sekunde wird a auf mindestens -1 m/s² begrenzt. Bruchteile einer
% Geschwindigkeitsstufe werden aufsummiert. Bei gleich schnellem/schnellerem
% Vorgänger gilt die reguläre Beschleunigung bis maximal +1 m/s².
% Stationen, Bremsreserve und belegte Blöcke begrenzen die Bewegung zusätzlich.
% Bei nur einem Zug ist die Antizipation ohne Wirkung.

langsamesAbbremsen = false;
beta = 0.25;
%% Zusätzliche Wartezeit
% Bei aktivierter Checkbox wird der feste Eingabewert auf jeden GTFS-Halt
% addiert. Zufällige Zusatzhalte kommen unabhängig davon hinzu.

zusaetzlicheWartezeit = false;
wartezeitzuschlagSekunden = 10;
%% Untersuchungsbereiche
% Diese Eingaben gelten nur bei aktivierter Verkehrsstromuntersuchung.
% Je Achse: Minimum, Maximum, Schrittweite. Die obere Grenze wird eingeschlossen;
% gegebenenfalls ist der letzte Schritt kürzer. Geschwindigkeitseingaben werden
% auf ganze m/s abgerundet. Gleiche Rasterstufen werden nur einmal simuliert.
% Die Heatmap zeigt die tatsächlich verwendeten Grenzen in km/h.

geschwindigkeitMinimumKmh = 36;
geschwindigkeitMaximumKmh = 80;
geschwindigkeitSchrittKmh = 7.2;
zugzahlMinimum = 8;
zugzahlMaximum = 24;
zugzahlSchritt = 4;
%% Störungsregeln und Modellannahmen
% Zufallsbremsung: Bei jeder tatsächlichen Blockeinfahrt wird einmal mit p
% entschieden. Bei einem Treffer ist das Bremsziel floor(v_Eintritt/2).
% Die Bremsung beginnt im nächsten Zeitschritt mit -1 m/s²; danach wird ohne
% zusätzliche Wartezeit wieder beschleunigt, soweit die übrigen Regeln es erlauben.
% Weitere Treffer während einer Bremsung können das Bremsziel weiter verringern.
% Alle überfahrenen Blockgrenzen werden berücksichtigt, auch kurze Blöcke.
%
% Stationszusatzhalt: Bei jeder Ankunft wird unabhängig mit derselben
% Wahrscheinlichkeit p entschieden. Zusatzdauer: diskrete Gleichverteilung
% U{0,...,Zeitspanne} Sekunden, zusätzlich zum GTFS-Halt und festen Zuschlag.
% p=0 schaltet beide Zufallswirkungen aus. Ein bereits beim Start laufender
% Stationshalt erhält keinen nachträglichen Zufallszusatz.
%
% Der Zufallsstartwert ist fest 42. Identische Eingaben reproduzieren den Lauf.
% Das Raster beträgt 1 m und 1 s, die Zuglänge 148 m. Eine Fahrtrichtung: S41.
% OSM-Signalabschnitte sind Modellgrenzen; der Zielblockabstand 500 m wirkt dort
% nicht. Die geografische Darstellung zeigt den lokalen Verlauf ohne Hintergrundkarte.
%% Berechnen und speichern
% Run startet die gewählte Betriebsart. Nach Abschluss werden alle zugehörigen
% Grafiken als PNG und bearbeitbare FIG-Dateien in einem eigenen Zeitstempelordner
% unter ergebnisse/trafic_flow/ gespeichert. Eingaben, Rohdaten und Kennzahlen
% werden ebenfalls gespeichert. Ungültige Untersuchungspunkte sind grau/NaN
% und werden mit Fehlergrund dokumentiert; sie zählen nicht als Nulldurchsatz.

projektordner = fileparts(mfilename('fullpath'));
if ~isfile(fullfile(projektordner,'run_trafic_flow.m'))
    projektordner = fileparts(which('trafic_flow.mlx'));
end
addpath(projektordner);
einstellungen = trafic_flow_defaults;
einstellungen.study = verkehrsstromuntersuchung;
einstellungen.trainCount = anzahlZuege;
einstellungen.warmupMinutes = einschwingzeitMinuten;
einstellungen.measurementMinutes = messdauerMinuten;
einstellungen.probability = wahrscheinlichkeitP;
einstellungen.randomHoldMaxSeconds = zeitspanneSekunden;
einstellungen.anticipationEnabled = langsamesAbbremsen;
einstellungen.beta = beta;
einstellungen.extraWaitEnabled = zusaetzlicheWartezeit;
einstellungen.extraWaitSeconds = wartezeitzuschlagSekunden;
einstellungen.speedMinimumKmh = geschwindigkeitMinimumKmh;
einstellungen.speedMaximumKmh = geschwindigkeitMaximumKmh;
einstellungen.speedStepKmh = geschwindigkeitSchrittKmh;
einstellungen.trainMinimum = zugzahlMinimum;
einstellungen.trainMaximum = zugzahlMaximum;
einstellungen.trainStep = zugzahlSchritt;
ergebnis = run_trafic_flow(einstellungen);
if ~verkehrsstromuntersuchung
    disp("Grafiken und Daten gespeichert unter: " + ergebnis.outputFolder)
end
