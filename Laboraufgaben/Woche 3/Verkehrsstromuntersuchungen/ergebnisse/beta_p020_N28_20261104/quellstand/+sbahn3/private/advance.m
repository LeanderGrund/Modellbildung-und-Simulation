function state = advance(state,model,stream)
%advance - Fahrweg, Geschwindigkeit und Stationsereignisse eines Schritts berechnen
%   STATE = advance(STATE,MODEL) verwendet für alle Züge denselben alten
%   Zustand. Der Arrayindex ist immer die Zugnummer.
%
%   See also sbahn3.simulate

if nargin < 3, stream = []; end % Referenzumlauf ohne Störungen und Zufallsziehungen.
traffic = trafficLimits(state.position,model);
traffic.blockDistance = min(traffic.blockDistance,state.closureDistance);
traffic.distance = min(traffic.distance,state.closureDistance);
distance = mod(model.route.stationCells(state.nextStation)-state.position,model.cellCount);
distance(distance == 0) = model.cellCount;
limit = min(traffic.distance,distance);

% Zuerst die reguläre Geschwindigkeit wählen, dann wartende Züge anhalten.
speed = min(1,limit);
if model.config.motionModel == "Beschleunigen und Bremsen"
    safeSpeed = floor((sqrt(1+8*limit)-1)/2);
    speed = min(min(state.velocity+1,model.vmax),safeSpeed);
end
speed(state.waitSteps > 0) = 0;
% Antizipation ist eine zusätzliche Bremse bei langsamerem Vorgänger.
% Bei freiem/gleich schnellem Vorgänger gilt die reguläre Beschleunigung.
% Bruchteile einer Geschwindigkeitsstufe werden über Schritte integriert,
% damit kleine beta-Werte im 1-m-/1-s-Raster nicht wirkungslos werden.
anticipationApplied = false(size(speed));
anticipationEligible = false(size(speed));
remainder = zeros(size(speed));
if model.config.anticipationEnabled && ~isempty(stream) && numel(speed) > 1
    leader = zeros(size(speed));
    leader(traffic.order) = traffic.order([2:end 1]);
    difference = state.velocity(leader)-state.velocity;
    % Das Zugende des Vorgaengers muss im ersten oder zweiten vorausliegenden
    % Block liegen. Die eigene Zugspitze definiert den Ausgangsblock.
    ownBlock = model.blocks.cellBlock(state.position);
    leaderEnd = mod(state.position(leader)-model.trainCells,model.cellCount)+1;
    leaderEndBlock = model.blocks.cellBlock(leaderEnd);
    blocksAhead = mod(leaderEndBlock-ownBlock,numel(model.blocks.startCells));
    inRange = blocksAhead >= 1 & blocksAhead <= model.config.anticipationMaxBlocks;
    % beta=0 hat keinerlei Zusatzwirkung, auch keine Beschleunigungssperre.
    slowing = difference < 0 & state.waitSteps == 0 & inRange ...
        & model.config.anticipationBeta > 0;
    anticipationEligible = slowing;
    acceleration = max(-1,model.config.anticipationBeta*difference);
    remainder(slowing) = state.anticipationRemainder(slowing) ...
        -acceleration(slowing)*model.stepSeconds^2/model.dxMeters;
    decrement = min(1,floor(remainder+1e-12));
    remainder = remainder-decrement;
    speed(slowing) = min(speed(slowing), ...
        max(0,state.velocity(slowing)-decrement(slowing)));
    anticipationApplied = slowing & decrement > 0;
end
randomBrakeApplied = false(size(speed));
if model.config.randomBrakeEnabled && ~isempty(stream)
    braking = isfinite(state.randomBrakeTarget);
    speed(braking) = min(speed(braking), ...
        max(state.randomBrakeTarget(braking),state.velocity(braking)-1));
    randomBrakeApplied = braking & speed < state.velocity;
end
if model.config.motionModel == "Beschleunigen und Bremsen"
    assert(all(speed >= max(0,state.velocity-1)),'SBahn:Braking', ...
        'Der Zustand erlaubt kein Bremsen mit höchstens 1 m/s².');
end

% Bewegung und Halteuhren werden gemeinsam aus dem alten Zustand abgeleitet.
next = state;
next.velocity = speed;
next.position = mod(state.position+speed-1,model.cellCount)+1;
next.movedCells = state.movedCells+speed;
next.timeSeconds = state.timeSeconds+model.stepSeconds;
next.waitSteps = max(0,state.waitSteps-1);
next.extraWaitSteps = min(state.extraWaitSteps,next.waitSteps);
next.blockedLastStep = state.waitSteps == 0 & traffic.distance == 0;
if model.config.anticipationEnabled
    next.anticipationRemainder = remainder;
    next.anticipationLastStep = anticipationApplied;
    next.anticipationEligibleLastStep = anticipationEligible;
end
if model.config.randomBrakeEnabled
    next.randomBrakeTarget(speed <= state.randomBrakeTarget) = NaN;
    next.randomBrakeLastStep = randomBrakeApplied;
end
next.signalBlockedLastStep = next.blockedLastStep & traffic.blockDistance == 0;
next.closureBlockedLastStep = next.blockedLastStep & state.closureDistance == 0;
if any(state.closurePermission)
    entryDistance = mod(model.blocks.startCells(model.config.closureBlock)-state.position,model.cellCount);
    next.closurePermission(entryDistance <= speed & speed > 0) = false;
end

% Nur bewegte Züge können abfahren oder ankommen. Die Ereignisreihenfolge
% bleibt nach alter Position sortiert, unabhängig von der Darstellung.
for train = traffic.order(speed(traffic.order) > 0)
    if state.dwellStation(train) > 0
        next.departureLog(end+1,:) = ... %#ok<AGROW>
            [state.timeSeconds,train,state.dwellStation(train)];
        next.dwellStation(train) = 0;
    end
    if speed(train) == distance(train)
        station = state.nextStation(train);
        targeted = 0; random = 0;
        c = model.config;
        if ~isempty(stream)
            if c.targetStopEnabled && ~state.targetStopApplied && train == c.targetStopTrain ...
                    && station == c.targetStopStation && next.timeSeconds >= c.targetStopAfterSeconds
                targeted = c.targetStopSeconds;
                next.targetStopApplied = true;
            end
            if c.randomStopEnabled && rand(stream) < c.randomStopProbability
                random = randi(stream,[c.randomStopMinSeconds,c.randomStopMaxSeconds]);
            end
        end
        next.extraWaitSteps(train) = (targeted+random)/model.stepSeconds;
        next.waitSteps(train) = model.dwellSteps(station)+next.extraWaitSteps(train);
        next.stopLog(end+1,:) = [next.timeSeconds,train,station, ...
            model.stationDwellSeconds(station),targeted,random];
        next.dwellStation(train) = station;
        next.nextStation(train) = mod(station,model.stationCount)+1;
        next.visitCount(train,station) = state.visitCount(train,station)+1;
        next.arrivalLog(end+1,:) = [next.timeSeconds,train,station];
    end
end
% Jede tatsächlich überfahrene Blockgrenze wird genau einmal geprüft,
% auch wenn ein Schritt mehrere kurze Blöcke überquert. Die Bremsung beginnt
% im Folgeschritt; Ziel ist die halbe Geschwindigkeit der Einfahrt.
if model.config.randomBrakeEnabled && ~isempty(stream)
    for train = traffic.order(speed(traffic.order) > 0)
        swept = mod(state.position(train)-1+(0:speed(train)),model.cellCount)+1;
        blocks = model.blocks.cellBlock(swept);
        entered = blocks(find(diff(blocks) ~= 0)+1);
        for block = entered
            triggered = rand(stream) < model.config.randomBrakeProbability;
            target = NaN;
            if triggered
                target = floor(speed(train)/2);
                next.randomBrakeTarget(train) = min( ...
                    next.randomBrakeTarget(train),target,'omitnan');
            end
            next.blockEntryLog(end+1,:) = ...
                [next.timeSeconds,train,block,speed(train),target,triggered]; %#ok<AGROW>
        end
    end
end
state = next;
end
