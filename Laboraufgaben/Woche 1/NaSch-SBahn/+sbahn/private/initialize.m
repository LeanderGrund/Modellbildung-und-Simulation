function [state,model] = initialize(model)
%initialize - Züge zeitlich gleichmäßig auf einem freien Umlauf verteilen
%   [STATE,MODEL] = initialize(MODEL) verwendet für beide Fahrmodelle
%   dieselbe Bewegungsfunktion wie die eigentliche Simulation.
%
%   See also sbahn.prepare

referenceState = emptyState(1,model.stationCount);
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
phase = floor((0:model.trainCount-1)*step/model.trainCount)+1;
state = emptyState(model.trainCount,model.stationCount);
for field = fields
    state.(field) = reference.(field)(phase);
end
traffic = trafficLimits(state.position,model);
if dynamic
    minimumNext = max(0,state.velocity-1);
    assert(all(minimumNext.*(minimumNext+1)/2 <= traffic.bodyDistance),'SBahn:InitialBrakingDistance', ...
        'Zu viele Züge: Die Startzustände haben keine ausreichende Bremsreserve hinter dem Zugende.');
    % Die Positionen bleiben in allen Blockmodi gleich. Nur eine zu hohe
    % Startgeschwindigkeit vor einem gesperrten Block wird abgesenkt.
    state.velocity = min(state.velocity,1+floor((sqrt(1+8*traffic.distance)-1)/2));
end
end

function state = emptyState(trainCount,stationCount)
%emptyState - Explizite Zugfelder mit dem Arrayindex als Zugnummer anlegen
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
end
