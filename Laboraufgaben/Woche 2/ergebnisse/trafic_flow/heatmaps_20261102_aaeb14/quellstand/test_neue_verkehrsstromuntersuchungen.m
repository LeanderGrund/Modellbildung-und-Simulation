function output = test_neue_verkehrsstromuntersuchungen(output,regressionFolder)
%TEST_NEUE_VERKEHRSSTROMUNTERSUCHUNGEN Native MLX-Bedienung und zwei Heatmaps.
arguments
    output (1,1) string = ""
    regressionFolder (1,1) string = ""
end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'modell'),fullfile(root,'tools'));
if output == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
    output = fullfile(root,'ergebnisse','trafic_flow',"neue_heatmaps_"+stamp);
end
if ~isfolder(output), mkdir(output); end

% Die bisherigen Betriebsarten und alle vorhandenen Modelltests bleiben geprüft.
if regressionFolder == ""
    test_trafic_flow;
    regressionFolder = strtrim(fileread(fullfile(root,'ergebnisse','trafic_flow','LETZTER_TEST.txt')));
else
    existingTests = readtable(fullfile(regressionFolder,'modelltests.csv'));
    existingCases = readtable(fullfile(regressionFolder,'testfaelle.csv'));
    assert(all(existingTests.Passed) && ~any(existingTests.Failed) && all(existingCases.passed));
end
proof = fullfile(output,'regression'); if ~isfolder(proof), mkdir(proof); end
for name = ["modelltests.csv","modelltests.mat","testfaelle.csv","TESTBERICHT.md"]
    copyfile(fullfile(regressionFolder,name),fullfile(proof,name));
end
diary(fullfile(output,'matlab.log')); cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('Neue Heatmaps: %s\n',output);
% Vier kurze neue Läufe in beiden Ausführungsarten prüfen die vollständigen
% Trajektorien und Ereignisse auf bitgleiche Ergebnisse.
probe = trafic_flow_defaults;
probe.study = true; probe.studyAxis = "Störungswahrscheinlichkeit p";
probe.trainMinimum = 1; probe.trainMaximum = 2; probe.trainStep = 1;
probe.probabilityMinimum = 0; probe.probabilityMaximum = 1; probe.probabilityStep = 1;
probe.warmupMinutes = 0; probe.measurementMinutes = 3;
sequentialFolder = fullfile(output,'parallel_pruefung','sequentiell');
parallelFolder = fullfile(output,'parallel_pruefung','parallel');
sequential = run_trafic_flow(probe,makeFigures=false,resume=true,outputFolder=sequentialFolder);
parallelResult = run_trafic_flow(probe,makeFigures=false,resume=true, ...
    parallel=true,workers=4,outputFolder=parallelFolder);
assert(isequaln(sequential.throughput,parallelResult.throughput));
for k = 1:height(sequential.runs)
    a = load(fullfile(sequentialFolder,'laeufe',sequential.runs.file(k)));
    b = load(fullfile(parallelFolder,'laeufe',parallelResult.runs.file(k)));
    assert(isequaln(a.G,b.G) && isequaln(a.p.state,b.p.state) && isequaln(a.report,b.report));
end
fprintf('Vier sequentielle/parallele Testkonfigurationen: Trajektorien und Ereignisse bitgleich.\n');
% Die bisherige Geschwindigkeitsachse wird nach der Umstellung zusätzlich
% gegen ihre zuvor berechneten neun Konfigurationen geprüft.
legacy = load(fullfile(regressionFolder,'verkehrsstrom','ergebnis.mat'));
legacyFolder = fullfile(output,'kompatibilitaet_geschwindigkeit');
if ~isfolder(fullfile(legacyFolder,'laeufe')), mkdir(fullfile(legacyFolder,'laeufe')); end
copyfile(fullfile(regressionFolder,'verkehrsstrom','laeufe','*.mat'),fullfile(legacyFolder,'laeufe'));
legacyActual = run_trafic_flow(legacy.result.settings,makeFigures=false,resume=true,outputFolder=legacyFolder);
assert(isequaln(legacy.result.throughput,legacyActual.throughput) && all(legacyActual.runs.reused));
source = fullfile(root,'trafic_flow.mlx');
converted = fullfile(output,'trafic_flow_import.m');
matlab.internal.liveeditor.openAndConvert(char(source),char(converted));
template = fileread(converted);
for binding = ["studyAxis = untersuchungsachse", ...
        "probabilityMinimum = pMinimum","probabilityMaximum = pMaximum", ...
        "probabilityStep = pSchritt","betaMinimum = betaMinimum", ...
        "betaMaximum = betaMaximum","betaStep = betaSchritt"]
    assert(contains(template,binding),'TrafficFlow:LiveBinding','Live-Eingabe fehlt: %s',binding);
end

% Bereichsfehler werden vor Erzeugung eines Ausgabeordners abgewiesen.
invalid = trafic_flow_defaults; invalid.study = true;
invalid.probabilityMinimum = 0.8; invalid.probabilityMaximum = 0.2;
try
    run_trafic_flow(invalid,makeFigures=false);
    error('TrafficFlow:MissingRangeError','Ungültiger p-Bereich wurde angenommen.');
catch exception
    assert(strcmp(exception.identifier,'TrafficFlow:Range'));
end
invalid = trafic_flow_defaults; invalid.betaMinimum = 0;
try
    run_trafic_flow(invalid,makeFigures=false);
    error('TrafficFlow:MissingBetaError','beta=0 wurde angenommen.');
catch exception
    assert(startsWith(exception.identifier,'MATLAB:'));
end

visibility = get(groot,'DefaultFigureVisible');
cleanupVisibility = onCleanup(@() set(groot,'DefaultFigureVisible',visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
cases = table();
for mode = ["Störungswahrscheinlichkeit p","Antizipationsfaktor beta"]
    probabilityMode = mode == "Störungswahrscheinlichkeit p";
    folderName = "zugzahl_beta"; if probabilityMode, folderName = "zugzahl_p"; end
    target = fullfile(output,folderName);
    values = struct('verkehrsstromuntersuchung',true,'untersuchungsachse',mode, ...
        'einschwingzeitMinuten',60,'messdauerMinuten',180,'zeitspanneSekunden',120, ...
        'langsamesAbbremsen',false,'beta',0.25,'zusaetzlicheWartezeit',false, ...
        'wartezeitzuschlagSekunden',10,'wahrscheinlichkeitP',0, ...
        'zugzahlMinimum',12,'zugzahlMaximum',40,'zugzahlSchritt',4, ...
        'pMinimum',0,'pMaximum',1,'pSchritt',0.1, ...
        'betaMinimum',0.05,'betaMaximum',0.5,'betaSchritt',0.05, ...
        'geschwindigkeitMinimumKmh',36,'geschwindigkeitMaximumKmh',36);
    % Bei der p-Achse muss der einzelne p-Wert vollständig durch den Bereich
    % ersetzt werden. Bei beta muss trotz ausgeschalteter Checkbox antizipiert werden.
    if probabilityMode, values.wahrscheinlichkeitP = 0.37; end
    executable = template;
    names = fieldnames(values);
    for k = 1:numel(names)
        name = names{k};
        pattern = ['(?m)^' name '\s*=\s*[^;\r\n]+;'];
        assert(numel(regexp(executable,pattern)) == 1,'TrafficFlow:TestInput','Eingabe nicht eindeutig: %s',name);
        executable = regexprep(executable,pattern,sprintf('%s = %s;',name,jsonencode(values.(name))));
    end
    executable = strrep(executable,'ergebnis = run_trafic_flow(einstellungen);', ...
        sprintf('ergebnis = run_trafic_flow(einstellungen,animate=false,progress=true,parallel=true,workers=4,resume=true,outputFolder="%s");', ...
        strrep(target,'\','/')));
    previousFigures = findall(groot,'Type','figure');
    started = tic;
    eval(executable);
    elapsedSeconds = toc(started);
    created = setdiff(findall(groot,'Type','figure'),previousFigures);
    expected = 80; if probabilityMode, expected = 88; end
    assert(height(ergebnis.runs) == expected && all(ergebnis.runs.passed));
    assert(ergebnis.figureCount == 1 && numel(created) == 1);
    assert(ergebnis.studyAxis == mode);
    assert(isequal(size(ergebnis.throughput),[8 expected/8]));
    chart = findall(created,'Type','image');
    assert(isequal(chart.CData,ergebnis.throughput));
    assert(all(ergebnis.runs.requested_kmh == 80));
    assert(all(abs(ergebnis.runs.effective_kmh-79.2) < 1e-10));
    assert(all(ergebnis.runs.anticipation == ~probabilityMode));
    assert(numel(dir(fullfile(target,'grafiken','*.png'))) == 1);
    assert(numel(dir(fullfile(target,'grafiken','*.fig'))) == 1);
    for k = 1:height(ergebnis.runs)
        data = load(fullfile(target,'laeufe',ergebnis.runs.file(k)));
        [metric,~] = trafic_flow_study_metrics(data.G,data.p,3600,10800);
        assert(data.report.checksPassed && metric.detector_check_passed);
        assert(abs(metric.throughput_trains_per_h-ergebnis.runs.throughput_trains_per_h(k)) < 1e-10);
        config = data.p.config;
        assert(config.cruiseSpeedKmh == 80);
        assert(config.anticipationEnabled == ~probabilityMode);
        if probabilityMode
            assert(abs(config.randomStopProbability-ergebnis.runs.x_value(k)) < 1e-10);
            assert(config.randomStopProbability == config.randomBrakeProbability);
            assert(config.anticipationBeta == 0.25);
        else
            assert(abs(config.anticipationBeta-ergebnis.runs.x_value(k)) < 1e-10);
            assert(config.randomStopProbability == 0 && config.randomBrakeProbability == 0);
        end
    end
    cases = [cases;table(mode,expected,numel(created),elapsedSeconds,true, ...
        'VariableNames',{'study_axis','simulation_count','figure_count','elapsed_s','passed'})]; %#ok<AGROW>
    writetable(cases,fullfile(output,'testfaelle.csv'));
    delete(created);
end
snapshot = fullfile(output,'quellstand'); mkdir(snapshot);
for name = ["trafic_flow.mlx","trafic_flow_defaults.m","run_trafic_flow.m","trafic_flow_parallel_worker.m"]
    copyfile(fullfile(root,name),fullfile(snapshot,name));
end
copyfile(fullfile(root,'modell','+sbahn2'),fullfile(snapshot,'+sbahn2'));
copyfile(fullfile(root,'tools','trafic_flow_source.m'),snapshot);
copyfile(fullfile(root,'tools','build_trafic_flow.py'),snapshot);
copyfile(mfilename('fullpath')+".m",snapshot);
fid = fopen(fullfile(output,'abschluss.json'),'w','n','UTF-8'); assert(fid >= 0);
fprintf(fid,'%s\n',jsonencode(struct('complete',true,'newSimulations',168, ...
    'newFigures',2,'rangeValidationPassed',true,'parallelEquivalencePassed',true, ...
    'parallelEquivalenceCases',4,'parallelWorkers',4,'legacyAxisRechecked',true, ...
    'regressionFolder',regressionFolder), ...
    'PrettyPrint',true)); fclose(fid);
fprintf('Neue Untersuchungen bestanden: 88 p-Läufe und 80 beta-Läufe.\n');
end
