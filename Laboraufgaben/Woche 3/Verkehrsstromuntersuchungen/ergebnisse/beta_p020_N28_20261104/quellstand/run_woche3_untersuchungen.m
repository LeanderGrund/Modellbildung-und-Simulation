function output = run_woche3_untersuchungen(output)
%RUN_WOCHE3_UNTERSUCHUNGEN Beta-Reihe mit Zugende in höchstens zwei Blöcken.
arguments
    output (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'modell'));
if output == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
    output = fullfile(root,'ergebnisse',"beta_zwei_bloecke_"+stamp);
end
if ~isfolder(output), mkdir(output); end
[~,info] = fileattrib(output); output = string(info.Name);
diary(fullfile(output,'matlab.log')); cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
snapshotSources(root,output);
tests = sbahn3.checkBlockAnticipation;
assert(all(tests.passed)); writetable(tests,fullfile(output,'blockpruefung.csv'));
plan = struct('probability',0.2,'trainCount',28,'betaValues',0:0.05:0.5, ...
    'warmupMinutes',60,'measurementMinutes',180,'randomSeed',42, ...
    'randomHoldMaxSeconds',120,'dwellOffsetSeconds',0, ...
    'requestedSpeedKmh',80,'effectiveSpeedKmh',79.2,'anticipationMaxBlocks',2, ...
    'leaderReference',"Zugende",'representativeBeta',0.2, ...
    'holdStudyIncluded',false,'runsPerConfiguration',1, ...
    'createdBerlin',string(datetime('now','TimeZone','Europe/Berlin')));
writeJson(fullfile(output,'parameter.json'),plan);
c = sbahn3.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.displayMode = "Geografischer Streckenverlauf";
c.motionModel = "Beschleunigen und Bremsen";
c.blockMode = "OSM-Signalabschnitte"; c.blockLengthMeters = 500;
c.dwellMode = "GTFS-Stationshalte"; c.initialPhaseSearch = true;
c.trainCount = plan.trainCount; c.cruiseSpeedKmh = plan.requestedSpeedKmh;
c.durationMinutes = plan.warmupMinutes+plan.measurementMinutes;
c.randomBrakeEnabled = true; c.randomBrakeProbability = plan.probability;
c.randomStopEnabled = true; c.randomStopProbability = plan.probability;
c.randomStopMinSeconds = 0; c.randomStopMaxSeconds = plan.randomHoldMaxSeconds;
c.anticipationEnabled = true; c.anticipationMaxBlocks = 2;
c.dwellOffsetSeconds = 0; c.randomSeed = plan.randomSeed; c.animate = false;
raw = fullfile(output,'laeufe'); if ~isfolder(raw), mkdir(raw); end
runs = table();
for index = 1:numel(plan.betaValues)
    c.anticipationBeta = plan.betaValues(index);
    name = string(sprintf('beta_%02d.mat',index)); path = fullfile(raw,name);
    reused = false;
    if isfile(path)
        d = load(path);
        assert(isequaln(d.p.config,c) && d.plan.warmupMinutes == plan.warmupMinutes ...
            && d.plan.measurementMinutes == plan.measurementMinutes, ...
            'Week3:ResumeMismatch','Gespeicherter Lauf hat eine andere Konfiguration.');
        assert(d.report.checksPassed,'Week3:ResumeUnchecked','Gespeicherter Lauf ist ungeprüft.');
        metrics = d.metrics; reused = true;
    else
        [G,p,report] = sbahn3.simulate(c);
        rows = G.timeSeconds(1:end-1) >= plan.warmupMinutes*60 & ...
            G.timeSeconds(1:end-1) < (plan.warmupMinutes+plan.measurementMinutes)*60;
        moved = mod(diff(G.position),p.cellCount) > 0;
        departure = G.position(1:end-1,:) == p.route.stationCells(1) & moved;
        count = nnz(departure(rows,:));
        metrics = struct('departureCount',count, ...
            'throughputTrainsPerHour',count/(plan.measurementMinutes/60), ...
            'warmupSeconds',plan.warmupMinutes*60, ...
            'measurementSeconds',plan.measurementMinutes*60);
        assert(report.checksPassed);
        save(path,'G','p','report','metrics','plan','-v7');
    end
    entry = table(c.anticipationBeta,metrics.throughputTrainsPerHour, ...
        metrics.departureCount,true,reused,name, ...
        'VariableNames',{'beta','throughput_trains_per_h','departure_count','passed','reused','file'});
    runs = [runs;entry]; %#ok<AGROW>
    writetable(runs,fullfile(output,'beta.csv'));
    fprintf('Beta-Reihe %d/%d | beta=%.2f | Q=%.3f Zuege/h | bestanden=true | uebernommen=%s\n', ...
        index,numel(plan.betaValues),c.anticipationBeta,metrics.throughputTrainsPerHour,string(reused));
end
result = struct('plan',plan,'runs',runs,'betaValues',runs.beta', ...
    'throughput',runs.throughput_trains_per_h');
save(fullfile(output,'ergebnis.mat'),'result','-v7');
writeJson(fullfile(output,'abschluss.json'),struct('complete',true,'configurations',11, ...
    'allRunsPassed',all(runs.passed),'blockBoundaryTestsPassed',all(tests.passed), ...
    'blockBoundaryTestCount',height(tests),'representativeBeta',0.2,'holdStudyIncluded',false));
fprintf('Woche 3 abgeschlossen: elf beta-Werte, keine Haltezeitreihe.\n%s\n',output);
end

function snapshotSources(root,output)
target = fullfile(output,'quellstand');
source = fullfile(root,'modell','+sbahn3');
if isfolder(target)
    saved = fullfile(target,'+sbahn3');
    a = dir(fullfile(source,'**','*.m')); b = dir(fullfile(saved,'**','*.m'));
    assert(numel(a) == numel(b),'Week3:SourceMismatch','Modellquellen wurden verändert.');
    for k = 1:numel(a)
        path = fullfile(a(k).folder,a(k).name); relative = path(numel(source)+2:end);
        previous = fullfile(saved,relative);
        assert(isfile(previous) && strcmp(fileread(path),fileread(previous)), ...
            'Week3:SourceMismatch','Modellquelle verändert: %s',relative);
    end
else
    mkdir(target); copyfile(source,fullfile(target,'+sbahn3'));
    for name = ["run_woche3_untersuchungen.m","bericht_woche3.py","README.md"]
        copyfile(fullfile(root,name),fullfile(target,name));
    end
end
end

function writeJson(path,value)
fid = fopen(path,'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
