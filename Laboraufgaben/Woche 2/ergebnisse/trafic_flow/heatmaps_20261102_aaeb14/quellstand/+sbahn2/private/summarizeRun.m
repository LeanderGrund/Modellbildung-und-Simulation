function report = summarizeRun(G,p,state)
%summarizeRun - Kennzahlen aus vollständig beobachteten Ereignissen berechnen
%   REPORT = summarizeRun(G,P,STATE) ignoriert unvollständige Halte und
%   Umläufe am Anfang beziehungsweise Ende der Beobachtungszeit.
%
%   See also sbahn2.simulate

dwellSeconds = zeros(0,1);
requiredDwellSeconds = zeros(0,1);
lapSeconds = zeros(0,1);
for train = 1:p.trainCount
    arrivals = state.arrivalLog(state.arrivalLog(:,2) == train,:);
    for station = 1:p.stationCount
        atStation = arrivals(arrivals(:,3) == station,1);
        lapSeconds = [lapSeconds;diff(atStation)]; %#ok<AGROW>
        departures = state.departureLog(state.departureLog(:,2) == train & ...
            state.departureLog(:,3) == station,1);
        for arrival = atStation'
            departure = departures(find(departures >= arrival,1));
            if ~isempty(departure)
                dwellSeconds(end+1,1) = departure-arrival; %#ok<AGROW>
                event = state.stopLog(state.stopLog(:,1) == arrival & state.stopLog(:,2) == train,:);
                requiredDwellSeconds(end+1,1) = sum(event(4:6)); %#ok<AGROW>
            end
        end
    end
end
departureTimes = sort(state.departureLog(state.departureLog(:,3) == 1,1));
headways = diff(departureTimes);
report.minimumDwellsSatisfied = all(dwellSeconds >= requiredDwellSeconds-1e-9);
report.allStationsVisited = all(state.visitCount > 0,'all');
report.blockedTrainSeconds = sum(G.blocked,'all')*p.stepSeconds;
report.signalBlockedTrainSeconds = sum(G.signalBlocked,'all')*p.stepSeconds;
report.closureBlockedTrainSeconds = sum(G.closureBlocked,'all')*p.stepSeconds;
report.occupiedBlockTrainSeconds = sum(G.signalBlocked & ~G.closureBlocked,'all')*p.stepSeconds;
report.targetedStopCount = nnz(state.stopLog(:,5));
report.randomStopCount = nnz(state.stopLog(:,6));
report.assignedTargetedSeconds = sum(state.stopLog(:,5));
report.assignedRandomSeconds = sum(state.stopLog(:,6));
report.observedExtraHoldTrainSeconds = sum(G.extraWaitSteps(1:end-1,:) > 0 & ...
    G.waitSteps(1:end-1,:) == G.extraWaitSteps(1:end-1,:),'all')*p.stepSeconds;
report.plannedHoldTrainSeconds = sum(G.waitSteps(1:end-1,:) > G.extraWaitSteps(1:end-1,:),'all')*p.stepSeconds;
report.closureGraceCount = size(state.closureGraceLog,1);
report.trainLengthMeters = p.effectiveTrainLengthMeters;
report.blockCount = numel(p.blocks.startCells);
report.maxSimultaneouslyBlocked = max(sum(G.blocked,2));
report.blockedTrainCount = nnz(any(G.blocked,1));
report.stationDwellSeconds = p.stationDwellSeconds;
report.stationRoundingMeters = p.route.stationRoundingMeters;
report.maxStationRoundingMeters = max(abs(p.route.stationRoundingMeters));
report.completeDwellCount = numel(dwellSeconds);
report.meanDwellSeconds = mean(dwellSeconds);
report.minDwellSeconds = minOrNaN(dwellSeconds);
report.maxDwellSeconds = maxOrNaN(dwellSeconds);
report.meanLapSeconds = mean(lapSeconds);
report.meanHeadwaySeconds = mean(headways);
report.minHeadwaySeconds = minOrNaN(headways);
report.maxHeadwaySeconds = maxOrNaN(headways);
report.meanSpeedKmh = mean(state.movedCells)*p.dxMeters/state.timeSeconds*3.6;
report.expectedLapSeconds = p.expectedLapSeconds;
report.expectedHeadwaySeconds = p.expectedHeadwaySeconds;
report.driveSpeedKmh = p.driveSpeedKmh;
report.maxObservedSpeedKmh = max(G.velocity,[],'all')*p.speedUnitKmh;
report.maxAccelerationMetersPerSecondSquared = ...
    max(0,max(diff(G.velocity,1,1),[],'all'))*p.dxMeters/p.stepSeconds^2;
report.maxBrakingMetersPerSecondSquared = ...
    max(0,-min(diff(G.velocity,1,1),[],'all'))*p.dxMeters/p.stepSeconds^2;
report.trainCount = p.trainCount;
report.stationVisitsPerTrain = sum(state.visitCount,2);
end

function value = minOrNaN(values)
%minOrNaN - Return NaN when no observations exist
if isempty(values), value = NaN; else, value = min(values); end
end

function value = maxOrNaN(values)
%maxOrNaN - Return NaN when no observations exist
if isempty(values), value = NaN; else, value = max(values); end
end
