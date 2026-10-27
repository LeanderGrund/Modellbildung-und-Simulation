function results = run_sbahn2
%RUN_SBAHN2 Aufgaben 1 und 2 vollständig und reproduzierbar auswerten.
% Aufruf aus einem beliebigen Verzeichnis: run_sbahn2 (Projekt im Pfad).
% Keine Zufallseinflüsse: je Einstellung ein deterministischer Lauf.
root = fileparts(mfilename('fullpath'));
oldPath = path;
restorePath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(root,fullfile(root,'modell'));
out = fullfile(root,'ergebnisse');
if ~isfolder(out), mkdir(out); end
raw = fullfile(out,'laeufe');
if ~isfolder(raw), mkdir(raw); end
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.motionModel = "Beschleunigen und Bremsen";
c.dwellMode = "GTFS-Stationshalte";
c.blockMode = "Gleichmäßige Blockabschnitte";
c.blockLengthMeters = 500;
c.animate = false;
c.targetStopEnabled = false;
c.randomStopEnabled = false;
c.closureEnabled = false;
warmup = 3600;
measurement = 10800;
c.durationMinutes = (warmup+measurement)/60;

%% Vergleichsgrößen vor der Kalibrierung festlegen (keine Nachoptimierung).
plan = struct('calibrationMetric','Abfahrt Beusselstrasse bis Rueckkehrankunft [s]', ...
    'validationMetric','27 Abschnittsfahrzeiten: Abfahrt bis naechste Ankunft [s]', ...
    'objective','Minimiere absoluten Fehler der Abfahrt-Rueckkehr-Zeit', ...
    'candidateSpeedLevelsMps',14:22,'fixedDwell','GTFS-Stationsmediane 14.10.2026', ...
    'warmupSeconds',warmup,'measurementSeconds',measurement, ...
    'detector','Abfahrten an Station 1 im halboffenen Messintervall [3600,14400)', ...
    'stochasticInfluences',false,'runsPerSetting',1);
writeJSON(fullfile(out,'versuchsplan.json'),plan);
referenceFile = fullfile(c.dataFolder,'processed','s41_example_timetable.csv');
referenceOptions = detectImportOptions(referenceFile,'TextType','string');
referenceOptions = setvartype(referenceOptions,{'arrival_time','departure_time'},'string');
reference = readtable(referenceFile,referenceOptions);
segments = readtable(fullfile(c.dataFolder,'processed','s41_example_segments.csv'), ...
    'TextType','string');
target = seconds(duration(reference.arrival_time(end),'InputFormat','hh:mm:ss') - ...
    duration(reference.departure_time(1),'InputFormat','hh:mm:ss'));
assert(target == 3558 && height(segments) == 27,'SBahn2:Reference','Unerwarteter Referenzdatensatz.');

%% Aufgabe 1: effektive Geschwindigkeitsgrenze in diskreten Stufen kalibrieren.
calConfig = c;
calConfig.trainCount = 1;
calConfig.durationMinutes = 130;
calibration = table();
for speed = plan.candidateSpeedLevelsMps
    calConfig.cruiseSpeedKmh = speed*3.6;
    [p,~] = sbahn2.prepare(calConfig);
    prediction = p.expectedLapSeconds-p.stationDwellSeconds(1);
    calibration = [calibration; table(speed,p.driveSpeedKmh,prediction,target,abs(prediction-target), ...
        'VariableNames',{'speed_mps','speed_kmh','model_departure_return_s', ...
        'reference_departure_return_s','absolute_error_s'})]; %#ok<AGROW>
end
[~,best] = min(calibration.absolute_error_s);
c.cruiseSpeedKmh = calibration.speed_kmh(best);
writetable(calibration,fullfile(out,'kalibrierung.csv'));
validation = table();
referenceSummary = table();
sanities = table();
for stage = ["vorher","kalibriert"]
    calConfig.cruiseSpeedKmh = 80;
    if stage == "kalibriert", calConfig.cruiseSpeedKmh = c.cruiseSpeedKmh; end
    fprintf('Referenzvergleich: %s\n',stage);
    [G,p,report] = sbahn2.simulate(calConfig);
    checks = sanity_check(G,p,report);
    sanities = [sanities; checkRow("referenz_"+stage,checks)]; %#ok<AGROW>
    save(fullfile(raw,"referenz_"+stage+".mat"),'G','p','report','checks','-v7');
    assert(isequal(string(reference.gtfs_parent_station_id(1:27)), ...
        p.route.gtfsParentStationIds(:)),'SBahn2:StationAlignment','Referenzstationen nicht deckungsgleich.');
    drive = segmentTimes(p);
    prediction = p.expectedLapSeconds-p.stationDwellSeconds(1);
    firstDeparture = p.state.departureLog(find(p.state.departureLog(:,3) == 1,1),1);
    returnArrival = p.state.arrivalLog(find(p.state.arrivalLog(:,3) == 1 & ...
        p.state.arrivalLog(:,1) > firstDeparture,1),1);
    assert(returnArrival-firstDeparture == prediction,'SBahn2:LapConvention', ...
        'Abfahrt-Rueckkehr-Zeit wurde mit einer anderen Umlaufdefinition verwechselt.');
    assert(sum(drive)+sum(p.stationDwellSeconds(2:end)) == prediction, ...
        'SBahn2:TimeBalance','Fahr- und Haltezeiten ergeben nicht die Referenz-Umlaufdefinition.');
    errors = drive-segments.planned_drive_seconds;
    referenceSummary = [referenceSummary; table(stage,p.driveSpeedKmh,prediction,target, ...
        prediction-target,100*(prediction-target)/target,mean(abs(errors)),sqrt(mean(errors.^2)), ...
        'VariableNames',{'stage','speed_kmh','model_departure_return_s','reference_s', ...
        'error_s','error_percent','segment_mae_s','segment_rmse_s'})]; %#ok<AGROW>
    rows = table(repmat(stage,27,1),segments.segment_sequence,segments.from_station, ...
        segments.to_station,segments.planned_drive_seconds,drive,errors, ...
        'VariableNames',{'stage','segment','from_station','to_station','reference_drive_s','model_drive_s','error_s'});
    validation = [validation;rows]; %#ok<AGROW>
end
writetable(referenceSummary,fullfile(out,'referenzvergleich.csv'));
writetable(validation,fullfile(out,'abschnittsvalidierung.csv'));

%% Aufgabe 2a: Zugzahl; gleiche Strecke, Blöcke und stationsabhängige Halte.
trainStudy = table();
for n = [4 8 12 16 20 24 28 32 36 40]
    config = c; config.trainCount = n;
    name = "zugzahl_"+compose('%02d',n);
    fprintf('Zugzahlstudie: N=%d\n',n);
    [G,p,report] = sbahn2.simulate(config);
    checks = sanity_check(G,p,report);
    metrics = evaluateRun(G,p,warmup,measurement);
    trainStudy = [trainStudy;struct2table(metrics)]; %#ok<AGROW>
    sanities = [sanities;checkRow(name,checks)]; %#ok<AGROW>
    save(fullfile(raw,name+".mat"),'G','p','report','checks','metrics','-v7');
    if n == 40
        tracePosition = G.position;
        traceVelocity = G.velocity;
        traceWait = G.waitSteps;
        traceBlocked = G.blocked;
        traceTime = G.timeSeconds;
        stationCells = p.route.stationCells;
        stationNames = p.route.stationNames;
        cellCount = p.cellCount;
        save(fullfile(out,'raumzeit.mat'),'tracePosition','traceVelocity','traceWait', ...
            'traceBlocked','traceTime','stationCells','stationNames','cellCount','-v7');
    end
end
writetable(trainStudy,fullfile(out,'zugzahlstudie.csv'));

%% Aufgabe 2b: mittlere Haltezeit; einheitliche Halte isolieren den Mittelwert.
% N=36 ist aus der ersten Studie als Bereich mit beginnender Sättigung gewählt.
% Die Uniformität ist ein eigener kontrollierter Versuch: GTFS-Profilvergleich
% nicht mit einer reinen Änderung des Mittelwerts verwechseln.
dwellStudy = table();
for h = [15 20 25 30 34 40 50 60]
    config = c; config.trainCount = 36;
    config.dwellMode = "Einheitlich"; config.stopSeconds = h;
    name = "haltezeit_"+compose('%02d',h);
    fprintf('Haltezeitstudie: h=%d s, N=36\n',h);
    [G,p,report] = sbahn2.simulate(config);
    checks = sanity_check(G,p,report);
    metrics = evaluateRun(G,p,warmup,measurement);
    dwellStudy = [dwellStudy;struct2table(metrics)]; %#ok<AGROW>
    sanities = [sanities;checkRow(name,checks)]; %#ok<AGROW>
    save(fullfile(raw,name+".mat"),'G','p','report','checks','metrics','-v7');
end
writetable(dwellStudy,fullfile(out,'haltezeitstudie.csv'));
writetable(sanities,fullfile(out,'sanity_checks.csv'));

%% Aktualisierte Parameter und kompakte Ergebnisse maschinenlesbar sichern.
[p,~] = sbahn2.prepare(c);
parameters = struct('source','Woche 1/NaSch-SBahn, lokale Weiterfuehrung +sbahn2', ...
    'route','S41, OSM 14.10.2026','lengthMeters',p.route.lengthMeters, ...
    'sourceLengthMeters',p.route.sourceLengthMeters,'stationCount',p.stationCount, ...
    'dxMeters',p.dxMeters,'dtSeconds',p.stepSeconds,'trainLengthMeters',p.trainLengthMeters, ...
    'baseTrainCount',c.trainCount,'speedSafetyLimitKmh',80, ...
    'cruiseSpeedKmhBefore',79.2,'cruiseSpeedKmhAfter',p.driveSpeedKmh, ...
    'accelerationMps2',1,'brakingMps2',1, ...
    'dwellMeanSeconds',mean(p.stationDwellSeconds),'dwellMinSeconds',min(p.stationDwellSeconds), ...
    'dwellMaxSeconds',max(p.stationDwellSeconds),'dwellSumSeconds',sum(p.stationDwellSeconds), ...
    'blockTargetMeters',c.blockLengthMeters,'blockCount',numel(p.blocks.startCells), ...
    'blockMinMeters',min(p.blocks.lengthMeters),'blockMaxMeters',max(p.blocks.lengthMeters), ...
    'freeArrivalLapSeconds',p.expectedLapSeconds,'warmupSeconds',warmup, ...
    'measurementSeconds',measurement,'randomInfluences',false,'runsPerSetting',1);
writeJSON(fullfile(out,'parameter.json'),parameters);
results = struct('parameters',parameters,'plan',plan,'calibration',calibration, ...
    'reference',referenceSummary,'validation',validation,'trainStudy',trainStudy, ...
    'dwellStudy',dwellStudy,'sanityChecks',sanities);
save(fullfile(out,'auswertung.mat'),'results','-v7');
disp(referenceSummary); disp(trainStudy); disp(dwellStudy);
fprintf('Fertig: %d Laeufe, alle Sanity Checks bestanden. Ergebnisse: %s\n',height(sanities),out);
end

function drive = segmentTimes(p)
drive = zeros(p.stationCount,1);
for station = 1:p.stationCount
    departure = p.state.departureLog(find(p.state.departureLog(:,3) == station,1),1);
    next = mod(station,p.stationCount)+1;
    arrival = p.state.arrivalLog(find(p.state.arrivalLog(:,3) == next & ...
        p.state.arrivalLog(:,1) > departure,1),1);
    assert(~isempty(departure) && ~isempty(arrival),'SBahn2:IncompleteSegment','Unvollständiger Abschnitt.');
    drive(station) = arrival-departure;
end
end

function metrics = evaluateRun(G,p,warmup,measurement)
startTimes = G.timeSeconds(1:end-1);
selected = startTimes >= warmup & startTimes < warmup+measurement;
departures = p.state.departureLog;
detected = sort(departures(departures(:,3) == 1 & departures(:,1) >= warmup & ...
    departures(:,1) < warmup+measurement,1));
blocked = G.blocked(2:end,:);
signal = G.signalBlocked(2:end,:);
speed = G.velocity(2:end,:);
headways = diff(detected);
hours = measurement/3600;
metrics = struct('train_count',p.trainCount,'mean_dwell_s',mean(p.stationDwellSeconds), ...
    'throughput_trains_per_h',numel(detected)/hours, ...
    'free_throughput_trains_per_h',3600*p.trainCount/p.expectedLapSeconds, ...
    'detected_departures',numel(detected), ...
    'blocked_train_s',nnz(blocked(selected,:))*p.stepSeconds, ...
    'signal_blocked_train_s',nnz(signal(selected,:))*p.stepSeconds, ...
    'blocked_s_per_train_h',nnz(blocked(selected,:))*p.stepSeconds/(p.trainCount*hours), ...
    'mean_speed_kmh',mean(speed(selected,:),'all')*p.speedUnitKmh, ...
    'mean_headway_s',mean(headways),'headway_std_s',std(headways), ...
    'free_lap_s',p.expectedLapSeconds,'warmup_s',warmup,'measurement_s',measurement);
assert(metrics.throughput_trains_per_h == metrics.detected_departures/hours, ...
    'SBahn2:ThroughputUnit','Durchsatz wurde nicht in Zügen pro Stunde berechnet.');
end

function row = checkRow(name,checks)
row = addvars(struct2table(checks),name,'Before',1,'NewVariableNames','run');
end

function writeJSON(file,value)
fid = fopen(file,'w','n','UTF-8');
assert(fid >= 0,'SBahn2:Output','Ausgabedatei nicht geöffnet.');
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
