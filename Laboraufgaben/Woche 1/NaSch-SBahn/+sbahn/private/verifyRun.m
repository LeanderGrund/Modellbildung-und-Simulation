function verifyRun(G,p,state,report)
%verifyRun - Bewegungen unabhängig von ihrer Berechnung prüfen
%   verifyRun(G,P,STATE,REPORT) prüft Belegung, Bremsreserven,
%   Stationsereignisse und Mindesthaltezeiten ohne Kennzahlen zu berechnen.
%
%   See also sbahn.simulate

position = G.position;
velocity = G.velocity;
closureLimits = verifyDisturbances(G,p,state);
assert(size(position,2) == p.trainCount, ...
    'SBahn:TrainCount','Zugzahl ist nicht konstant.');
assert(all(position >= 1 & position <= p.cellCount,'all'), ...
    'SBahn:Position','Position liegt außerhalb der Ringstrecke.');
assert(all(velocity >= 0 & velocity <= p.vmax & velocity == round(velocity),'all'), ...
    'SBahn:Velocity','Geschwindigkeit liegt außerhalb der zulässigen Stufen.');
if p.config.motionModel == "Beschleunigen und Bremsen"
    assert(all(abs(diff(velocity,1,1)) <= 1,'all'),'SBahn:Acceleration', ...
        'Beschleunigung oder Bremsverzögerung überschreitet 1 m/s².');
    % Keine Station überspringen; der diskrete Bremsweg muss davor enden.
    nextDistance = inf(size(position,1)-1,p.trainCount);
    for station = 1:p.stationCount
        distance = mod(p.route.stationCells(station)-position(1:end-1,:),p.cellCount);
        distance(distance == 0) = p.cellCount;
        nextDistance = min(nextDistance,distance);
    end
    assert(all(mod(diff(position,1,1),p.cellCount) <= nextDistance,'all'),'SBahn:SkippedStation', ...
        'Ein Zug überspringt eine Station.');
    nextSpeed = velocity(2:end,:);
    assert(all(nextSpeed.*(nextSpeed+1)/2 <= nextDistance,'all'), ...
        'SBahn:BrakingDistance','Ein Zug hat keine ausreichende Bremsreserve.');
end
sortedAll = sort(position,2);
bodyGaps = [diff(sortedAll,1,2),p.cellCount+sortedAll(:,1)-sortedAll(:,end)]-p.trainCells;
assert(all(bodyGaps >= 0,'all'),'SBahn:Collision','Zugkörper überlappen auf dem Ring.');
movement = mod(diff(position,1,1),p.cellCount);
assert(isequal(movement,velocity(2:end,:)), ...
    'SBahn:Movement','Bewegung passt nicht zur Geschwindigkeit.');
assert(all(movement(G.waitSteps(1:end-1,:) > 0) == 0), ...
    'SBahn:DwellMovement','Ein wartender Zug bewegt sich.');
assert(all(isfinite(G.waitSteps) & G.waitSteps >= 0 & G.waitSteps == round(G.waitSteps),'all'), ...
    'SBahn:Timer','Ungültige Haltezeit.');
assert(all(ismember(position(G.waitSteps > 0),p.route.stationCells)), ...
    'SBahn:DwellPosition','Ein Zug hält außerhalb einer Station.');
% Die zulässige Halteuhr wird genau einmal je Station bestimmt.
[~,stationIndex] = ismember(position,p.route.stationCells);
waiting = G.waitSteps > 0;
limits = reshape(p.dwellSteps(stationIndex(waiting)),[],1);
assert(all(G.waitSteps(waiting)-G.extraWaitSteps(waiting) <= limits),'SBahn:StationTimer', ...
    'Die Halteuhr überschreitet die Haltezeit dieser Station.');
blocked = G.blocked(2:end,:);
assert(~any(G.blocked(1,:)) && all(movement(blocked) == 0) && ...
    ~any(blocked & G.waitSteps(1:end-1,:) > 0,'all'), ...
    'SBahn:Blocked','Ungültige Markierung eines blockierten Zuges.');
% Körperbelegung unabhängig für jeden gespeicherten Zustand rekonstruieren.
% Mehrere Abschnitte bleiben bis zur Räumung durch das Zugende belegt.
for row = 1:size(position,1)
    owner = zeros(size(p.blocks.startCells));
    for train = 1:p.trainCount
        if ~isempty(owner)
            body = mod(position(row,train)-1-(0:p.trainCells-1),p.cellCount)+1;
            occupied = unique(p.blocks.cellBlock(body));
            assert(all(owner(occupied) == 0),'SBahn:BlockOccupancy', ...
                'Ein Block wird von mehreren Zugkörpern belegt.');
            owner(occupied) = train;
        end
    end
    if row == size(position,1), break; end
    for train = 1:p.trainCount
        distances = mod(position(row,:)-position(row,train),p.cellCount);
        distances(train) = p.cellCount;
        authority = min(distances)-p.trainCells;
        assert(movement(row,train) <= authority,'SBahn:Overtaking', ...
            'Ein Zug überfährt das zuvor belegte Zugende.');
        signalDistance = inf;
        if ~isempty(owner)
            foreign = p.blocks.startCells(owner > 0 & owner ~= train);
            if ~isempty(foreign)
                signalDistance = min(mod(foreign-position(row,train),p.cellCount))-1;
            end
            swept = mod(position(row,train)-1+(1:movement(row,train)),p.cellCount)+1;
            sweptOwners = owner(p.blocks.cellBlock(swept));
            assert(all(sweptOwners == 0 | sweptOwners == train), ...
                'SBahn:BlockEntry','Ein Zug fährt in einen zuvor fremdbelegten Block ein.');
        end
        assert(movement(row,train) <= closureLimits(row,train),'SBahn:ClosureEntry', ...
            'Ein Zug überfährt einen gesperrten Blockzugang ohne letzte Einfahrerlaubnis.');
        signalDistance = min(signalDistance,closureLimits(row,train));
        expectedBlock = min(authority,signalDistance) == 0 && G.waitSteps(row,train) == 0;
        assert(blocked(row,train) == expectedBlock,'SBahn:BlockReason', ...
            'Eine Blockierung passt nicht zur vorausliegenden Belegung.');
        assert(G.signalBlocked(row+1,train) == (expectedBlock && signalDistance == 0), ...
            'SBahn:SignalBlockReason','Die Signalblockierung passt nicht zur Blockbelegung.');
        assert(G.closureBlocked(row+1,train) == (expectedBlock && closureLimits(row,train) == 0), ...
            'SBahn:ClosureReason','Die Wartezeit passt nicht zur zeitweisen Blocksperre.');
        if p.config.motionModel == "Beschleunigen und Bremsen"
            speed = velocity(row+1,train);
            assert(speed*(speed+1)/2 <= min(authority,signalDistance), ...
                'SBahn:BlockBraking','Die Bremsreserve vor Zugende oder Blockgrenze fehlt.');
        end
    end
end
assert(p.driveSpeedKmh <= p.maxSpeedKmh, ...
    'SBahn:SpeedLimit','Höchstgeschwindigkeit überschritten.');

for train = 1:p.trainCount
    arrivals = state.arrivalLog(state.arrivalLog(:,2) == train,:);
    if size(arrivals,1) > 1
        assert(isequal(arrivals(2:end,3),mod(arrivals(1:end-1,3),p.stationCount)+1), ...
            'SBahn:SkippedStation','Eine Station wurde übersprungen.');
    end
end
assert(report.minimumDwellsSatisfied,'SBahn:DwellTime','Ein Stationshalt ist zu kurz.');
if state.timeSeconds >= p.expectedLapSeconds && ~any(G.blocked,'all') && ...
        ~any(G.extraWaitSteps,'all') && ...
        (p.config.motionModel == "On/Off" || p.trainCount == 1)
    assert(all(state.visitCount > 0,'all'), ...
        'SBahn:StationVisits','Nicht alle Stationen wurden bedient.');
end
if p.config.motionModel == "Beschleunigen und Bremsen"
    arrivalRows = round(state.arrivalLog(:,1)/p.stepSeconds)+1;
    arrivalIndex = sub2ind(size(position),arrivalRows,state.arrivalLog(:,2));
    expectedCells = reshape(p.route.stationCells(state.arrivalLog(:,3)),[],1);
    assert(isequal(position(arrivalIndex),expectedCells) && ...
        all(velocity(arrivalIndex) == 1),'SBahn:Arrival', ...
        'Eine Ankunft liegt nicht auf der Station oder erfolgt zu schnell.');
end
end
