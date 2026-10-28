function pruefe_ergebnisse
%PRUEFE_ERGEBNISSE Gespeicherte Daten und Fehlersensitivität nachprüfen.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'modell'));
out = fullfile(root,'ergebnisse');
file = fullfile(root,'..','Woche 1','NaSch-SBahn','daten', ...
    'ringbahn_2026-10-14','processed','s41_example_timetable.csv');
options = detectImportOptions(file,'TextType','string');
options = setvartype(options,{'arrival_time','departure_time'},'string');
t = readtable(file,options);
referenceSeconds = seconds(duration(t.arrival_time(end),'InputFormat','hh:mm:ss') - ...
    duration(t.departure_time(1),'InputFormat','hh:mm:ss'));
assert(referenceSeconds == 3558,'SBahn2:ReferenceImport','Referenzimport fehlerhaft.');

master = load(fullfile(out,'auswertung.mat'),'results');
draw = load(fullfile(out,'diagrammdaten.mat'),'plotData');
assert(isequaln(master.results.plotData,draw.plotData),'SBahn2:PlotExport', ...
    'Zurückgegebene und exportierte Diagrammdaten unterscheiden sich.');
data = draw.plotData;
manifest = readtable(fullfile(out,'laufverzeichnis.csv'),'TextType','string', ...
    'Delimiter',',','VariableNamingRule','preserve');
trains = readtable(fullfile(out,'zugzahlstudie.csv'),'Delimiter',',');
dwells = readtable(fullfile(out,'haltezeitstudie.csv'),'Delimiter',',');
calibration = readtable(fullfile(out,'kalibrierung.csv'),'Delimiter',',');
audit = table();
for caseIndex = 1:height(manifest)
    item = load(fullfile(out,'laeufe',manifest.file(caseIndex)));
    p = item.p; G = item.G;
    sanity_check(G,p,item.report);
    assert(isequal(p.stationDwellSeconds,p.baseStationDwellSeconds+p.config.dwellOffsetSeconds), ...
        'SBahn2:DwellProfile','Das GTFS-Profil wurde nicht gleichmäßig verschoben.');
    checked = 0;
    if isfield(item,'metrics')
        m = item.metrics;
        selected = G.timeSeconds(1:end-1) >= m.warmup_s & ...
            G.timeSeconds(1:end-1) < m.warmup_s+m.measurement_s;
        movement = mod(diff(G.position,1,1),p.cellCount);
        detector = G.position(1:end-1,:) == p.route.stationCells(1) & movement > 0;
        count = nnz(detector(selected,:));
        stopped = movement == 0 & G.waitSteps(1:end-1,:) == 0;
        assert(isequal(stopped,G.blocked(2:end,:)),'SBahn2:StoppedCounter', ...
            'Stillstand aus Position und Halteuhr passt nicht zur Blockierungsmarkierung.');
        waitSeconds = nnz(stopped(selected,:))*p.stepSeconds;
        hours = m.measurement_s/3600;
        closeEnough(m.detected_departures,count);
        closeEnough(m.throughput_trains_per_h,count/hours);
        closeEnough(m.blocked_train_s,waitSeconds);
        closeEnough(m.blocked_s_per_train_h,waitSeconds/(p.trainCount*hours));
        closeEnough(m.free_throughput_trains_per_h,3600*p.trainCount/p.expectedLapSeconds);
        if startsWith(manifest.run(caseIndex),"zugzahl_")
            index = find(trains.train_count == p.trainCount);
            csvRow = trains(index,:); curve = data.trains;
        else
            index = find(dwells.dwell_offset_s == p.config.dwellOffsetSeconds);
            csvRow = dwells(index,:); curve = data.dwell;
        end
        for name = string(fieldnames(m))'
            closeEnough(csvRow.(name),m.(name));
            checked = checked+1;
        end
        closeEnough(curve.throughput(index),count/hours);
        closeEnough(curve.blockedSecondsPerTrainHour(index),waitSeconds/(p.trainCount*hours));
        closeEnough(curve.freeThroughput(index),m.free_throughput_trains_per_h);
        closeEnough(curve.departureCount(index),count);
        checked = checked+4;
    else
        depart = p.state.departureLog;
        arrive = p.state.arrivalLog;
        first = depart(find(depart(:,3) == 1,1),1);
        returned = arrive(find(arrive(:,3) == 1 & arrive(:,1) > first,1),1);
        index = find(calibration.speed_mps == p.vmax);
        closeEnough(data.speed.xKmh(index),p.driveSpeedKmh);
        closeEnough(data.speed.modelSeconds(index),returned-first);
        closeEnough(data.speed.referenceSeconds(index),referenceSeconds);
        closeEnough(data.speed.absoluteErrorSeconds(index),abs(returned-first-referenceSeconds));
        closeEnough(calibration.model_departure_return_s(index),returned-first);
        checked = 5;
    end
    audit = [audit;table(manifest.run(caseIndex),checked,true, ...
        'VariableNames',{'run','checked_numeric_values','passed'})]; %#ok<AGROW>
end
% Der gemeinsame Betriebspunkt muss in beiden Studien bitgenau gleich sein.
train36 = load(fullfile(out,'laeufe','zugzahl_36.mat'));
zeroOffset = load(fullfile(out,'laeufe','gtfs_plus_00.mat'));
assert(isequaln(train36.G,zeroOffset.G) && isequaln(train36.metrics,zeroOffset.metrics), ...
    'SBahn2:CommonOperatingPoint','N=36 und GTFS+0 sind in den beiden Studien verschieden.');
i = data.trains.comparisonIndex; j = data.dwell.baseIndex;
closeEnough(data.trains.throughput(i),data.dwell.throughput(j));
closeEnough(data.trains.blockedSecondsPerTrainHour(i),data.dwell.blockedSecondsPerTrainHour(j));
closeEnough(data.trains.x(data.trains.baseIndex),data.meta.baseTrainCount);
[~,optimal] = min(data.speed.absoluteErrorSeconds);
assert(data.speed.bestIndex == optimal,'SBahn2:OptimalSpeed','Falscher optimaler Punkt exportiert.');
writetable(audit,fullfile(out,'diagrammwerte_pruefung.csv'));
plotValues = [plotRows("geschwindigkeitsgrenze",data.speed.xKmh, ...
    data.speed.modelSeconds,data.speed.referenceSeconds,data.speed.absoluteErrorSeconds); ...
    plotRows("zugzahl",data.trains.x,data.trains.throughput, ...
    data.trains.freeThroughput,data.trains.blockedSecondsPerTrainHour); ...
    plotRows("haltezeit",data.dwell.x,data.dwell.throughput, ...
    data.dwell.freeThroughput,data.dwell.blockedSecondsPerTrainHour)];
writetable(plotValues,fullfile(out,'diagrammwerte.csv'));

d = load(fullfile(out,'laeufe','zugzahl_40.mat'));
sanity_check(d.G,d.p,d.report);
selectedTrace = d.G.timeSeconds >= data.spaceTime.startMinute*60 & ...
    d.G.timeSeconds <= (data.spaceTime.startMinute+data.spaceTime.durationMinutes)*60;
closeEnough(data.spaceTime.positionKm,(d.G.position(selectedTrace,:)-1)*d.p.dxMeters/1000);
closeEnough(data.spaceTime.timeMinutes, ...
    (d.G.timeSeconds(selectedTrace)-data.spaceTime.startMinute*60)/60);
closeEnough(data.spaceTime.stationKm,(d.p.route.stationCells-1)*d.p.dxMeters/1000);
assert(isequal(data.spaceTime.blocked,d.G.blocked(selectedTrace,:)), ...
    'SBahn2:SpaceTimeExport','Raum-Zeit-Markierungen passen nicht zu den gespeicherten Zuständen.');
% Absichtlich verfälschte Daten müssen von den Sanity Checks erkannt werden.
wrong = d.G; wrong.velocity(2,1) = d.p.vmax+1;
expectError(@() sanity_check(wrong,d.p,d.report),'SBahn2:Speed');
wrong = d.G; wrong.position(2,1) = wrong.position(2,1)+1;
expectError(@() sanity_check(wrong,d.p,d.report),'SBahn2:Movement');

% Zeitfenster an zwei Punkten im Sättigungsbereich separat auswerten.
windows = table();
for n = [32 36 40]
    d = load(fullfile(out,'laeufe',sprintf('zugzahl_%02d.mat',n)));
    for start = [3600 7200 10800]
        log = d.p.state.departureLog;
        count = nnz(log(:,3) == 1 & log(:,1) >= start & log(:,1) < start+3600);
        selected = d.G.timeSeconds(1:end-1) >= start & d.G.timeSeconds(1:end-1) < start+3600;
        blocked = d.G.blocked(2:end,:);
        wait = nnz(blocked(selected,:))/n;
        windows = [windows;table(n,start,count,wait,'VariableNames', ...
            {'train_count','window_start_s','throughput_trains_per_h','blocked_s_per_train_h'})]; %#ok<AGROW>
    end
end
writetable(windows,fullfile(out,'messfensterkontrolle.csv'));
disp(windows);
fprintf('%d Laeufe, %d Zahlenwerte, gemeinsamer N=36-Punkt und beide Fehlerfaelle geprueft.\n', ...
    height(audit),sum(audit.checked_numeric_values));
end

function closeEnough(a,b)
assert(isequal(size(a),size(b)) && all(abs(a-b) <= 1e-10*max(1,abs(b)),'all'), ...
    'SBahn2:NumericExport','Ein Diagramm-/CSV-Wert stimmt nicht mit den Simulationsdaten ueberein.');
end

function t = plotRows(name,x,y,reference,secondary)
t = table(repmat(name,numel(x),1),x(:),y(:),reference(:),secondary(:), ...
    'VariableNames',{'diagram','x','y_primary','y_reference','y_secondary'});
end

function expectError(action,identifier)
try
    action();
catch e
    assert(strcmp(e.identifier,identifier),'SBahn2:WrongGuard','Falsche Fehlererkennung: %s.',e.identifier);
    return
end
error('SBahn2:MissingGuard','Absichtlicher Fehler wurde nicht erkannt.');
end
