function [state,model] = initialize(model)
%initialize - Züge zeitlich gleichmäßig auf einem freien Umlauf verteilen
%   [STATE,MODEL] = initialize(MODEL) verwendet für beide Fahrmodelle
%   dieselbe Bewegungsfunktion wie die eigentliche Simulation.
%
%   See also sbahn3x.prepare

referenceState = emptyState(1,model);
referenceState.position = model.route.stationCells(1);
referenceState.nextStation = 2;
referenceState.dwellStation = 1;
dynamic = model.config.motionModel == "Beschleunigen und Bremsen";
if dynamic
    referenceState.velocity = 1; % Letzter Ankunftsschritt vor dem Halt.
    referenceState.waitSteps = model.dwellSteps(1);
end
fields = ["position","velocity","waitSteps","nextStation","dwellStation"];
maximumSteps = model.cellCount+sum(model.dwellSteps)+model.stationCount;
for field = fields
    reference.(field) = zeros(1,maximumSteps);
end
for step = 1:maximumSteps
    for field = fields
        reference.(field)(step) = referenceState.(field);
    end
    referenceState = advance(referenceState,model);
    if (dynamic && referenceState.visitCount(1) > 0) || ...
            (~dynamic && step == model.cellCount+sum(model.dwellSteps))
        break
    end
end
assert(step < maximumSteps,'SBahn:ReferenceCycle', ...
    'Der freie Referenzumlauf konnte nicht abgeschlossen werden.');
model.expectedLapSeconds = step*model.stepSeconds;
model.expectedHeadwaySeconds = model.expectedLapSeconds/model.trainCount;
model.averageSpeedKmh = 3.6*model.route.lengthMeters/model.expectedLapSeconds;
if model.config.initializationMode == "Ruhende Blockaufstellung"
    % Gleichmaessig ueber die Blocknummern verteilte Zugspitzen am Blockende.
    % Mindestens zwei Blocknummern Abstand lassen Platz fuer den Zugkoerper.
    count = numel(model.blocks.startCells);
    assert(floor(count/model.trainCount) >= 2,'SBahn:InitialBlockCount', ...
        'Zu wenige Bloecke fuer diese ruhende Aufstellung.');
    selected = 1+floor((0:model.trainCount-1)*count/model.trainCount);
    following = mod(selected,count)+1;
    state = emptyState(model.trainCount,model);
    state.position = mod(model.blocks.startCells(following)-2,model.cellCount)+1;
    for train = 1:model.trainCount
        distances = mod(model.route.stationCells-state.position(train),model.cellCount);
        station = find(distances == 0,1);
        if isempty(station)
            [~,state.nextStation(train)] = min(distances);
        else
            state.dwellStation(train) = station;
            state.waitSteps(train) = model.dwellSteps(station);
            state.nextStation(train) = mod(station,model.stationCount)+1;
        end
    end
    trafficLimits(state.position,model); % Exklusive Bloecke und freie Zugkoerper.
    model.initialPhaseShiftSeconds = NaN; % Bei dieser Aufstellung ohne Bedeutung.
    model.initialHeadBlocks = selected;
    return
end
phase = floor((0:model.trainCount-1)*step/model.trainCount)+1;
maximumShift = double(model.config.initialPhaseSearch)*(step-1);
for shift = 0:maximumShift
    state = emptyState(model.trainCount,model);
    shifted = mod(phase-1+shift,step)+1;
    for field = fields
        state.(field) = reference.(field)(shifted);
    end
    try
        traffic = trafficLimits(state.position,model);
        if dynamic
            minimumNext = max(0,state.velocity-1);
            assert(all(minimumNext.*(minimumNext+1)/2 <= traffic.bodyDistance),'SBahn:InitialBrakingDistance', ...
                'Zu viele Züge: Die Startzustände haben keine ausreichende Bremsreserve hinter dem Zugende.');
            state.velocity = min(state.velocity,1+floor((sqrt(1+8*traffic.distance)-1)/2));
        end
        model.initialPhaseShiftSeconds = shift*model.stepSeconds;
        return
    catch errorInfo
        recoverable = ismember(string(errorInfo.identifier), ...
            ["SBahn:TrainOverlap","SBahn:InitialBlockOverlap","SBahn:InitialBrakingDistance"]);
        if ~model.config.initialPhaseSearch || ~recoverable
            rethrow(errorInfo);
        end
    end
end
error('SBahn:NoSafeInitialPhase', ...
    'Keine gemeinsame Verschiebung der freien Zeitphasen ergibt eine zulässige Startbelegung.');
end

function state = emptyState(trainCount,model)
%emptyState - Explizite Zugfelder mit dem Arrayindex als Zugnummer anlegen
stationCount = model.stationCount;
state = struct('position',ones(1,trainCount),'velocity',zeros(1,trainCount), ...
    'waitSteps',zeros(1,trainCount),'nextStation',ones(1,trainCount), ...
    'dwellStation',zeros(1,trainCount),'timeSeconds',0, ...
    'blockedLastStep',false(1,trainCount),'signalBlockedLastStep',false(1,trainCount),'movedCells',zeros(1,trainCount), ...
    'visitCount',zeros(trainCount,stationCount), ...
     'arrivalLog',zeros(0,3),'departureLog',zeros(0,3), ...
    'extraWaitSteps',zeros(1,trainCount),'stopLog',zeros(0,6),'targetStopApplied',false, ...
    'closureActive',false,'closureActivated',false,'closurePermission',false(1,trainCount), ...
    'closureDistance',inf(1,trainCount),'closureBlockedLastStep',false(1,trainCount), ...
    'closureGraceLog',zeros(0,3));
% Bei ausgeschalteten Erweiterungen bleibt auch die Zustandsstruktur mit
% Woche 1 identisch (bestehende Regressionstests).
if model.config.randomBrakeEnabled
    state.randomBrakeTarget = nan(1,trainCount);
    state.randomBrakeLastStep = false(1,trainCount);
    state.blockEntryLog = zeros(0,6); % Zeit, Zug, Block, v_Eintritt, Ziel, Treffer
end
if model.config.anticipationEnabled
    state.anticipationRemainder = zeros(1,trainCount);
    state.anticipationLastStep = false(1,trainCount);
    state.anticipationEligibleLastStep = false(1,trainCount);
end
end
