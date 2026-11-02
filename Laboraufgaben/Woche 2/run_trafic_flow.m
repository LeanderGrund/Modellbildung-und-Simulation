function result = run_trafic_flow(settings,runtime)
%RUN_TRAFIC_FLOW Einzellauf oder Verkehrsstromuntersuchung ausführen/speichern.
% SETTINGS: siehe trafic_flow_defaults. RUNTIME nur für automatisierte Läufe:
% animate=false unterdrückt die Wiedergabe, nicht den geografischen Endzustand.
arguments
    settings (1,1) struct = trafic_flow_defaults
    runtime.animate (1,1) logical = true
    runtime.makeFigures (1,1) logical = true
    runtime.outputFolder (1,1) string = ""
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'modell'));
settings = validatedSettings(settings);
if runtime.outputFolder == ""
    stamp = string(datetime('now','TimeZone','Europe/Berlin','Format','yyyyMMdd_HHmmss_SSS'));
    mode = "einzellauf";
    if settings.study, mode = "verkehrsstrom"; end
    runtime.outputFolder = fullfile(root,'ergebnisse','trafic_flow',stamp+"_"+mode);
end
out = runtime.outputFolder;
assert(~isfolder(out) || isempty(dir(fullfile(out,'*.mat'))), ...
    'TrafficFlow:ExistingRun','Dieser Ordner enthält bereits einen gespeicherten Lauf.');
if ~isfolder(out), mkdir(out); end
diagrams = fullfile(out,'grafiken');
if ~isfolder(diagrams), mkdir(diagrams); end
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.displayMode = "Geografischer Streckenverlauf";
c.motionModel = "Beschleunigen und Bremsen";
c.blockMode = "OSM-Signalabschnitte";
c.blockLengthMeters = 500; % Bei OSM wirkungslos, nur dokumentierter Parameter.
c.dwellMode = "GTFS-Stationshalte";
c.cruiseSpeedKmh = 80;
c.framePauseSeconds = 0.05;
c.displayEvery = 10;
c.initialPhaseSearch = true;
c.durationMinutes = settings.warmupMinutes+settings.measurementMinutes;
c.randomBrakeEnabled = true;
c.randomBrakeProbability = settings.probability;
c.randomStopEnabled = true;
c.randomStopProbability = settings.probability;
c.randomStopMinSeconds = 0;
c.randomStopMaxSeconds = settings.randomHoldMaxSeconds;
c.anticipationEnabled = settings.anticipationEnabled;
c.anticipationBeta = settings.beta;
c.dwellOffsetSeconds = double(settings.extraWaitEnabled)*settings.extraWaitSeconds;
c.randomSeed = settings.randomSeed;
c.animate = runtime.animate && runtime.makeFigures && ~settings.study;
result = struct('settings',settings,'outputFolder',out,'baseConfig',c);
figures = gobjects(0);
if ~settings.study
    c.trainCount = settings.trainCount;
    previousFigures = findall(groot,'Type','figure');
    [G,p,report] = sbahn2.simulate(c);
    metrics = measure(G,p,settings);
    result.G = G; result.p = p; result.report = report; result.metrics = metrics;
    result.comparison = sbahn2.compareTimetable(p);
    if runtime.makeFigures
        figures = setdiff(findall(groot,'Type','figure'),previousFigures);
        if isempty(figures), figures(end+1) = sbahn2.plotSnapshot(p); end
        figures(end+1) = sbahn2.plotResults(G,p);
        figures(end+1) = sbahn2.plotDynamics(G,p);
        figures(end+1) = sbahn2.plotMeanSpeed(G,p);
    end
    result.tables = singleTables(G,p,report,metrics,result.comparison,settings);
    tableNames = fieldnames(result.tables);
    for k = 1:numel(tableNames)
        name = tableNames{k};
        if ismember(name,{'stationsereignisse','blockeinfahrten'})
            disp(result.tables.(name)(1:min(20,height(result.tables.(name))),:));
        else
            disp(result.tables.(name));
        end
        writetable(result.tables.(name),fullfile(out,[name '.csv']));
    end
    fprintf('Modellprüfungen bestanden. Durchsatz nach Einschwingen: %.3f Züge/h.\n', ...
        metrics.throughputTrainsPerHour);
    fprintf('Blockgrundlage: %s\nHaltezeitquelle: %s\n',p.blocks.source,p.dwellSource);
    fprintf('Bestanden: konstante Zugzahl, freie Zugkörper, exklusive Blockbelegung, kein Überholen.\n');
    fprintf('Stationsreihenfolge, Mindesthalte, Bremsreserven und Beschleunigungsgrenzen geprüft.\n');
    fprintf('Größte Stationsrundung: %g m. Streckengrundlage: %s\n', ...
        report.maxStationRoundingMeters,p.route.source);
else
    % Unterschiedliche Eingaben derselben Rasterstufe werden nur einmal simuliert.
    requested = inclusiveRange(settings.speedMinimumKmh,settings.speedStepKmh,settings.speedMaximumKmh);
    levels = floor(requested/3.6+1e-10);
    [levels,indices] = unique(levels,'stable');
    requested = requested(indices);
    effective = levels*3.6;
    trains = inclusiveRange(settings.trainMinimum,settings.trainStep,settings.trainMaximum);
    throughput = nan(numel(trains),numel(levels));
    runs = table();
    runFolder = fullfile(out,'laeufe'); mkdir(runFolder);
    for row = 1:numel(trains)
        for column = 1:numel(levels)
            c.trainCount = trains(row);
            c.cruiseSpeedKmh = requested(column);
            c.animate = false;
            passed = false; failure = ""; detected = NaN;
            file = sprintf('n_%03d_v_%02d.mat',trains(row),levels(column));
            try
                [G,p,report] = sbahn2.simulate(c);
                metrics = measure(G,p,settings);
                throughput(row,column) = metrics.throughputTrainsPerHour;
                detected = metrics.departureCount;
                passed = report.checksPassed;
                save(fullfile(runFolder,file),'G','p','report','metrics','settings','-v7');
            catch exception
                failure = string(exception.identifier)+": "+string(exception.message);
                % Unzulässige Belegungen sind keine gemessenen Null-Durchsätze.
                save(fullfile(runFolder,file),'c','failure','settings');
            end
            runs = [runs;table(requested(column),effective(column),trains(row), ...
                throughput(row,column),detected,passed,failure,string(file), ...
                'VariableNames',{'requested_kmh','effective_kmh','train_count', ...
                'throughput_trains_per_h','departure_count','passed','failure','file'})]; %#ok<AGROW>
        end
    end
    result.effectiveSpeedsKmh = effective;
    result.trainCounts = trains;
    result.throughput = throughput;
    result.runs = runs;
    writetable(runs,fullfile(out,'verkehrsstrom.csv'));
    if runtime.makeFigures
        figures = figure('Name','Verkehrsstromuntersuchung','Color','w','Position',[100 100 950 570]);
        ax = axes(figures);
        chart = imagesc(ax,1:numel(effective),1:numel(trains),throughput);
        chart.AlphaData = isfinite(throughput);
        ax.Color = [0.8 0.8 0.8]; ax.YDir = 'normal';
        ax.XTick = 1:numel(effective); ax.XTickLabel = compose('%.1f',effective);
        ax.YTick = 1:numel(trains); ax.YTickLabel = string(trains);
        xlabel(ax,'Effektive Maximalgeschwindigkeit [km/h]');
        ylabel(ax,'Anzahl der Züge');
        colormap(ax,parula);
        cb = colorbar(ax); cb.Label.String = 'Durchschnittlicher Durchsatz [Züge/h]';
        title(ax,{'Verkehrsstrom nach der Einschwingzeit', ...
            sprintf('Einschwingen %g min | Messung %g min | p = %g | Antizipation %s', ...
            settings.warmupMinutes,settings.measurementMinutes,settings.probability, ...
            string(settings.anticipationEnabled))});
        if numel(throughput) <= 100
            for row = 1:numel(trains)
                for column = 1:numel(effective)
                    value = throughput(row,column);
                    label = sprintf('%.2f',value);
                    if isnan(value), label = 'ungültig'; end
                    text(ax,column,row,label,'HorizontalAlignment','center', ...
                        'Color','k','BackgroundColor','w','Margin',1,'FontSize',9);
                end
            end
        end
    end
end
% Ausschließlich die zu diesem Lauf gehörenden Figuren speichern.
for k = 1:numel(figures)
    sbahn2.styleFigure(figures(k));
    name = sprintf('%02d_%s',k,regexprep(figures(k).Name,'[^a-zA-Z0-9]','_'));
    exportgraphics(figures(k),fullfile(diagrams,[name '.png']), ...
        'Resolution',160,'BackgroundColor','white');
    savefig(figures(k),fullfile(diagrams,[name '.fig']));
end
result.figureCount = numel(figures);
save(fullfile(out,'ergebnis.mat'),'result','-v7');
writeJson(fullfile(out,'parameter.json'),struct('settings',settings,'baseConfig',result.baseConfig));
writeRunNote(result);
result.figures = figures; % Handles gehören nicht in die gespeicherte MAT-Datei.
end

function settings = validatedSettings(input)
settings = trafic_flow_defaults;
names = fieldnames(input);
assert(all(ismember(names,fieldnames(settings))),'TrafficFlow:Setting','Unbekannte Einstellung.');
for k = 1:numel(names), settings.(names{k}) = input.(names{k}); end
for name = ["study","anticipationEnabled","extraWaitEnabled"]
    validateattributes(settings.(name),{'logical'},{'scalar'});
end
for name = ["trainCount","trainMinimum","trainMaximum","trainStep"]
    validateattributes(settings.(name),{'numeric'},{'scalar','real','finite','integer','positive'});
end
for name = ["randomHoldMaxSeconds","extraWaitSeconds","randomSeed"]
    validateattributes(settings.(name),{'numeric'},{'scalar','real','finite','integer','nonnegative'});
end
validateattributes(settings.randomSeed,{'numeric'},{'<=',2^32-1});
validateattributes(settings.warmupMinutes,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(settings.measurementMinutes,{'numeric'},{'scalar','real','finite','positive'});
assert(all(abs([settings.warmupMinutes settings.measurementMinutes]*60- ...
    round([settings.warmupMinutes settings.measurementMinutes]*60)) < 1e-8), ...
    'TrafficFlow:TimeGrid','Einschwingzeit und Messdauer müssen ganze Sekunden ergeben.');
validateattributes(settings.probability,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
validateattributes(settings.beta,{'numeric'},{'scalar','real','finite','positive'});
for name = ["speedMinimumKmh","speedMaximumKmh"]
    validateattributes(settings.(name),{'numeric'},{'scalar','real','finite','>=',3.6,'<=',80});
end
validateattributes(settings.speedStepKmh,{'numeric'},{'scalar','real','finite','positive'});
assert(settings.speedMinimumKmh <= settings.speedMaximumKmh && ...
    settings.trainMinimum <= settings.trainMaximum,'TrafficFlow:Range','Bereichsgrenzen sind vertauscht.');
end

function values = inclusiveRange(first,step,last)
values = first:step:last;
if abs(values(end)-last) > 1e-9, values(end+1) = last; end
end

function metrics = measure(G,p,s)
start = s.warmupMinutes*60; finish = start+s.measurementMinutes*60;
departures = p.state.departureLog;
detected = departures(:,3) == 1 & departures(:,1) >= start & departures(:,1) < finish;
rows = G.timeSeconds >= start & G.timeSeconds < finish;
metrics = struct('departureCount',nnz(detected), ...
    'throughputTrainsPerHour',nnz(detected)/(s.measurementMinutes/60), ...
    'warmupSeconds',start,'measurementSeconds',finish-start, ...
    'meanSpeedKmh',mean(G.velocity(rows,:),'all')*p.speedUnitKmh, ...
    'blockedTrainSeconds',sum(G.blocked(find(rows)+1,:),'all')*p.stepSeconds);
end

function tables = singleTables(G,p,r,m,comparison,s)
tables.parameter = table( ...
    ["Streckengrundlage";"Darstellung";"Fahrmodell";"Blocksteuerung";"Zielblockabstand"; ...
    "Haltezeitmodell";"Maximalgeschwindigkeit Eingabe";"Maximalgeschwindigkeit effektiv"; ...
    "Bildpause";"Bildabstand";"Züge";"Einschwingzeit";"Messdauer";"p"; ...
    "Störungszeitspanne";"Langsames Abbremsen";"Beta";"Zusätzliche Wartezeit";"Fester Zuschlag"; ...
    "Zufallsstartwert";"Blockanzahl";"Zuglänge";"Raster";"Freier Referenzumlauf";"Freie Referenzzugfolge"], ...
    [p.config.trackMode;p.config.displayMode;p.config.motionModel;p.config.blockMode; ...
    "500 m; bei OSM ohne Wirkung";p.config.dwellMode;"80 km/h"; ...
    string(p.driveSpeedKmh)+" km/h";"0.05 s";"10 Schritte";string(p.trainCount); ...
    string(s.warmupMinutes)+" min";string(s.measurementMinutes)+" min";string(s.probability); ...
    "0 bis "+string(s.randomHoldMaxSeconds)+" s";string(s.anticipationEnabled);string(s.beta)+" 1/s"; ...
    string(s.extraWaitEnabled);string(p.config.dwellOffsetSeconds)+" s";string(s.randomSeed); ...
    string(r.blockCount);string(p.effectiveTrainLengthMeters)+" m";"1 m / 1 s"; ...
    string(p.expectedLapSeconds/60)+" min";string(p.expectedHeadwaySeconds/60)+" min"], ...
    'VariableNames',{'Parameter','Wert'});
tables.parameter = [tables.parameter;table( ...
    ["Blocklängen min–max";"Stationshalte min–max";"Simulationsdauer gesamt"; ...
    "Animation";"Streckenlänge";"Beschleunigung / Bremsverzögerung"; ...
    "Rundung der Ringlänge";"Größte Stationsrundung"], ...
    [compose('%g–%g m',min(p.blocks.lengthMeters),max(p.blocks.lengthMeters)); ...
    compose('%g–%g s',min(p.stationDwellSeconds),max(p.stationDwellSeconds)); ...
    string(p.config.durationMinutes)+" min";string(p.config.animate); ...
    compose('%.4f km',p.route.lengthMeters/1000);"1 / 1 m/s²"; ...
    string(p.route.lengthMeters-p.route.sourceLengthMeters)+" m"; ...
    string(r.maxStationRoundingMeters)+" m"], ...
    'VariableNames',{'Parameter','Wert'})];
tables.kennzahlen = table( ...
    ["Durchsatz nach Einschwingen [Züge/h]";"Gezählte Abfahrten im Messfenster"; ...
    "Gemessener Umlauf gesamt [min]";"Gemessene Zugfolge gesamt [min]";"Gemessener Stationshalt gesamt [s]"; ...
    "Höchste Geschwindigkeitsstufe [km/h]";"Gemessene Höchstgeschwindigkeit [km/h]"; ...
    "Mittlere Geschwindigkeit gesamt [km/h]";"Mittlere Geschwindigkeit Messfenster [km/h]"; ...
    "Blockierte Zugsekunden gesamt";"Davon vor belegtem Block";"Maximal gleichzeitig blockiert"], ...
    [m.throughputTrainsPerHour;m.departureCount;r.meanLapSeconds/60;r.meanHeadwaySeconds/60; ...
    r.meanDwellSeconds;r.driveSpeedKmh;r.maxObservedSpeedKmh;r.meanSpeedKmh;m.meanSpeedKmh; ...
    r.blockedTrainSeconds;r.signalBlockedTrainSeconds;r.maxSimultaneouslyBlocked], ...
    'VariableNames',{'Kennzahl','Wert'});
tables.fahrplanvergleich = table( ...
    ["GTFS-Referenz: Abfahrt bis Rückkehr [s]";"Freies Modell [s]";"Absoluter Fehler frei [s]"; ...
    "Gemessene mittlere Abfahrt bis Rückkehr [s]";"Absoluter Fehler gemessen [s]";"Vollständige Ringfahrten"], ...
    [comparison.referenceSeconds;comparison.freeModelSeconds;comparison.freeAbsoluteErrorSeconds; ...
    comparison.measuredMeanSeconds;comparison.measuredAbsoluteErrorSeconds;comparison.completedTripCount], ...
    'VariableNames',{'Fahrplanvergleich','Wert'});
tables.stationen = table((1:p.stationCount)',p.route.stationNames', ...
    (p.route.stationCells'-1)*p.dxMeters/1000,p.baseStationDwellSeconds', ...
    p.stationDwellSeconds',p.dwellSampleCounts', ...
    'VariableNames',{'Nr','Station','Position_km','GTFS_Halt_s','Geplant_mit_Zuschlag_s','Quellhalte'});
entries = p.state.blockEntryLog;
tables.stoerungen = table( ...
    ["Blockeinfahrten geprüft";"Zufallsbremsungen ausgelöst";"Bremsende Zugsekunden durch Zufallsbremsung"; ...
    "Zufällige Stationszusatzhalte mit positiver Dauer";"Zugewiesener Zufallszusatz [s]"; ...
    "Beobachteter Zusatzhalt [Zug·s]";"Geplanter Stationshalt [Zug·s]"; ...
    "Warten vor gewöhnlich belegtem Block [Zug·s]";"Bremsende Zugsekunden durch Antizipation"], ...
    [size(entries,1);nnz(entries(:,6));nnz(G.randomBrakeApplied);r.randomStopCount; ...
    r.assignedRandomSeconds;r.observedExtraHoldTrainSeconds;r.plannedHoldTrainSeconds; ...
    r.occupiedBlockTrainSeconds;anticipationSeconds(G)],'VariableNames',{'Kennzahl','Wert'});
events = p.state.stopLog;
tables.stationsereignisse = array2table(events,'VariableNames', ...
    {'Zeit_s','Zug','Station','Geplant_s','Gezielter_Zusatz_s','Zufallszusatz_s'});
tables.blockeinfahrten = array2table(entries,'VariableNames', ...
    {'Zeit_s','Zug','Block','Eintritt_mps','Bremsziel_mps','Treffer'});
% Ereignistabellen werden vollständig gespeichert, die Live-Ausgabe bleibt kurz.
end

function seconds = anticipationSeconds(G)
seconds = 0;
if isfield(G,'anticipationApplied'), seconds = nnz(G.anticipationApplied); end
end

function writeJson(path,value)
fid = fopen(path,'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end

function writeRunNote(result)
fid = fopen(fullfile(result.outputFolder,'LAUF.md'),'w','n','UTF-8'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
s = result.settings;
fprintf(fid,'# Gespeicherter trafic_flow-Lauf\n\n');
fprintf(fid,'Erstellt: %s (Europe/Berlin). MATLAB %s.\n\n', ...
    string(datetime('now','TimeZone','Europe/Berlin')),version);
fprintf(fid,'Einschwingzeit: %g min. Messdauer: %g min. p: %g. Zufallsstartwert: %g.\n\n', ...
    s.warmupMinutes,s.measurementMinutes,s.probability,s.randomSeed);
fprintf(fid,'Antizipation: %s, beta = %g 1/s. Fester GTFS-Zuschlag: %g s. Zufallszusatz: U{0,...,%g} s.\n\n', ...
    string(s.anticipationEnabled),s.beta,result.baseConfig.dwellOffsetSeconds,s.randomHoldMaxSeconds);
fprintf(fid,'Durchsatz: Abfahrten an Station 1 im halboffenen Messfenster [%g,%g) s, geteilt durch Messdauer in Stunden.\n\n', ...
    s.warmupMinutes*60,(s.warmupMinutes+s.measurementMinutes)*60);
if s.study
    fprintf(fid,'Verkehrsstromuntersuchung: %g Kombinationen, davon %g bestanden. Genau ein Lauf je Kombination.\n\n', ...
        height(result.runs),nnz(result.runs.passed));
    fprintf(fid,'CSV und MAT enthalten die Heatmapwerte. Vollständige Einzelläufe unter laeufe/. Ungültige Kombinationen sind NaN, nicht null.\n\n');
else
    fprintf(fid,'Einzellauf: %g Züge, effektiv %g km/h. Modellprüfungen bestanden: %s. Durchsatz: %.6g Züge/h.\n\n', ...
        s.trainCount,result.p.driveSpeedKmh,string(result.report.checksPassed),result.metrics.throughputTrainsPerHour);
    fprintf(fid,'Alle Kennzahlen und Ereignisse stehen in CSV; Trajektorien, Konfiguration und Endzustand in ergebnis.mat.\n\n');
end
fprintf(fid,'%g Grafiken jeweils als PNG und FIG unter grafiken/. parameter.json dokumentiert die Eingaben.\n',result.figureCount);
end
