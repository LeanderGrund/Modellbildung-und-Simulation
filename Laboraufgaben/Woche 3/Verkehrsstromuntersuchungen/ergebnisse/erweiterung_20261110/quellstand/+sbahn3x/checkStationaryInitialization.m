function tests = checkStationaryInitialization
%CHECKSTATIONARYINITIALIZATION Sichere Aufstellung und Anfahren bis N=44 prüfen.
tests = table();
settings = [20,0;28,0;36,0;44,0;44,18;44,45];
for k = 1:size(settings,1)
    c = sbahn3x.defaultConfig;
    c.trackMode = "Reale Ringbahn S41";
    c.motionModel = "Beschleunigen und Bremsen";
    c.blockMode = "OSM-Signalabschnitte"; c.dwellMode = "GTFS-Stationshalte";
    c.trainCount = settings(k,1); c.dwellOffsetSeconds = settings(k,2);
    c.initializationMode = "Ruhende Blockaufstellung";
    c.durationMinutes = 2; c.animate = false;
    c.anticipationEnabled = true; c.anticipationBeta = 0.2;
    c.randomBrakeEnabled = true; c.randomBrakeProbability = 0.2;
    c.randomStopEnabled = true; c.randomStopProbability = 0.2;
    c.randomStopMinSeconds = 0; c.randomStopMaxSeconds = 120;
    [G,p,r] = sbahn3x.simulate(c);
    assert(r.checksPassed && all(G.velocity(1,:) == 0));
    blocks = p.blocks.cellBlock(G.position(1,:));
    assert(isequal(blocks,p.initialHeadBlocks));
    assert(all(mod(diff([blocks,blocks(1)]),numel(p.blocks.startCells)) >= 2));
    assert(any(G.velocity > 0,'all'));
    assert(max(abs(diff(G.velocity)),[],'all') <= 1);
    tests = [tests;table(c.trainCount,c.dwellOffsetSeconds,true, ...
        'VariableNames',{'train_count','extra_dwell_s','passed'})]; %#ok<AGROW>
end
end
