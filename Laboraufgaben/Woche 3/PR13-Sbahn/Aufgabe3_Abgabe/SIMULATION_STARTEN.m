%% S-Bahn: genau einen Simulationslauf manuell konfigurieren und starten
% ZIP vollständig entpacken, diese Datei öffnen, Parameter ändern und ausführen.
% Vergleich: beta = 0 ist das Basismodell; beta = 0.20 aktiviert die Zusatzregel.

%% Veränderliche Parameter
zugzahl = 28;
beta = 0.20;                       % [1/s], Antizipation auf langsameren Vorgänger
antizipationAktiv = true;          % alternativ vollständig ausschalten
stoerwahrscheinlichkeit = 0.20;   % jeweils für Blockbremsung und Stationszusatz
zusaetzlicheHaltezeit_s = 0;       % fester Zuschlag je Stationshalt
maximalerZufallshalt_s = 120;      % Zufallszusatz gleichverteilt von 0 bis hier
maximalgeschwindigkeit_kmh = 80;   % bei 1 m / 1 s effektiv 79,2 km/h
simulationsdauer_min = 240;
einschwingzeit_min = 60;           % nur für die nachträgliche Durchsatzzählung
zufallsstartwert = 42;
animationAnzeigen = false;

%% Lokales Modell laden; keine benachbarten Wochenordner erforderlich
projektordner = fileparts(mfilename('fullpath'));
addpath(fullfile(projektordner,'modell'));
c = sbahn3x.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.displayMode = "Geografischer Streckenverlauf";
c.motionModel = "Beschleunigen und Bremsen";
c.blockMode = "OSM-Signalabschnitte";
c.blockLengthMeters = 500;       % nur für gleichmäßige Blöcke; bei OSM unbenutzt
c.dwellMode = "GTFS-Stationshalte";
c.initializationMode = "Ruhende Blockaufstellung";
c.initialPhaseSearch = false;
c.trainCount = zugzahl;
c.anticipationEnabled = antizipationAktiv;
c.anticipationBeta = beta;
c.anticipationMaxBlocks = 2;      % bezogen auf das Zugende des Vorgängers
c.randomBrakeEnabled = true;
c.randomBrakeProbability = stoerwahrscheinlichkeit;
c.randomStopEnabled = true;
c.randomStopProbability = stoerwahrscheinlichkeit;
c.randomStopMinSeconds = 0;
c.randomStopMaxSeconds = maximalerZufallshalt_s;
c.dwellOffsetSeconds = zusaetzlicheHaltezeit_s;
c.cruiseSpeedKmh = maximalgeschwindigkeit_kmh;
c.durationMinutes = simulationsdauer_min;
c.randomSeed = zufallsstartwert;
c.animate = animationAnzeigen;
c.framePauseSeconds = 0.05;
c.displayEvery = 10;
assert(einschwingzeit_min >= 0 && einschwingzeit_min < simulationsdauer_min, ...
    'Die Einschwingzeit muss kleiner als die Simulationsdauer sein.');

%% Ein Lauf, keine automatische Parameterreihe
[G,p,bericht] = sbahn3x.simulate(c);
assert(bericht.checksPassed);
messfenster = G.timeSeconds(1:end-1) >= einschwingzeit_min*60 & ...
    G.timeSeconds(1:end-1) < simulationsdauer_min*60;
bewegung = mod(diff(G.position),p.cellCount) > 0;
abfahrten = G.position(1:end-1,:) == p.route.stationCells(1) & bewegung;
anzahlAbfahrten = sum(abfahrten(messfenster,:),'all');
messdauer_h = (simulationsdauer_min-einschwingzeit_min)/60;
durchsatz = anzahlAbfahrten/messdauer_h;
fprintf('N=%d, beta=%.2f 1/s, p=%.2f, Zusatzhalt=%g s\n', ...
    zugzahl,beta,stoerwahrscheinlichkeit,zusaetzlicheHaltezeit_s);
fprintf('Station 1: %d Abfahrten in %.2f h; Durchsatz %.3f Zuege/h.\n', ...
    anzahlAbfahrten,messdauer_h,durchsatz);

%% Grafiken anzeigen und diesen einzelnen Lauf speichern
zeitstempel = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
ausgabeordner = fullfile(projektordner,'ausgaben',zeitstempel);
mkdir(ausgabeordner);
save(fullfile(ausgabeordner,'simulation.mat'),'G','p','bericht','c', ...
    'einschwingzeit_min','anzahlAbfahrten','messdauer_h','durchsatz','-v7');
kennzahlen = table(zugzahl,beta,stoerwahrscheinlichkeit,zusaetzlicheHaltezeit_s, ...
    einschwingzeit_min,simulationsdauer_min,anzahlAbfahrten,messdauer_h,durchsatz);
writetable(kennzahlen,fullfile(ausgabeordner,'kennzahlen.csv'));
figuren = [sbahn3x.plotResults(G,p),sbahn3x.plotMeanSpeed(G,p), ...
    sbahn3x.plotDynamics(G,p),sbahn3x.plotSnapshot(p)];
namen = ["weg_zeit","mittlere_geschwindigkeit","fahrbewegung_zug1","streckenansicht"];
for k = 1:numel(figuren)
    sbahn3x.styleFigure(figuren(k));
    exportgraphics(figuren(k),fullfile(ausgabeordner,namen(k)+".png"),'Resolution',180);
    savefig(figuren(k),fullfile(ausgabeordner,namen(k)+".fig"));
end
fprintf('Simulation und Grafiken gespeichert in: %s\n',ausgabeordner);
