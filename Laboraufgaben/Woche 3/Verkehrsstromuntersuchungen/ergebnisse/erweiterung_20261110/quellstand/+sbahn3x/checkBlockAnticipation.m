function cases = checkBlockAnticipation
%CHECKBLOCKANTICIPATION Verhalten am Zugende und an Block-/Ringgrenzen prüfen.
c = sbahn3x.defaultConfig;
c.motionModel = "Beschleunigen und Bremsen";
c.blockMode = "Gleichmäßige Blockabschnitte";
c.blockLengthMeters = 500; c.trainCount = 2; c.durationMinutes = 1;
c.animate = false; c.anticipationEnabled = true; c.anticipationBeta = 0.2;
[p,base] = sbahn3x.prepare(c);
cases = table(strings(0,1),false(0,1),'VariableNames',{'name','passed'});
for blocksAhead = 1:3
    [s,q] = fixture(base,p,10,blocksAhead,false);
    next = advance(s,q,RandStream('mt19937ar','Seed',42));
    expected = 6; if blocksAhead <= 2, expected = 4; end
    assert(next.velocity(1) == expected);
    assert(next.anticipationEligibleLastStep(1) == (blocksAhead <= 2));
    cases(end+1,:) = {"Zugende "+blocksAhead+" Bloecke voraus",true};
end
% Zugspitze schon in Block 3, Zugende genau auf letzter Zelle von Block 2.
for wrap = [false,true]
    own = 10; if wrap, own = numel(p.blocks.startCells); end
    [s,q] = fixture(base,p,own,2,true);
    next = advance(s,q,RandStream('mt19937ar','Seed',42));
    assert(next.velocity(1) == 4 && next.anticipationEligibleLastStep(1));
    cases(end+1,:) = {"Zugende letzte Zelle Block 2; Ringschluss="+wrap,true};
    s.position(2) = mod(s.position(2),q.cellCount)+1;
    next = advance(s,q,RandStream('mt19937ar','Seed',42));
    assert(next.velocity(1) == 6 && ~next.anticipationEligibleLastStep(1));
    cases(end+1,:) = {"Zugende erste Zelle Block 3; Ringschluss="+wrap,true};
end
[s,q] = fixture(base,p,10,2,false); q.config.anticipationBeta = 0;
next = advance(s,q,RandStream('mt19937ar','Seed',42));
assert(next.velocity(1) == 6 && ~next.anticipationEligibleLastStep(1));
cases(end+1,:) = {"beta=0 erlaubt regulaere Beschleunigung",true};
[s,q] = fixture(base,p,10,2,false); q.config.anticipationBeta = 0.05;
s.waitSteps(2) = 10;
for k = 1:4
    s = advance(s,q,RandStream('mt19937ar','Seed',42));
    expected = 5; if k == 4, expected = 4; end
    assert(s.velocity(1) == expected);
end
cases(end+1,:) = {"Kleine beta-Werte integrieren Bruchteile",true};
[s,q] = fixture(base,p,10,3,false); q.config.anticipationBeta = 0.05;
s.anticipationRemainder(1) = 0.75;
next = advance(s,q,RandStream('mt19937ar','Seed',42));
assert(next.velocity(1) == 6 && next.anticipationRemainder(1) == 0);
cases(end+1,:) = {"Bruchteil ausserhalb des Bereichs wird verworfen",true};
end

function [s,q] = fixture(base,p,ownBlock,ahead,lastCell)
q = p; s = base;
count = numel(p.blocks.startCells);
rearBlock = mod(ownBlock-1+ahead,count)+1;
rearCell = p.blocks.startCells(rearBlock)+250;
if lastCell
    nextBlock = mod(rearBlock,count)+1;
    rearCell = mod(p.blocks.startCells(nextBlock)-2,p.cellCount)+1;
end
s.position = [p.blocks.startCells(ownBlock)+10, ...
    mod(rearCell+p.trainCells-2,p.cellCount)+1];
s.velocity = [5,0]; s.waitSteps(:) = 0; s.extraWaitSteps(:) = 0;
s.dwellStation(:) = 0;
for train = 1:2
    distance = mod(p.route.stationCells-s.position(train),p.cellCount);
    distance(distance == 0) = p.cellCount;
    [~,s.nextStation(train)] = min(distance);
end
s.anticipationRemainder(:) = 0;
end
