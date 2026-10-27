function [model,state] = prepare(config)
%prepare - Einstellungen, Strecke und Startzustand einmal vorbereiten
%   [MODEL,STATE] = sbahn2.prepare(CONFIG) trennt feste Modellparameter
%   und Streckendaten von den veränderlichen Zugzuständen.
%
%   See also sbahn2.simulate, sbahn2.defaultConfig
arguments
    config (1,1) struct
end
base = sbahn2.defaultConfig;
fields = fieldnames(config);
assert(all(ismember(fields,fieldnames(base))),'SBahn:ConfigField', ...
    'Die Konfiguration enthält unbekannte Einstellungen.');
for k = 1:numel(fields)
    base.(fields{k}) = config.(fields{k});
end
config = base;
validateConfig(config);
model.config = config;
[model.route,model.cellCount] = loadRoute(config);
model.stepSeconds = 1;
model.stepCount = round(config.durationMinutes*60);
model.dxMeters = model.route.lengthMeters/model.cellCount;
model.trainCount = config.trainCount;
model.trainLengthMeters = 148;
model.trainCells = ceil(model.trainLengthMeters/model.dxMeters);
model.effectiveTrainLengthMeters = model.trainCells*model.dxMeters;
model.blocks = loadBlocks(model);
model.stationCount = numel(model.route.stationCells);
model.maxSpeedKmh = 80;
dynamic = config.motionModel == "Beschleunigen und Bremsen";
model.vmax = 1;
if dynamic
    model.vmax = floor(config.cruiseSpeedKmh/3.6*model.stepSeconds/model.dxMeters);
end
model.accelerationMetersPerSecondSquared = double(dynamic);
model.brakingMetersPerSecondSquared = double(dynamic);
model.speedUnitKmh = 3.6*model.dxMeters/model.stepSeconds;
model.driveSpeedKmh = model.vmax*model.speedUnitKmh;
dwell = struct('seconds',repmat(config.stopSeconds,1,model.stationCount), ...
    'sampleCounts',zeros(1,model.stationCount),'source',"Einheitliche Modellannahme");
if config.dwellMode == "GTFS-Stationshalte"
    dwell = loadDwellProfile(model.route);
end
model.stationDwellSeconds = dwell.seconds;
model.dwellSteps = round(dwell.seconds/model.stepSeconds);
model.dwellSource = dwell.source;
model.dwellSampleCounts = dwell.sampleCounts;
assert(all(abs(model.dwellSteps*model.stepSeconds-dwell.seconds) < 1e-9), ...
    'SBahn:TimeGrid','Haltezeit muss ein Vielfaches des Zeitschritts sein.');
assert(~dynamic || all(model.dwellSteps >= 1),'SBahn:DynamicsDwell', ...
    'Beschleunigen und Bremsen benötigt mindestens eine Sekunde Halt je Station.');
assert(model.trainCount*model.trainCells <= model.cellCount,'SBahn:CellCount', ...
    'Die Züge sind zusammen länger als die Ringstrecke. Bitte die Zugzahl verringern.');
if config.targetStopEnabled
    assert(config.targetStopTrain <= model.trainCount && config.targetStopStation <= model.stationCount, ...
        'SBahn:TargetStop','Zug- und Stationsnummer des Zusatzhalts müssen zum gewählten Modell passen.');
end
if config.closureEnabled
    assert(~isempty(model.blocks.startCells) && config.closureBlock <= numel(model.blocks.startCells), ...
        'SBahn:ClosureBlock','Eine Blocksperre benötigt Blocksteuerung und eine gültige Blocknummer.');
end
[state,model] = initialize(model);
end

function validateConfig(config)
%validateConfig - Sämtliche bedienbaren Einstellungen zentral prüfen
validateattributes(config.cruiseSpeedKmh,{'numeric'}, ...
    {'scalar','real','finite','>=',3.6,'<=',80});
assert(isstring(config.dataFolder) && isscalar(config.dataFolder), ...
    'SBahn:DataFolder','dataFolder muss ein einzelner Pfad als String sein.');
choices = {"trackMode",["Idealisierter Ring","Reale Ringbahn S41"],"SBahn:TrackMode"; ...
    "displayMode",["Schematischer Ring","Geografischer Streckenverlauf"],"SBahn:DisplayMode"; ...
    "dwellMode",["Einheitlich","GTFS-Stationshalte"],"SBahn:DwellMode"; ...
    "motionModel",["On/Off","Beschleunigen und Bremsen"],"SBahn:MotionModel"; ...
    "blockMode",["Ohne Blocksteuerung","Gleichmäßige Blockabschnitte","OSM-Signalabschnitte"],"SBahn:BlockMode"};
for row = 1:size(choices,1)
    value = config.(choices{row,1});
    assert(isstring(value) && isscalar(value) && ismember(value,choices{row,2}), ...
        choices{row,3},'Ungültige Auswahl für %s.',choices{row,1});
end
assert(config.displayMode ~= "Geografischer Streckenverlauf" || ...
    config.trackMode == "Reale Ringbahn S41",'SBahn:Geography', ...
    'Für den geografischen Streckenverlauf bitte die reale Ringbahn S41 auswählen.');
assert(config.dwellMode ~= "GTFS-Stationshalte" || config.trackMode == "Reale Ringbahn S41", ...
    'SBahn:DwellTrack','Für GTFS-Stationshalte bitte die reale Ringbahn S41 auswählen.');
assert(config.blockMode ~= "OSM-Signalabschnitte" || config.trackMode == "Reale Ringbahn S41", ...
    'SBahn:BlockTrack','OSM-Signalabschnitte benötigen die reale Ringbahn S41.');
for name = ["targetStopEnabled","randomStopEnabled","closureEnabled"]
    validateattributes(config.(name),{'logical'},{'scalar'});
end
for name = ["targetStopTrain","targetStopStation","targetStopSeconds", ...
        "randomStopMinSeconds","randomStopMaxSeconds","closureBlock","closureDurationSeconds"]
    validateattributes(config.(name),{'numeric'},{'scalar','real','finite','integer','positive'});
end
for name = ["targetStopAfterSeconds","closureStartSeconds","randomSeed"]
    validateattributes(config.(name),{'numeric'},{'scalar','real','finite','integer','nonnegative'});
end
validateattributes(config.randomSeed,{'numeric'},{'<=',2^32-1});
validateattributes(config.randomStopProbability,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
assert(config.randomStopMinSeconds <= config.randomStopMaxSeconds,'SBahn:RandomStopRange', ...
    'Die minimale zusätzliche Haltezeit darf nicht größer als die maximale sein.');
validateattributes(config.blockLengthMeters,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(config.trainCount,{'numeric'},{'scalar','real','finite','integer','positive'});
validateattributes(config.stopSeconds,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(config.durationMinutes,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(config.animate,{'logical'},{'scalar'});
validateattributes(config.framePauseSeconds,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(config.displayEvery,{'numeric'},{'scalar','real','finite','integer','positive'});
assert(abs(config.durationMinutes*60-round(config.durationMinutes*60)) < 1e-8, ...
    'SBahn:Duration','Die Simulationsdauer muss eine ganze Anzahl Sekunden ergeben.');
end
