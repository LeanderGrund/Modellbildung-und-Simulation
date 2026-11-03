function state = updateClosure(state,p)
%updateClosure - Zeitweise Sperre eines Blockzugangs und letzte Einfahrten setzen
%   STATE = updateClosure(STATE,P) wird vor jedem Zeitschritt aufgerufen.
%   Bereits zu nahe Züge erhalten bei Sperrbeginn genau eine letzte Einfahrt.
%
%   See also sbahn2.simulate
c = p.config;
state.closureActive = c.closureEnabled && state.timeSeconds >= c.closureStartSeconds ...
    && state.timeSeconds < c.closureStartSeconds+c.closureDurationSeconds;
state.closureDistance(:) = inf;
if ~state.closureActive
    state.closurePermission(:) = false;
    return
end
block = c.closureBlock;
entry = mod(p.blocks.startCells(block)-state.position,p.cellCount);
entry(entry == 0) = p.cellCount; % Wer schon auf der Grenze steht, darf weiterfahren.
if ~state.closureActivated
    minimumNext = max(0,state.velocity-1);
    cannotStop = p.config.motionModel == "Beschleunigen und Bremsen" ...
        & minimumNext.*(minimumNext+1)/2 > entry-1;
    state.closurePermission = cannotStop;
    state.closureActivated = true;
    granted = find(state.closurePermission);
    state.closureGraceLog = [repmat(state.timeSeconds,numel(granted),1), ...
        granted',repmat(block,numel(granted),1)];
end
restricted = ~state.closurePermission;
state.closureDistance(restricted) = entry(restricted)-1;
end
