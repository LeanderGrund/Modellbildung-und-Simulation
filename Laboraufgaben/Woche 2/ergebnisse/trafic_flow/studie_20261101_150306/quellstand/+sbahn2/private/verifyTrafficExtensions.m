function verifyTrafficExtensions(G,p,state)
%VERIFYTRAFFICEXTENSIONS Blockübertritte und ausgelöste Bremsziele prüfen.
if ~p.config.randomBrakeEnabled, return; end
expected = zeros(0,4);
for row = 1:numel(G.timeSeconds)-1
    [~,order] = sort(G.position(row,:));
    for train = order
        movement = mod(G.position(row+1,train)-G.position(row,train),p.cellCount);
        swept = mod(G.position(row,train)-1+(0:movement),p.cellCount)+1;
        blocks = p.blocks.cellBlock(swept);
        entered = blocks(find(diff(blocks) ~= 0)+1);
        for block = entered
            expected(end+1,:) = [G.timeSeconds(row+1),train,block,G.velocity(row+1,train)]; %#ok<AGROW>
        end
    end
end
events = state.blockEntryLog;
assert(isequal(events(:,1:4),expected),'SBahn:BlockTrials', ...
    'Die Störungsprüfung muss genau einmal je tatsächlicher Blockeinfahrt erfolgen.');
hit = events(:,6) == 1;
assert(all(events(hit,5) == floor(events(hit,4)/2)) && all(isnan(events(~hit,5))), ...
    'SBahn:BrakeTarget','Das Bremsziel ist nicht die abgerundete halbe Eintrittsgeschwindigkeit.');
if p.config.randomBrakeProbability == 0
    assert(~any(hit),'SBahn:BrakeDisabled','Zufallsbremsung trotz p=0.');
elseif p.config.randomBrakeProbability == 1
    assert(all(hit),'SBahn:BrakeCertain','Bei p=1 fehlt eine Zufallsbremsung.');
end
pending = G.randomBrakeTarget(1:end-1,:);
active = isfinite(pending);
limit = max(pending,G.velocity(1:end-1,:)-1);
actual = G.velocity(2:end,:);
assert(all(actual(active) <= limit(active)), ...
    'SBahn:RandomBraking','Ein aktives Zufallsbremsziel wurde nicht beachtet.');
end
