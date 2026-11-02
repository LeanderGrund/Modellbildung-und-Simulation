function output = run_trafic_flow_studien(output)
%RUN_TRAFIC_FLOW_STUDIEN Angeforderte Serien ohne Änderung des Modellkerns.
arguments
    output (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'modell'),fullfile(root,'tools'));
if output == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss'));
    output = fullfile(root,'ergebnisse','trafic_flow',"studie_"+stamp);
end
if ~isfolder(output), mkdir(output); end
runFolder = fullfile(output,'laeufe'); if ~isfolder(runFolder), mkdir(runFolder); end
diary(fullfile(output,'matlab.log')); cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
test_study_metrics;
plan = struct('warmupMinutes',60,'measurementMinutes',180,'beta',0.25, ...
    'randomSeed',42,'randomHoldMaxSeconds',120,'trainGrid',12:4:40, ...
    'dwellGrid',0:6:30,'probabilityGrid',0:0.1:1, ...
    'heatTrainGrid',12:4:40,'heatSpeedRequestedKmh',[36:7.2:79.2 80], ...
    'criticalDepartureTolerance',1,'criticalScan',1:40, ...
    'stationDetector',1,'maximumInputKmh',80,'runsPerSetting',1, ...
    'createdBerlin',string(datetime('now','TimeZone','Europe/Berlin')), ...
    'matlabVersion',string(version));
writeJson(fullfile(output,'versuchsplan.json'),plan);
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.displayMode = "Geografischer Streckenverlauf";
c.motionModel = "Beschleunigen und Bremsen";
c.blockMode = "OSM-Signalabschnitte";
c.blockLengthMeters = 500;
c.dwellMode = "GTFS-Stationshalte";
c.durationMinutes = plan.warmupMinutes+plan.measurementMinutes;
c.framePauseSeconds = 0.05; c.displayEvery = 10; c.animate = false;
c.initialPhaseSearch = true; c.randomSeed = plan.randomSeed;
c.randomBrakeEnabled = true; c.randomStopEnabled = true;
c.randomStopMinSeconds = 0; c.randomStopMaxSeconds = plan.randomHoldMaxSeconds;
c.anticipationBeta = plan.beta;
writeJson(fullfile(output,'basiskonfiguration.json'),c);
% Quellstand der tatsächlich verwendeten Modellfunktionen und Auswertung sichern.
snapshot = fullfile(output,'quellstand'); if ~isfolder(snapshot), mkdir(snapshot); end
copyfile(fullfile(root,'modell','+sbahn2'),fullfile(snapshot,'+sbahn2'));
copyfile(mfilename('fullpath')+".m",snapshot);
copyfile(fullfile(root,'trafic_flow_study_metrics.m'),snapshot);
indexFile = fullfile(output,'laufverzeichnis.csv');
allRuns = table(); cache = containers.Map('KeyType','char','ValueType','any');
if isfile(indexFile)
    allRuns = readtable(indexFile,'TextType','string');
    for previous = 1:height(allRuns)
        cache(char(allRuns.key(previous))) = allRuns(previous,:);
    end
end
fprintf('Ausgabeordner: %s\n',output);
critical = table(); criticalScans = table();
for anticipation = [false true]
    mode = "ohne_abbremsen"; if anticipation, mode = "mit_abbremsen"; end
    scan = table();
    fprintf('Grenzsuche: %s, N=1 bis 40.\n',mode);
    for trainCount = plan.criticalScan
        entry = runCase(anticipation,trainCount,80,0,0);
        scan = [scan;entry]; %#ok<AGROW>
    end
    matching = scan.passed & scan.free_match;
    boundary = max(scan.train_count(matching));
    assert(~isempty(boundary),'TrafficStudy:NoReferencePoint','Kein freier Referenzpunkt gefunden.');
    % Falls der gesamte angeforderte Bereich frei ist, oberhalb 40 weitersuchen.
    if boundary == 40
        for trainCount = 41:117
            entry = runCase(anticipation,trainCount,80,0,0);
            scan = [scan;entry]; %#ok<AGROW>
            if entry.passed && entry.free_match
                boundary = trainCount;
            else
                break
            end
        end
    end
    probabilityTrains = max(1,round(0.6*boundary));
    critical = [critical;table(anticipation,boundary,probabilityTrains, ...
        'VariableNames',{'anticipation','critical_trains','probability_trains'})]; %#ok<AGROW>
    criticalScans = [criticalScans;scan]; %#ok<AGROW>
    writetable(critical,fullfile(output,'grenzzugzahlen.csv'));
    writetable(criticalScans,fullfile(output,'grenzsuche.csv'));
    fprintf('Grenzzugzahl %s: N=%g; Störungsserie mit N=%g.\n',mode,boundary,probabilityTrains);
    series = table();
    for trainCount = plan.trainGrid
        entry = runCase(anticipation,trainCount,80,0,0);
        entry.x = trainCount; series = [series;entry]; %#ok<AGROW>
    end
    writetable(series,fullfile(output,"zugzahl_"+mode+".csv"));
    series = table();
    for extra = plan.dwellGrid
        entry = runCase(anticipation,boundary,80,extra,0);
        entry.x = extra; series = [series;entry]; %#ok<AGROW>
    end
    writetable(series,fullfile(output,"haltezeit_"+mode+".csv"));
    series = table();
    for probability = plan.probabilityGrid
        entry = runCase(anticipation,probabilityTrains,80,0,probability);
        entry.x = probability; series = [series;entry]; %#ok<AGROW>
    end
    writetable(series,fullfile(output,"stoerung_"+mode+".csv"));
end
[~,indices] = unique(floor(plan.heatSpeedRequestedKmh/3.6+1e-10),'stable');
speeds = plan.heatSpeedRequestedKmh(indices);
heat = table();
fprintf('Heatmap: %g Kombinationen.\n',numel(speeds)*numel(plan.heatTrainGrid));
for trainCount = plan.heatTrainGrid
    for speed = speeds
        heat = [heat;runCase(true,trainCount,speed,0,0)]; %#ok<AGROW>
    end
end
writetable(heat,fullfile(output,'heatmap.csv'));
save(fullfile(output,'studie.mat'),'plan','critical','criticalScans','heat','allRuns','-v7');
writeJson(fullfile(output,'abschluss.json'),struct( ...
    'uniqueRuns',height(allRuns),'successfulRuns',nnz(allRuns.passed), ...
    'failedRuns',nnz(~allRuns.passed),'heatmapPoints',height(heat), ...
    'metricsTestPassed',true,'complete',true));
fprintf('Fertig: %g unterschiedliche Konfigurationen, %g erfolgreich.\n', ...
    height(allRuns),nnz(allRuns.passed));

    function entry = runCase(anticipation,trains,speed,extra,probability)
        key = sprintf('a%d_n%d_v%.12g_d%d_p%.12g',anticipation,trains,speed,extra,probability);
        if isKey(cache,key), entry = cache(key); return; end
        config = c;
        config.anticipationEnabled = anticipation; config.trainCount = trains;
        config.cruiseSpeedKmh = speed; config.dwellOffsetSeconds = extra;
        config.randomBrakeProbability = probability; config.randomStopProbability = probability;
        file = sprintf('lauf_%04d.mat',height(allRuns)+1);
        began = tic; passed = false; failure = "";
        metric = emptyMetrics;
        phase = NaN; effective = floor(speed/3.6+1e-10)*3.6;
        try
            [G,p,report] = sbahn2.simulate(config);
            [metric,lapSamples] = trafic_flow_study_metrics(G,p,plan.warmupMinutes*60,plan.measurementMinutes*60);
            phase = p.initialPhaseShiftSeconds; effective = p.driveSpeedKmh;
            passed = report.checksPassed && metric.detector_check_passed;
            save(fullfile(runFolder,file),'G','p','report','metric','lapSamples','config','-v7');
        catch exception
            failure = string(exception.identifier)+": "+string(exception.message);
            save(fullfile(runFolder,file),'config','failure');
        end
        durationSeconds = toc(began);
        expectedCount = metric.free_throughput_trains_per_h*plan.measurementMinutes/60;
        deficit = expectedCount-metric.departure_count;
        match = passed && deficit <= plan.criticalDepartureTolerance+1e-9;
        entry = table(string(key),anticipation,trains,speed,effective,extra,probability, ...
            metric.throughput_trains_per_h,metric.free_throughput_trains_per_h, ...
            metric.departure_count,deficit,match,metric.blocked_s_per_train_lap, ...
            metric.complete_lap_count,metric.trains_with_complete_laps, ...
            metric.mean_complete_lap_s,metric.blocked_train_s_measurement, ...
            metric.free_lap_s,phase,passed,failure,string(file),durationSeconds, ...
            'VariableNames',{'key','anticipation','train_count','requested_kmh','effective_kmh', ...
            'extra_dwell_s','probability','throughput_trains_per_h','free_throughput_trains_per_h', ...
            'departure_count','departure_deficit','free_match','blocked_s_per_train_lap', ...
            'complete_lap_count','trains_with_complete_laps','mean_complete_lap_s', ...
            'blocked_train_s_measurement','free_lap_s','phase_shift_s','passed','failure','file','elapsed_s'});
        allRuns = [allRuns;entry]; cache(key) = entry;
        writetable(allRuns,indexFile);
        fprintf('%3g: %s | Q=%.3f | blockiert=%.3f s/(Zug Umlauf) | %s | %.1f s\n', ...
            height(allRuns),key,entry.throughput_trains_per_h,entry.blocked_s_per_train_lap, ...
            string(passed),durationSeconds);
    end
end

function metric = emptyMetrics
names = {'throughput_trains_per_h','free_throughput_trains_per_h','departure_count', ...
    'blocked_s_per_train_lap','complete_lap_count','trains_with_complete_laps', ...
    'mean_complete_lap_s','blocked_train_s_measurement','free_lap_s'};
for index = 1:numel(names), metric.(names{index}) = NaN; end
end

function writeJson(path,value)
fid = fopen(path,'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
