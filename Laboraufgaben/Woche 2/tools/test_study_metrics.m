function test_study_metrics
%TEST_STUDY_METRICS Bekannte Ereignisse prüfen insbesondere Intervallgrenzen.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
G.timeSeconds = (0:10)';
G.position = [1 2 5 1 1 1 2 5 1 1 1]';
G.blocked = false(11,1); G.blocked([5 6]) = true;
G.waitSteps = zeros(11,1);
p = struct('cellCount',100,'trainCount',1,'stepSeconds',1, ...
    'expectedLapSeconds',5,'route',struct('stationCells',1), ...
    'state',struct('arrivalLog',[3 1 1;8 1 1],'departureLog',[0 1 1;5 1 1]));
[m,laps] = trafic_flow_study_metrics(G,p,0,10);
assert(m.departure_count == 2 && m.throughput_trains_per_h == 720);
assert(m.complete_lap_count == 1 && m.blocked_s_per_train_lap == 2);
assert(laps.start_s == 3 && laps.end_s == 8);
[m,~] = trafic_flow_study_metrics(G,p,4,6);
assert(m.departure_count == 1 && m.throughput_trains_per_h == 600);
assert(m.complete_lap_count == 0 && isnan(m.blocked_s_per_train_lap));
G.blocked(:) = false; G.waitSteps(4:5) = 1;
[m,~] = trafic_flow_study_metrics(G,p,0,10);
assert(m.blocked_s_per_train_lap == 0);
fprintf('Kennzahlenprüfung bestanden: Detektor, Einschwingen, Umlaufgrenzen, Ausschluss von Stationshalten.\n');
end
