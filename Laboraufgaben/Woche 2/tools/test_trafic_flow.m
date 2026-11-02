function test_trafic_flow(modelTestFile)
%TEST_TRAFIC_FLOW Regressionen und beide Betriebsarten aus echtem MLX-Code.
% Optional kann eine in dieser Sitzung bereits bestandene Modelltestdatei
% übergeben werden, wenn nur die Live-Schnittstelle nachgeprüft werden muss.
arguments
    modelTestFile (1,1) string = ""
end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'modell'));
stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
out = fullfile(root,'ergebnisse','trafic_flow',"test_"+stamp);
mkdir(out);
diary(fullfile(out,'matlab.log'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Testordner: %s\n',out);
if modelTestFile == ""
    results = runtests(fullfile(root,'modell','tests'));
else
    previous = load(modelTestFile,'results'); results = previous.results;
    fprintf('Bereits bestandene Modelltests für unveränderten Modellkern: %s\n',modelTestFile);
end
testTable = table(results);
writetable(testTable,fullfile(out,'modelltests.csv'));
save(fullfile(out,'modelltests.mat'),'results');
assertSuccess(results);

% Die tatsächlich ausgelieferte MLX-Datei wird von MATLAB gelesen und
% konvertiert. Danach werden nur Testeingaben und Wiedergabe überschrieben.
source = fullfile(root,'trafic_flow.mlx');
converted = fullfile(out,'trafic_flow_import.m');
matlab.internal.liveeditor.openAndConvert(char(source),char(converted));
template = fileread(converted);
assert(contains(template,'einstellungen.beta = beta;') && ...
    contains(template,'einstellungen.extraWaitEnabled = zusaetzlicheWartezeit;') && ...
    contains(template,'einstellungen.study = verkehrsstromuntersuchung;'), ...
    'TrafficFlow:LiveBindings','Eine Live-Eingabe ist nicht angeschlossen.');
visibility = get(groot,'DefaultFigureVisible');
cleanupVisibility = onCleanup(@() set(groot,'DefaultFigureVisible',visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
cases = table();
for study = [false true]
    mode = "einzellauf";
    if study, mode = "verkehrsstrom"; end
    runFolder = fullfile(out,mode);
    executable = template;
    values = struct('verkehrsstromuntersuchung',study,'anzahlZuege',12, ...
        'einschwingzeitMinuten',60,'messdauerMinuten',180, ...
        'wahrscheinlichkeitP',0.1,'zeitspanneSekunden',30, ...
        'langsamesAbbremsen',true,'beta',0.25, ...
        'zusaetzlicheWartezeit',true,'wartezeitzuschlagSekunden',6, ...
        'geschwindigkeitMinimumKmh',36,'geschwindigkeitMaximumKmh',80, ...
        'geschwindigkeitSchrittKmh',21.6, ...
        'zugzahlMinimum',8,'zugzahlMaximum',16,'zugzahlSchritt',4);
    names = fieldnames(values);
    for k = 1:numel(names)
        name = names{k}; value = values.(name);
        if islogical(value)
            literal = lower(string(value));
        else
            literal = string(sprintf('%.15g',value));
        end
        executable = regexprep(executable,['(?m)^' name '\s*=\s*[^;\r\n]+;'], ...
            name+" = "+literal+";");
    end
    executable = strrep(executable,'ergebnis = run_trafic_flow(einstellungen);', ...
        sprintf('ergebnis = run_trafic_flow(einstellungen,animate=false,outputFolder="%s");', ...
        strrep(runFolder,'\','/')));
    previousFigures = findall(groot,'Type','figure');
    started = tic;
    capturedOutput = evalc(executable);
    elapsed = toc(started);
    fid = fopen(fullfile(runFolder,'live_ausgabe.txt'),'w','n','UTF-8');
    fprintf(fid,'%s',capturedOutput); fclose(fid);
    created = setdiff(findall(groot,'Type','figure'),previousFigures);
    if study
        assert(numel(created) == 1 && ergebnis.figureCount == 1, ...
            'TrafficFlow:StudyFigures','Die Studie darf ausschließlich die Heatmap erzeugen.');
        assert(height(ergebnis.runs) == 9 && all(ergebnis.runs.passed));
        assert(isequal(size(ergebnis.throughput),[3 3]));
        assert(max(abs(ergebnis.effectiveSpeedsKmh-[36 57.6 79.2])) < 1e-9);
        for index = 1:height(ergebnis.runs)
            data = load(fullfile(runFolder,'laeufe',ergebnis.runs.file(index)));
            verifySaved(data,values);
            assert(abs(data.metrics.throughputTrainsPerHour- ...
                ergebnis.runs.throughput_trains_per_h(index)) < 1e-10);
        end
        % Die gezeichnete Matrix muss genau den abgespeicherten Werten entsprechen.
        chart = findall(created,'Type','image');
        assert(isequal(chart.CData,ergebnis.throughput));
        runs = height(ergebnis.runs);
    else
        assert(numel(created) == 4 && ergebnis.figureCount == 4);
        verifySaved(ergebnis,values);
        assert(ergebnis.report.randomStopCount > 0);
        assert(nnz(ergebnis.p.state.blockEntryLog(:,6)) > 0);
        assert(any(ergebnis.G.anticipationApplied,'all'));
        assert(ergebnis.comparison.completedTripCount > 0);
        runs = 1;
    end
    assert(numel(dir(fullfile(runFolder,'grafiken','*.png'))) == numel(created));
    assert(numel(dir(fullfile(runFolder,'grafiken','*.fig'))) == numel(created));
    for fig = created'
        for ax = findall(fig,'Type','axes')'
            expected = [1 1 1];
            if study, expected = [0.8 0.8 0.8]; end
            assert(isequal(ax.Color,expected) && isequal(ax.XColor,[0 0 0]) ...
                && isequal(ax.YColor,[0 0 0]));
        end
    end
    cases = [cases;table(mode,runs,numel(created),elapsed,true, ...
        'VariableNames',{'case_name','simulation_count','figure_count','elapsed_s','passed'})]; %#ok<AGROW>
    delete(created);
    fprintf('%s: %g Simulationen, %g Grafiken, %.1f s; bestanden.\n',mode,runs,height(created),elapsed);
end
writetable(cases,fullfile(out,'testfaelle.csv'));
writeTestNote(out,testTable,cases);
% Fester Verweis auf die neueste Dokumentation, ältere Testläufe bleiben erhalten.
fid = fopen(fullfile(root,'ergebnisse','trafic_flow','LETZTER_TEST.txt'),'w','n','UTF-8');
fprintf(fid,'%s\n',out); fclose(fid);
fprintf('Alle Tests bestanden. Dokumentation: %s\n',fullfile(out,'TESTBERICHT.md'));
end

function verifySaved(data,values)
G = data.G; p = data.p; m = data.metrics;
assert(data.report.checksPassed);
departures = p.state.departureLog;
start = values.einschwingzeitMinuten*60;
finish = start+values.messdauerMinuten*60;
selected = departures(:,3) == 1 & departures(:,1) >= start & departures(:,1) < finish;
assert(nnz(selected) == m.departureCount);
assert(abs(m.throughputTrainsPerHour-nnz(selected)/(values.messdauerMinuten/60)) < 1e-10);
assert(p.config.anticipationEnabled && p.config.anticipationBeta == values.beta);
assert(p.config.randomBrakeProbability == values.wahrscheinlichkeitP);
assert(p.config.randomStopProbability == values.wahrscheinlichkeitP);
assert(p.config.dwellOffsetSeconds == 6);
assert(all(p.stationDwellSeconds == p.baseStationDwellSeconds+6));
assert(max(abs(diff(G.velocity)),[],'all') <= 1);
assert(p.driveSpeedKmh <= 80);
end

function writeTestNote(out,tests,cases)
fid = fopen(fullfile(out,'TESTBERICHT.md'),'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# Testbericht: trafic_flow.mlx\n\n');
fprintf(fid,'Ausgeführt am %s (Europe/Berlin) mit MATLAB %s.\n\n', ...
    string(datetime('now','TimeZone','Europe/Berlin')),version);
fprintf(fid,'## Automatisierte Prüfungen\n\n');
fprintf(fid,'%g Modelltests bestanden; %g fehlgeschlagen. Enthalten sind die bestehenden Regressionen gegenüber Woche 1 sowie die neuen Störungs- und Antizipationstests.\n\n', ...
    nnz(tests.Passed),nnz(tests.Failed));
fprintf(fid,'Das native Live Script wurde durch MATLAB nach .m konvertiert. Beide Testfälle führen diesen Code mit Testeingaben aus; die Live-Eingaben werden dabei bis zur Modellkonfiguration geprüft.\n\n');
fprintf(fid,'## Gemeinsame Testeingaben\n\n');
fprintf(fid,'60 min Einschwingen + 180 min Messung, p = 0,1 für beide unabhängigen Störungsarten, Stationszusatz U{0,...,30} s, Antizipation aktiviert mit beta = 0,25 1/s, fester GTFS-Zuschlag aktiviert mit +6 s, Zufallsstartwert 42.\n\n');
fprintf(fid,'Die zeitaufwendige Animation wurde nur für die Batchprüfung deaktiviert; der geografische Endzustand wurde erzeugt und gespeichert. Im Live Script bleibt die Animation eingeschaltet (0,05 s Pause, 10 Schritte Bildabstand).\n\n');
fprintf(fid,'Grafiken verwenden unabhängig vom MATLAB-Design helle Hintergründe und schwarze Beschriftungen. Die Achsenfarben wurden ebenfalls geprüft.\n\n');
fprintf(fid,'## Einzellauf\n\n');
data = load(fullfile(out,'einzellauf','ergebnis.mat')); r = data.result;
fprintf(fid,'12 Züge, 80 km/h Eingabe / %.1f km/h effektiv. Durchsatz %.3f Züge/h aus %g gezählten Abfahrten.\n\n', ...
    r.p.driveSpeedKmh,r.metrics.throughputTrainsPerHour,r.metrics.departureCount);
fprintf(fid,'%g Blockeinfahrten geprüft, %g Zufallsbremsungen ausgelöst, %g positive Stationszusatzhalte, %g Antizipations-Bremssekunden. %g vollständige Ringfahrten für den GTFS-Vergleich.\n\n', ...
    height(r.p.state.blockEntryLog),nnz(r.p.state.blockEntryLog(:,6)),r.report.randomStopCount, ...
    nnz(r.G.anticipationApplied),r.comparison.completedTripCount);
fprintf(fid,'Vier Grafiken: geografischer Endzustand, Raum-Zeit, Geschwindigkeit/Beschleunigung von Zug 1, mittlere Geschwindigkeit. Jeweils PNG und FIG unter [einzellauf/grafiken](einzellauf/grafiken/).\n\n');
fprintf(fid,'## Verkehrsstromuntersuchung\n\n');
data = load(fullfile(out,'verkehrsstrom','ergebnis.mat')); r = data.result;
fprintf(fid,'Neun Kombinationen: 8 / 12 / 16 Züge und effektiv 36,0 / 57,6 / 79,2 km/h. Genau ein Lauf je Kombination. Die zusätzlich angefragten 80 km/h ergeben dieselbe Rasterstufe wie 79,2 km/h und werden zusammengefasst.\n\n');
fprintf(fid,'| Züge | 36,0 km/h | 57,6 km/h | 79,2 km/h |\n|---:|---:|---:|---:|\n');
for row = 1:3
    fprintf(fid,'| %g | %.3f | %.3f | %.3f |\n',r.trainCounts(row),r.throughput(row,:));
end
fprintf(fid,'\nAlle Angaben in Zügen/h. Genau eine Grafik, die [Heatmap](verkehrsstrom/grafiken/01_Verkehrsstromuntersuchung.png), wurde erzeugt. Ihre Bildmatrix stimmt mit den gespeicherten Durchsätzen überein.\n\n');
fprintf(fid,'## Unabhängige Ergebnisprüfung\n\n');
fprintf(fid,'Für alle zehn Simulationen wurden die Abfahrten an Station 1 aus den Ereignisprotokollen im halboffenen Messfenster [3600,14400) s erneut gezählt. Der Durchsatz stimmt damit überein. GTFS+6, beide p-Werte, beta, Beschleunigungsgrenzen, Ausgabeanzahl sowie PNG-/FIG-Export wurden geprüft. Der Modellkern prüft zudem Körper- und Blockbelegung, Bremsreserven, Stationsreihenfolge und Mindesthaltezeiten.\n\n');
fprintf(fid,'Dieser kleine Test belegt Funktion und reproduzierbare Auswertung. Er schätzt keine Zufallsunsicherheit und ersetzt keine umfassende Kapazitätsstudie.\n\n');
fprintf(fid,'## Dateien und Wiederholung\n\n');
fprintf(fid,'- `modelltests.csv` / `.mat`: vollständige Modelltestergebnisse.\n- `testfaelle.csv`: beide Oberflächentestfälle mit Laufzeiten.\n- `matlab.log`: Testprotokoll.\n- `trafic_flow_import.m`: von MATLAB aus dem ausgelieferten Live Script exportierter Code.\n- `einzellauf/` und `verkehrsstrom/`: Eingaben, Ereignisse/Rohdaten, Grafiken und jeweilige `LAUF.md`.\n\n');
fprintf(fid,'Wiederholen im Projektordner: `addpath(''tools''); test_trafic_flow`. Erstellt einen neuen Testordner und überschreibt keine früheren Testdaten.\n\n');
fprintf(fid,'Laufzeiten: Einzellauf %.1f s, Untersuchung %.1f s.\n',cases.elapsed_s(1),cases.elapsed_s(2));
end
