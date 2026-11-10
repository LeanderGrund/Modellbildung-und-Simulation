function closureLimits = verifyDisturbances(G,p,state)
%verifyDisturbances - Zusatzhalte und sichere Blocksperren unabhängig nachprüfen
%   CLOSURELIMITS = verifyDisturbances(G,P,STATE) rekonstruiert die erlaubten
%   Einfahrten aus den gespeicherten Positionen und Geschwindigkeiten.
%
%   See also sbahn2.simulate
c = p.config;
extra = G.extraWaitSteps;
assert(all(isfinite(extra) & extra >= 0 & extra == round(extra) & extra <= G.waitSteps,'all') ...
    && ~any(extra(1,:)),'SBahn:ExtraTimer','Ungültige zusätzliche Halteuhr.');
events = state.stopLog;
assert(isequal(events(:,1:3),state.arrivalLog),'SBahn:StopLog', ...
    'Für jede Ankunft muss genau ein Halteprotokoll vorhanden sein.');
assert(all(events(:,4) == reshape(p.stationDwellSeconds(events(:,3)),[],1)), ...
    'SBahn:PlannedDwell','Die geplanten Haltezeiten passen nicht zum Stationsprofil.');
targeted = zeros(size(events,1),1);
if c.targetStopEnabled
    first = find(events(:,2) == c.targetStopTrain & events(:,3) == c.targetStopStation ...
        & events(:,1) >= c.targetStopAfterSeconds,1);
    if ~isempty(first), targeted(first) = c.targetStopSeconds; end
end
assert(isequal(events(:,5),targeted),'SBahn:TargetEvent','Der gezielte Zusatzhalt wurde falsch vergeben.');
random = events(:,6);
assert(all(random == 0 | (random >= c.randomStopMinSeconds & random <= c.randomStopMaxSeconds ...
    & random == round(random))),'SBahn:RandomEvent','Ein zufälliger Zusatzhalt liegt außerhalb der Grenzen.');
assert((c.randomStopEnabled && c.randomStopProbability > 0) || all(random == 0), ...
    'SBahn:RandomDisabled','Trotz deaktivierter Zufallswirkung wurde ein Zusatzhalt vergeben.');
arrivals = false(size(extra));
indices = sub2ind(size(extra),round(events(:,1)/p.stepSeconds)+1,events(:,2));
arrivals(indices) = true;
assert(isequal(G.waitSteps(indices),sum(events(:,4:6),2)/p.stepSeconds) ...
    && isequal(extra(indices),sum(events(:,5:6),2)/p.stepSeconds), ...
    'SBahn:AssignedDwell','Die Halteuhr passt nicht zum vergebenen Aufenthalt.');
notArriving = ~arrivals(2:end,:);
expectedWait = max(0,G.waitSteps(1:end-1,:)-1);
expectedExtra = min(extra(1:end-1,:),G.waitSteps(2:end,:));
actualWait = G.waitSteps(2:end,:); actualExtra = extra(2:end,:);
assert(isequal(actualWait(notArriving),expectedWait(notArriving)) ...
    && isequal(actualExtra(notArriving),expectedExtra(notArriving)), ...
    'SBahn:DwellCountdown','Geplante oder zusätzliche Haltezeit wird nicht vollständig abgezählt.');

closureLimits = inf(size(G.position));
permission = false(1,p.trainCount);
activated = false;
graceLog = zeros(0,3);
for row = 1:numel(G.timeSeconds)
    active = c.closureEnabled && G.timeSeconds(row) >= c.closureStartSeconds ...
        && G.timeSeconds(row) < c.closureStartSeconds+c.closureDurationSeconds;
    if active
        entry = mod(p.blocks.startCells(c.closureBlock)-G.position(row,:),p.cellCount);
        entry(entry == 0) = p.cellCount;
        if ~activated
            minimumNext = max(0,G.velocity(row,:)-1);
            permission = p.config.motionModel == "Beschleunigen und Bremsen" ...
                & minimumNext.*(minimumNext+1)/2 > entry-1;
            granted = find(permission);
            graceLog = [repmat(G.timeSeconds(row),numel(granted),1), ...
                granted',repmat(c.closureBlock,numel(granted),1)];
            activated = true;
        end
        restricted = ~permission;
        closureLimits(row,restricted) = entry(restricted)-1;
    else
        permission(:) = false;
    end
    assert(isequal(G.closurePermission(row,:),permission),'SBahn:ClosurePermission', ...
        'Eine letzte Einfahrerlaubnis wurde falsch erteilt oder nicht verbraucht.');
    if active && row < numel(G.timeSeconds)
        moved = mod(G.position(row+1,:)-G.position(row,:),p.cellCount);
        permission(entry <= moved & moved > 0) = false;
    end
end
assert(isequal(state.closureGraceLog,graceLog),'SBahn:ClosureGraceLog', ...
    'Das Protokoll letzter Einfahrten passt nicht zum Sperrbeginn.');
end
