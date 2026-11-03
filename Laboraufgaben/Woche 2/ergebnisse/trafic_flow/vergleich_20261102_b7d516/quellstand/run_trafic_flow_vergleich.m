function output = run_trafic_flow_vergleich(output)
%RUN_TRAFIC_FLOW_VERGLEICH Zwei Wiederholungen, Halteheatmap und alte Vergleiche.
arguments
    output (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'modell'));
if output == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
    output = fullfile(root,'ergebnisse','trafic_flow',"vergleich_"+stamp);
end
if ~isfolder(output), mkdir(output); end
[~,info] = fileattrib(output); output = string(info.Name);
baseline = fullfile(root,'ergebnisse','trafic_flow','heatmaps_20261102_aaeb14');
assert(isfile(fullfile(baseline,'abschluss.json')),'TrafficCompare:Baseline','Die bisherigen Vergleichsmessungen fehlen.');
checkModelSource(root,baseline);
diary(fullfile(output,'matlab.log')); cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
visibility = get(groot,'DefaultFigureVisible');
cleanupVisibility = onCleanup(@() set(groot,'DefaultFigureVisible',visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');

pValues = 0:0.1:1; betaValues = 0.05:0.05:0.5;
[~,commonPIndex] = min(abs(pValues-0.3)); commonP = pValues(commonPIndex);
[~,commonBetaIndex] = min(abs(betaValues-0.2)); commonBeta = betaValues(commonBetaIndex);
s = trafic_flow_defaults;
s.study = true; s.anticipationEnabled = true; s.beta = commonBeta; s.probability = commonP;
s.trainMinimum = 12; s.trainMaximum = 40; s.trainStep = 4;
s.warmupMinutes = 60; s.measurementMinutes = 180; s.randomSeed = 42;
s.randomHoldMaxSeconds = 120; s.extraWaitEnabled = false; s.extraWaitSeconds = 0;
s.probabilityMinimum = 0; s.probabilityMaximum = 1; s.probabilityStep = 0.1;
s.betaMinimum = 0.05; s.betaMaximum = 0.5; s.betaStep = 0.05;
s.dwellMinimumSeconds = 0; s.dwellMaximumSeconds = 30; s.dwellStepSeconds = 6;

% Kleine Funktionsprüfung der neuen Achse und der Wiederverwendung identischer
% physikalischer Konfigurationen unabhängig von der gewählten Darstellungsachse.
probe = s; probe.studyAxis = "Haltezeitzuschlag";
probe.trainMinimum = 1; probe.trainMaximum = 2; probe.trainStep = 1;
probe.warmupMinutes = 0; probe.measurementMinutes = 3;
probe.dwellMaximumSeconds = 12;
probeFolder = fullfile(output,'funktionspruefung','halteachse');
test = runNativeDwellProbe(root,output,probeFolder,commonP,commonBeta);
assert(height(test.runs) == 6 && all(test.runs.passed));
for index = 1:height(test.runs)
    d = load(fullfile(probeFolder,'laeufe',test.runs.file(index)));
    assert(d.p.config.dwellOffsetSeconds == test.runs.x_value(index));
    assert(all(d.p.stationDwellSeconds == d.p.baseStationDwellSeconds+test.runs.x_value(index)));
    assert(d.p.config.anticipationEnabled && d.p.config.anticipationBeta == commonBeta);
    assert(d.p.config.randomStopProbability == commonP);
end
cacheFolder = fullfile(output,'funktionspruefung','achsenuebergreifend');
if ~isfolder(fullfile(cacheFolder,'laeufe')), mkdir(fullfile(cacheFolder,'laeufe')); end
seedFile(fullfile(probeFolder,'laeufe','n_001_h_000.mat'), ...
    fullfile(cacheFolder,'laeufe','n_001_beta_001.mat'));
cross = probe; cross.studyAxis = "Antizipationsfaktor beta"; cross.trainMaximum = 1;
cross.betaMinimum = commonBeta; cross.betaMaximum = commonBeta;
testCross = run_trafic_flow(cross,makeFigures=false,resume=true,outputFolder=cacheFolder);
assert(all(testCross.runs.reused));
different = cross; different.betaMinimum = 0.25; different.betaMaximum = 0.25;
try
    run_trafic_flow(different,makeFigures=false,resume=true,outputFolder=cacheFolder);
    error('TrafficCompare:MissingCacheGuard','Eine andere Konfiguration wurde wiederverwendet.');
catch exception
    assert(strcmp(exception.identifier,'TrafficFlow:ResumeMismatch'));
end
fprintf('Funktionsprüfung bestanden: sechs Haltezuschlagspunkte und strikte Konfigurationsprüfung.\n');

specs = repmat(struct('id',"",'title',"",'axis',"",'folder',"", ...
    'anticipation',false,'fixedP',NaN,'fixedBeta',NaN,'origin',""),1,5);
specs(1) = spec("p_bisher","Zugzahl und p: bisherige Messung","p", ...
    fullfile(baseline,'zugzahl_p'),false,NaN,0.25,"vorhandene Messung");
specs(2) = spec("p_beta020","Zugzahl und p: beta = 0,20 1/s","p", ...
    fullfile(output,'p_beta020'),true,NaN,commonBeta,"neue Messung");
specs(3) = spec("beta_bisher","Zugzahl und beta: bisherige Messung, p = 0","beta", ...
    fullfile(baseline,'zugzahl_beta'),true,0,NaN,"vorhandene Messung");
specs(4) = spec("beta_p030","Zugzahl und beta: p = 0,3","beta", ...
    fullfile(output,'beta_p030'),true,commonP,NaN,"neue Messung");
specs(5) = spec("halte_p030_beta020","Zugzahl und Haltezeitzuschlag: p = 0,3, beta = 0,20","dwell", ...
    fullfile(output,'halte_p030_beta020'),true,commonP,commonBeta,"neue Messung");
plan = struct('cases',specs,'warmupMinutes',60,'measurementMinutes',180, ...
    'randomSeed',42,'randomHoldMaxSeconds',120,'trainValues',12:4:40, ...
    'probabilityValues',pValues,'betaValues',betaValues,'dwellValuesSeconds',0:6:30, ...
    'requestedSpeedKmh',80,'effectiveSpeedKmh',79.2,'runsPerConfiguration',1, ...
    'createdBerlin',string(datetime('now','TimeZone','Europe/Berlin')),'matlabVersion',string(version));
writeJson(fullfile(output,'versuchsplan.json'),plan);

s.studyAxis = "Störungswahrscheinlichkeit p";
fprintf('Wiederholung p-Heatmap, beta=%.2f, Antizipation an.\n',commonBeta);
pResult = run_trafic_flow(s,parallel=true,workers=4,progress=true,resume=true,outputFolder=specs(2).folder);
assert(height(pResult.runs) == 88 && all(pResult.runs.passed));

% Die acht Schnittpunkte (p=0,3, beta=0,20, Zuschlag=0) sind in allen drei
% neuen Heatmaps physikalisch identisch und werden mit Herkunftsangabe geteilt.
betaTarget = fullfile(specs(4).folder,'laeufe'); if ~isfolder(betaTarget), mkdir(betaTarget); end
dwellTarget = fullfile(specs(5).folder,'laeufe'); if ~isfolder(dwellTarget), mkdir(dwellTarget); end
for train = 12:4:40
    source = fullfile(specs(2).folder,'laeufe',sprintf('n_%03d_p_%03d.mat',train,commonPIndex));
    seedFile(source,fullfile(betaTarget,sprintf('n_%03d_beta_%03d.mat',train,commonBetaIndex)));
    seedFile(source,fullfile(dwellTarget,sprintf('n_%03d_h_000.mat',train)));
end
s.studyAxis = "Antizipationsfaktor beta";
fprintf('Wiederholung beta-Heatmap, p=%.2f.\n',commonP);
betaResult = run_trafic_flow(s,parallel=true,workers=4,progress=true,resume=true,outputFolder=specs(4).folder);
assert(height(betaResult.runs) == 80 && all(betaResult.runs.passed));
s.studyAxis = "Haltezeitzuschlag";
fprintf('Neue Haltezuschlags-Heatmap, p=%.2f, beta=%.2f.\n',commonP,commonBeta);
dwellResult = run_trafic_flow(s,parallel=true,workers=4,progress=true,resume=true,outputFolder=specs(5).folder);
assert(height(dwellResult.runs) == 48);
for index = 1:height(dwellResult.runs)
    row = dwellResult.runs(index,:);
    if ~row.passed
        assert(startsWith(row.failure,"SBahn:NoSafeInitialPhase") || ...
            startsWith(row.failure,"SBahn:InitialBlockOverlap"), ...
            'TrafficCompare:UnexpectedFailure','Unerwarteter Modellfehler: %s',row.failure);
    end
end

% Die gemeinsamen Punkte müssen auch in der gezeichneten Matrix übereinstimmen.
assert(isequaln(pResult.throughput(:,commonPIndex),betaResult.throughput(:,commonBetaIndex)));
assert(isequaln(pResult.throughput(:,commonPIndex),dwellResult.throughput(:,1)));
for h = [pResult.figures(:);betaResult.figures(:);dwellResult.figures(:)]'
    if isgraphics(h), close(h); end
end
snapshot = fullfile(output,'quellstand'); if ~isfolder(snapshot), mkdir(snapshot); end
checkModelSource(root,baseline);
for name = ["trafic_flow.mlx","trafic_flow_defaults.m","run_trafic_flow.m", ...
        "trafic_flow_parallel_worker.m","run_trafic_flow_vergleich.m"]
    copyfile(fullfile(root,name),fullfile(snapshot,name));
end
copyfile(fullfile(root,'modell','+sbahn2'),fullfile(snapshot,'+sbahn2'));
copyfile(fullfile(root,'tools','trafic_flow_source.m'),snapshot);
copyfile(fullfile(root,'tools','build_trafic_flow.py'),snapshot);
writeJson(fullfile(output,'abschluss.json'),struct('complete',true, ...
    'newPoints',216,'baselinePoints',168,'newUniqueConfigurations',200, ...
    'newSuccessfulPoints',nnz(pResult.runs.passed)+nnz(betaResult.runs.passed)+nnz(dwellResult.runs.passed), ...
    'sharedIntersectionsChecked',true,'axisAndCacheChecksPassed',true,'nativeLiveScriptChecked',true));
fprintf('Abgeschlossen: 216 neue und 168 bisherige Diagrammpunkte.\n');
end

function result = runNativeDwellProbe(root,output,target,probability,betaValue)
% Die neue Achse über den von MATLAB importierten Live-Script-Code prüfen.
converted = fullfile(output,'trafic_flow_import.m');
matlab.internal.liveeditor.openAndConvert(char(fullfile(root,'trafic_flow.mlx')),char(converted));
code = fileread(converted);
for binding = ["dwellMinimumSeconds = haltezuschlagMinimumSekunden", ...
        "dwellMaximumSeconds = haltezuschlagMaximumSekunden", ...
        "dwellStepSeconds = haltezuschlagSchrittSekunden"]
    assert(contains(code,binding),'TrafficCompare:LiveBinding','Live-Eingabe fehlt: %s',binding);
end
values = struct('verkehrsstromuntersuchung',true,'untersuchungsachse',"Haltezeitzuschlag", ...
    'einschwingzeitMinuten',0,'messdauerMinuten',3,'wahrscheinlichkeitP',probability, ...
    'zeitspanneSekunden',120,'langsamesAbbremsen',true,'beta',betaValue, ...
    'zusaetzlicheWartezeit',false,'wartezeitzuschlagSekunden',0, ...
    'zugzahlMinimum',1,'zugzahlMaximum',2,'zugzahlSchritt',1, ...
    'haltezuschlagMinimumSekunden',0,'haltezuschlagMaximumSekunden',12, ...
    'haltezuschlagSchrittSekunden',6);
names = fieldnames(values);
for k = 1:numel(names)
    value = values.(names{k});
    if isstring(value)
        literal = """"+value+"""";
    elseif islogical(value)
        literal = string(value);
    else
        literal = string(mat2str(value,17));
    end
    expression = "(?m)^"+names{k}+" = [^;\r\n]+;";
    assert(~isempty(regexp(code,expression,'once')),'TrafficCompare:LiveAssignment','Eingabe fehlt.');
    code = regexprep(code,expression,names{k}+" = "+literal+";");
end
call = "ergebnis = run_trafic_flow(einstellungen);";
assert(contains(code,call),'TrafficCompare:LiveCall','Live-Aufruf fehlt.');
replacement = "ergebnis = run_trafic_flow(einstellungen,makeFigures=false,resume=true,outputFolder="""+target+""");";
code = strrep(code,call,replacement);
fid = fopen(fullfile(output,'trafic_flow_halteachse_test.m'),'w','n','UTF-8');
assert(fid >= 0); fprintf(fid,'%s',code); fclose(fid);
eval(code);
result = ergebnis;
end

function value = spec(id,title,axis,folder,anticipation,p,beta,origin)
value = struct('id',id,'title',title,'axis',axis,'folder',folder, ...
    'anticipation',anticipation,'fixedP',p,'fixedBeta',beta,'origin',origin);
end

function seedFile(source,target)
if isfile(target), return; end
data = load(source);
assert(data.report.checksPassed,'TrafficCompare:Seed','Quelllauf ist ungeprüft.');
data.reuse_source = string(source);
save(target,'-struct','data','-v7');
end

function writeJson(path,value)
fid = fopen(path,'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end

function checkModelSource(root,baseline)
% Der alte und der neue Durchsatz dürfen nur denselben Modellkern verwenden.
current = fullfile(root,'modell','+sbahn2');
previous = fullfile(baseline,'quellstand','+sbahn2');
files = dir(fullfile(current,'**','*.m'));
oldFiles = dir(fullfile(previous,'**','*.m'));
assert(numel(files) == numel(oldFiles) && ~isempty(files), ...
    'TrafficCompare:ModelSource','Die Anzahl der Modellquellen weicht ab.');
for k = 1:numel(files)
    path = fullfile(files(k).folder,files(k).name);
    relative = path(numel(current)+2:end);
    oldPath = fullfile(previous,relative);
    assert(isfile(oldPath) && strcmp(fileread(path),fileread(oldPath)), ...
        'TrafficCompare:ModelSource','Modellquelle seit Vergleichsmessung verändert: %s',relative);
end
end
