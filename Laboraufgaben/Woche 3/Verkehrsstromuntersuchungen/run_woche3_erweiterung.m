function output = run_woche3_erweiterung(output)
%RUN_WOCHE3_ERWEITERUNG Vergleichbare Beta- und Haltezuschlagsreihen für vier N.
arguments
    output (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'modell'));
if output == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
    output = fullfile(root,'ergebnisse',"erweiterung_"+stamp);
end
if ~isfolder(output), mkdir(output); end
[~,info] = fileattrib(output); output = string(info.Name);
diary(fullfile(output,'matlab_erweiterung.log')); cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
source = fullfile(root,'modell','+sbahn3x'); saved = fullfile(output,'quellstand');
if ~isfolder(saved)
    mkdir(saved); copyfile(source,fullfile(saved,'+sbahn3x'));
    for name = ["run_woche3_erweiterung.m","woche3_erweiterung_worker.m", ...
            "bericht_woche3_erweiterung.py","erweiterung_daten_hashes.json"]
        copyfile(fullfile(root,name),fullfile(saved,name));
    end
else
    current = dir(fullfile(source,'**','*.m'));
    previous = dir(fullfile(saved,'+sbahn3x','**','*.m'));
    assert(numel(current) == numel(previous),'Week3x:SourceMismatch','Modellquellen verändert.');
    for k = 1:numel(current)
        path = fullfile(current(k).folder,current(k).name); relative = path(numel(source)+2:end);
        assert(strcmp(fileread(path),fileread(fullfile(saved,'+sbahn3x',relative))), ...
            'Week3x:SourceMismatch','Modellquelle verändert: %s',relative);
    end
end
plan = struct('probability',0.2,'trainCounts',[20,28,36,44], ...
    'betaValues',0:0.05:0.5,'dwellValuesSeconds',[0,6,12,18,24,30,36,42,45], ...
    'fixedDwellBeta',0.2,'representativeTrainCount',28,'representativeBeta',0.2, ...
    'representativeDwellSeconds',18,'warmupMinutes',60,'measurementMinutes',180, ...
    'randomSeed',42,'randomHoldMaxSeconds',120,'requestedSpeedKmh',80, ...
    'effectiveSpeedKmh',79.2,'anticipationMaxBlocks',2,'leaderReference',"Zugende", ...
    'initializationMode',"Ruhende Blockaufstellung",'runsPerConfiguration',1, ...
    'initializationReason',"Für N=44 ist keine sichere gemeinsame freie Zeitphase vorhanden.", ...
    'createdBerlin',string(datetime('now','TimeZone','Europe/Berlin')));
writeJson(fullfile(output,'parameter.json'),plan);

% Grenzfalltests und die neue sichere Aufstellung werden vor den Hauptläufen geprüft.
a = sbahn3x.checkBlockAnticipation; b = sbahn3x.checkStationaryInitialization;
assert(all(a.passed) && all(b.passed));
writetable(a,fullfile(output,'blockpruefung.csv'));
writetable(b,fullfile(output,'initialisierung_pruefung.csv'));
c = sbahn3x.defaultConfig;
c.trackMode = "Reale Ringbahn S41"; c.displayMode = "Geografischer Streckenverlauf";
c.motionModel = "Beschleunigen und Bremsen"; c.blockMode = "OSM-Signalabschnitte";
c.dwellMode = "GTFS-Stationshalte"; c.cruiseSpeedKmh = 80;
c.initializationMode = plan.initializationMode; c.initialPhaseSearch = false;
c.durationMinutes = plan.warmupMinutes+plan.measurementMinutes;
c.randomBrakeEnabled = true; c.randomBrakeProbability = plan.probability;
c.randomStopEnabled = true; c.randomStopProbability = plan.probability;
c.randomStopMinSeconds = 0; c.randomStopMaxSeconds = plan.randomHoldMaxSeconds;
c.anticipationEnabled = true; c.anticipationMaxBlocks = 2;
c.randomSeed = plan.randomSeed; c.animate = false;
tasks = cell(76,1); index = 0;
for train = plan.trainCounts
    c.trainCount = train; c.dwellOffsetSeconds = 0;
    for j = 1:numel(plan.betaValues)
        index = index+1; c.anticipationBeta = plan.betaValues(j);
        tasks{index} = struct('config',c,'series',"beta",'x',plan.betaValues(j), ...
            'file',string(sprintf('n_%03d_beta_%03d.mat',train,j)));
    end
end
for train = plan.trainCounts
    c.trainCount = train; c.anticipationBeta = plan.fixedDwellBeta;
    for extra = plan.dwellValuesSeconds(2:end)
        index = index+1; c.dwellOffsetSeconds = extra;
        tasks{index} = struct('config',c,'series',"haltezeit",'x',extra, ...
            'file',string(sprintf('n_%03d_h_%03d.mat',train,extra)));
    end
end
assert(index == 76);
raw = fullfile(output,'laeufe'); if ~isfolder(raw), mkdir(raw); end
jobsRoot = fullfile(output,'parallel_jobs'); if ~isfolder(jobsRoot), mkdir(jobsRoot); end
jobs = string(tempname(jobsRoot)); mkdir(jobs);
statusFiles = fullfile(jobs,compose('task_%03d.mat',(1:numel(tasks))'));
workers = cell(1,4);
for worker = 1:4
    indices = worker:4:numel(tasks);
    spec = struct('indices',indices,'plan',plan,'rawFolder',raw,'task',@studyCase);
    spec.tasks = tasks(indices); spec.statusFiles = statusFiles(indices);
    specFile = fullfile(jobs,sprintf('worker_%02d_spec.mat',worker)); save(specFile,'spec','-v7');
    log = fullfile(jobs,sprintf('worker_%02d.log',worker));
    expression = sprintf('addpath(''%s''); woche3_erweiterung_worker(''%s'');', ...
        strrep(root,'''',''''''),strrep(char(specFile),'''',''''''));
    process = System.Diagnostics.ProcessStartInfo;
    process.FileName = fullfile(matlabroot,'bin','matlab.exe');
    process.Arguments = sprintf('-batch "%s" -logfile "%s"',expression,log);
    process.WorkingDirectory = root; process.UseShellExecute = false;
    process.CreateNoWindow = true; process.WindowStyle = System.Diagnostics.ProcessWindowStyle.Hidden;
    workers{worker} = System.Diagnostics.Process.Start(process);
end
cleanupWorkers = onCleanup(@() closeWorkers(workers)); %#ok<NASGU>
entries = cell(numel(tasks),1);
for done = 1:numel(tasks)
    while true
        ready = find(cellfun(@isempty,entries) & isfile(statusFiles),1);
        if ~isempty(ready)
            try
                d = load(statusFiles(ready),'entry'); entry = d.entry; break;
            catch
                % Kurze Schreibvorgänge können schon als Datei sichtbar sein.
            end
        end
        assert(any(cellfun(@(p) ~p.HasExited,workers)),'Week3x:WorkerFailed', ...
            'Ein Arbeitsprozess ist ohne gültige Statusdatei beendet; siehe parallel_jobs/.');
        pause(0.25);
    end
    entries{ready} = entry;
    runs = vertcat(entries{~cellfun(@isempty,entries)});
    writetable(runs,fullfile(output,'laufindex.csv'));
    fprintf('Messung %d/76 | %s | N=%d | x=%.3g | Q=%.3f | bestanden=%s\n', ...
        done,entry.series,entry.train_count,entry.x_value,entry.throughput_trains_per_h,string(entry.passed));
end
assert(all(runs.passed),'Week3x:FailedRuns','Mindestens eine Messung ist fehlgeschlagen.');
betaRuns = sortrows(runs(runs.series == "beta",:),{'train_count','x_value'});
dwellRuns = runs(runs.series == "haltezeit",:);
for train = plan.trainCounts
    shared = betaRuns(betaRuns.train_count == train & abs(betaRuns.beta-plan.fixedDwellBeta) < 1e-12,:);
    assert(height(shared) == 1);
    shared.series = "haltezeit"; shared.x_value = 0; shared.shared_point = true;
    dwellRuns = [dwellRuns;shared]; %#ok<AGROW>
end
dwellRuns = sortrows(dwellRuns,{'train_count','x_value'});
writetable(betaRuns,fullfile(output,'beta.csv'));
writetable(dwellRuns,fullfile(output,'haltezeiten.csv'));
writetable([betaRuns;dwellRuns],fullfile(output,'alle_punkte.csv'));
betaQ = reshape(betaRuns.throughput_trains_per_h,11,4)';
dwellQ = reshape(dwellRuns.throughput_trains_per_h,9,4)';
assert(isequal(betaQ(:,5),dwellQ(:,1)));
result = struct('plan',plan,'betaValues',plan.betaValues,'trainCounts',plan.trainCounts, ...
    'dwellValuesSeconds',plan.dwellValuesSeconds,'betaThroughput',betaQ,'dwellThroughput',dwellQ);
save(fullfile(output,'ergebnis.mat'),'result','-v7');
writeJson(fullfile(output,'abschluss.json'),struct('complete',true,'uniqueConfigurations',76, ...
    'diagramPoints',80,'betaPoints',44,'dwellPoints',36,'sharedPoints',4, ...
    'allRunsPassed',all(runs.passed),'newInitializationTestsPassed',all(b.passed)));
fprintf('Abgeschlossen: 76 Konfigurationen, 80 Diagrammpunkte.\n%s\n',output);
end

function entry = studyCase(task,plan,rawFolder)
c = task.config; path = fullfile(rawFolder,task.file);
passed = false; failure = ""; value = NaN; count = NaN; reused = false;
try
    if isfile(path)
        d = load(path);
        assert(isequaln(d.p.config,c) && d.plan.warmupMinutes == plan.warmupMinutes && ...
            d.plan.measurementMinutes == plan.measurementMinutes,'Week3x:ResumeMismatch', ...
            'Andere Konfiguration oder Messfenster im gespeicherten Lauf.');
        assert(d.report.checksPassed); metrics = d.metrics; reused = true;
    else
        [G,p,report] = sbahn3x.simulate(c);
        selected = G.timeSeconds(1:end-1) >= plan.warmupMinutes*60 & ...
            G.timeSeconds(1:end-1) < (plan.warmupMinutes+plan.measurementMinutes)*60;
        moved = mod(diff(G.position),p.cellCount) > 0;
        departure = G.position(1:end-1,:) == p.route.stationCells(1) & moved;
        count = nnz(departure(selected,:));
        metrics = struct('departureCount',count, ...
            'throughputTrainsPerHour',count/(plan.measurementMinutes/60), ...
            'warmupSeconds',plan.warmupMinutes*60,'measurementSeconds',plan.measurementMinutes*60);
        assert(report.checksPassed); save(path,'G','p','report','metrics','plan','-v7');
    end
    passed = true; value = metrics.throughputTrainsPerHour; count = metrics.departureCount;
catch exception
    failure = string(exception.identifier)+": "+string(exception.message);
    if strcmp(exception.identifier,'Week3x:ResumeMismatch'), rethrow(exception); end
    save(path,'c','failure','plan','-v7');
end
entry = table(task.series,task.x,c.trainCount,c.anticipationBeta,c.dwellOffsetSeconds, ...
    value,count,passed,failure,reused,false,task.file, ...
    'VariableNames',{'series','x_value','train_count','beta','extra_dwell_s', ...
    'throughput_trains_per_h','departure_count','passed','failure','reused','shared_point','file'});
end

function closeWorkers(workers)
for k = 1:numel(workers)
    try
        if ~workers{k}.HasExited, workers{k}.WaitForExit(10000); end
        workers{k}.Close();
    catch
    end
end
end

function writeJson(path,value)
fid = fopen(path,'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
