function [metrics,laps] = trafic_flow_study_metrics(G,p,warmupSeconds,measurementSeconds)
%TRAFIC_FLOW_STUDY_METRICS Durchsatz und blockierte Sekunden je vollem Umlauf.
% Umläufe: Ankunft Station 1 bis nächste Ankunft dort, vollständig im Messfenster.
finish = warmupSeconds+measurementSeconds;
starts = G.timeSeconds(1:end-1);
selected = starts >= warmupSeconds & starts < finish;
moving = mod(diff(G.position,1,1),p.cellCount) > 0;
detector = G.position(1:end-1,:) == p.route.stationCells(1) & moving;
count = nnz(detector(selected,:));
departures = p.state.departureLog;
logged = departures(:,3) == 1 & departures(:,1) >= warmupSeconds & departures(:,1) < finish;
assert(count == nnz(logged),'TrafficStudy:Detector','Positions- und Ereignisdetektor widersprechen sich.');
blocked = G.blocked(2:end,:);
assert(~any(blocked & (moving | G.waitSteps(1:end-1,:) > 0),'all'), ...
    'TrafficStudy:Blocked','Blockierter Stillstand enthält Bewegung oder Stationshalte.');
samples = zeros(0,5);
arrivals = p.state.arrivalLog;
for train = 1:p.trainCount
    times = arrivals(arrivals(:,2) == train & arrivals(:,3) == 1,1);
    for index = 1:numel(times)-1
        first = times(index); last = times(index+1);
        if first >= warmupSeconds && last <= finish
            rows = round(first/p.stepSeconds)+1:round(last/p.stepSeconds);
            seconds = nnz(blocked(rows,train))*p.stepSeconds;
            samples(end+1,:) = [train,first,last,last-first,seconds]; %#ok<AGROW>
        end
    end
end
laps = array2table(samples,'VariableNames', ...
    {'train','start_s','end_s','duration_s','blocked_s'});
metrics = struct('throughput_trains_per_h',count/(measurementSeconds/3600), ...
    'departure_count',count,'free_throughput_trains_per_h',3600*p.trainCount/p.expectedLapSeconds, ...
    'complete_lap_count',height(laps),'trains_with_complete_laps',numel(unique(samples(:,1))), ...
    'blocked_s_per_train_lap',mean(samples(:,5)), ...
    'mean_complete_lap_s',mean(samples(:,4)), ...
    'blocked_train_s_measurement',nnz(blocked(selected,:))*p.stepSeconds, ...
    'free_lap_s',p.expectedLapSeconds,'warmup_s',warmupSeconds, ...
    'measurement_s',measurementSeconds,'detector_check_passed',true);
end
