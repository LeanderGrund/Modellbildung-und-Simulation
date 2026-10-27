%% S-Bahn-Ring: Aufgaben 1 und 2 aus SBahn2.pdf
% MATLAB R2026a. Auf "Ausführen" klicken oder dieses Skript aufrufen.
% Der Modellkern ist aus ../Woche 1/NaSch-SBahn abgeleitet.
% Rechenzeit: mehrere Minuten; keine Animation in der Parameterstudie.
projekt = fileparts(mfilename('fullpath'));
addpath(projekt,fullfile(projekt,'modell'));
ausgabeOrdner = fullfile(projekt,'ergebnisse');
if ~isfolder(ausgabeOrdner), mkdir(ausgabeOrdner); end

%% Übernommene Modelltests und Regression gegen Woche 1
testergebnisse = runtests(fullfile(projekt,'modell','tests'));
writetable(table(testergebnisse),fullfile(ausgabeOrdner,'matlab_tests.csv'));
save(fullfile(ausgabeOrdner,'matlab_tests.mat'),'testergebnisse');
assertSuccess(testergebnisse);

%% Kalibrierung, Parameterstudien und Sanity Checks
ergebnisse = run_sbahn2;
addpath(fullfile(projekt,'tools'));
pruefe_ergebnisse;

%% Geforderte Diagramme und dreiseitige Ausarbeitung erzeugen
% Benötigt Python mit numpy, scipy und matplotlib.
% Alternativ im Terminal: py tools/erstelle_bericht.py
berichtSkript = fullfile(projekt,'tools','erstelle_bericht.py');
[status,ausgabe] = system(sprintf('py "%s"',berichtSkript));
disp(ausgabe);
assert(status == 0,'SBahn2:Report','Berichtserzeugung fehlgeschlagen.');
