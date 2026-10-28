function checks = sanity_check(G,p,report)
%SANITY_CHECK Grundregeln unabhängig aus gespeicherten Zuständen prüfen.
% G(k+1).velocity beschreibt die Bewegung von Zustand k nach k+1.
% Die ausführlichen Stations-/Blockprüfungen aus Woche 1 laufen zusätzlich
% bereits in sbahn2.simulate (verifyRun und verifyDisturbances).
x = G.position; v = G.velocity; N = p.cellCount;
assert(isequal(size(x),size(v),size(G.waitSteps)) && ...
    size(x,2) == p.trainCount,'SBahn2:Conservation','Zugzahl/Zustandsdimension verändert.');
assert(all(isfinite(x) & x == round(x) & x >= 1 & x <= N,'all'), ...
    'SBahn2:Ring','Positionen müssen ganzzahlig auf dem Ring liegen.');
assert(all(isfinite(v) & v == round(v) & v >= 0 & v <= p.vmax,'all'), ...
    'SBahn2:Speed','Unzulässige Geschwindigkeitsstufe.');
move = mod(diff(x,1,1),N);
assert(isequal(move,v(2:end,:)),'SBahn2:Movement','Ringbewegung und Geschwindigkeit widersprechen sich.');
assert(all(abs(diff(v,1,1)) <= 1,'all'),'SBahn2:Acceleration', ...
    'Beschleunigung/Bremsen überschreitet eine Stufe pro Sekunde.');
assert(all(move(G.waitSteps(1:end-1,:) > 0) == 0),'SBahn2:Dwell', ...
    'Bewegung während eines Stationshalts.');
[sx,order] = sort(x(1:end-1,:),2);
gaps = [diff(sx,1,2),N+sx(:,1)-sx(:,end)]-p.trainCells;
lastX = sort(x(end,:));
lastGaps = [diff(lastX),N+lastX(1)-lastX(end)]-p.trainCells;
assert(all(gaps >= 0,'all') && all(lastGaps >= 0), ...
    'SBahn2:Collision','Zugkörper überlappen, auch am Ringschluss.');
rows = repmat((1:size(move,1))',1,p.trainCount);
ordered = move(sub2ind(size(move),rows,order));
assert(all(ordered <= gaps,'all'),'SBahn2:Synchronous', ...
    'Ein Zug nutzt bereits im selben Schritt den Weg eines vorausfahrenden Zuges.');
B = ordered.*(ordered+1)/2;
assert(all(B <= gaps,'all'),'SBahn2:BodyBraking','Bremsreserve vor einem Zugende fehlt.');
stationDistance = inf(size(move));
for station = p.route.stationCells
    d = mod(station-x(1:end-1,:),N);
    d(d == 0) = N;
    stationDistance = min(stationDistance,d);
end
assert(all(move.*(move+1)/2 <= stationDistance,'all'), ...
    'SBahn2:StationBraking','Station übersprungen oder ohne Bremsreserve angefahren.');
% Abfahrtsdetektor unabhängig vom Ereignisprotokoll rekonstruieren.
detector = x(1:end-1,:) == p.route.stationCells(1) & move > 0;
[detectorRows,detectorTrains] = find(detector);
observed = sortrows([G.timeSeconds(detectorRows),detectorTrains],[1 2]);
logged = p.state.departureLog(p.state.departureLog(:,3) == 1,1:2);
assert(isequal(observed,sortrows(logged,[1 2])),'SBahn2:Detector', ...
    'Abfahrtsprotokoll und unabhängig rekonstruierter Detektor widersprechen sich.');
assert(report.checksPassed && report.minimumDwellsSatisfied, ...
    'SBahn2:InheritedChecks','Eine Prüfung des Modellkerns ist fehlgeschlagen.');
checks = struct('constantTrainCount',true,'integerRingPositions',true, ...
    'speedBounds',true,'periodicMovement',true,'accelerationBounds',true, ...
    'stationaryDuringDwell',true,'noBodyOverlap',true,'synchronousMovement',true, ...
    'brakingReserve',true,'noSkippedStations',true,'independentDetector',true, ...
    'inheritedStationAndBlockChecks',true);
end
