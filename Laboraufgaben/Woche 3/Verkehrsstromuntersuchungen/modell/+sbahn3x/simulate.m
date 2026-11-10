function [G,p,report] = simulate(config)
%simulate - Das gewählte Fahrmodell mit expliziten Zugzuständen berechnen
%   [G,P,REPORT] = sbahn3x.simulate(CONFIG) liefert die Trajektorien,
%   feste Modellparameter und den Prüfbericht. P.state enthält den
%   letzten Zugzustand; die Zugnummer ist der jeweilige Arrayindex.
%
%   See also sbahn3x.defaultConfig, sbahn3x.plotResults
arguments
    config (1,1) struct
end
[p,state] = sbahn3x.prepare(config);
G.timeSeconds = (0:p.stepCount)'*p.stepSeconds;
G.position = zeros(p.stepCount+1,p.trainCount);
G.velocity = zeros(p.stepCount+1,p.trainCount);
G.waitSteps = zeros(p.stepCount+1,p.trainCount);
G.blocked = false(p.stepCount+1,p.trainCount);
G.signalBlocked = false(p.stepCount+1,p.trainCount);
G.extraWaitSteps = zeros(p.stepCount+1,p.trainCount);
G.closureBlocked = false(p.stepCount+1,p.trainCount);
G.closurePermission = false(p.stepCount+1,p.trainCount);
if p.config.randomBrakeEnabled
    G.randomBrakeTarget = nan(p.stepCount+1,p.trainCount);
    G.randomBrakeApplied = false(p.stepCount+1,p.trainCount);
end
if p.config.anticipationEnabled
    G.anticipationApplied = false(p.stepCount+1,p.trainCount);
    G.anticipationEligible = false(p.stepCount+1,p.trainCount);
end
stream = RandStream('mt19937ar','Seed',p.config.randomSeed);
h = [];
for k = 1:p.stepCount+1
    state = updateClosure(state,p);
    G.position(k,:) = state.position;
    G.velocity(k,:) = state.velocity;
    G.waitSteps(k,:) = state.waitSteps;
    G.blocked(k,:) = state.blockedLastStep;
    G.signalBlocked(k,:) = state.signalBlockedLastStep;
    G.extraWaitSteps(k,:) = state.extraWaitSteps;
    G.closureBlocked(k,:) = state.closureBlockedLastStep;
    G.closurePermission(k,:) = state.closurePermission;
    if p.config.randomBrakeEnabled
        G.randomBrakeTarget(k,:) = state.randomBrakeTarget;
        G.randomBrakeApplied(k,:) = state.randomBrakeLastStep;
    end
    if p.config.anticipationEnabled
        G.anticipationApplied(k,:) = state.anticipationLastStep;
        G.anticipationEligible(k,:) = state.anticipationEligibleLastStep;
    end
    if p.config.animate && (mod(k-1,p.config.displayEvery) == 0 || k == p.stepCount+1)
        h = drawState(state,p,h);
        if p.config.framePauseSeconds > 0 && k <= p.stepCount
            pause(p.config.framePauseSeconds);
        end
    end
    if k <= p.stepCount
        state = advance(state,p,stream);
    end
end
report = summarizeRun(G,p,state);
verifyRun(G,p,state,report);
report.checksPassed = true;
p.state = state;
end
