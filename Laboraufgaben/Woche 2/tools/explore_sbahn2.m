function explore_sbahn2
% Kleine Voruntersuchung zur Wahl ausführbarer Parameterbereiche.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'modell'));
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.motionModel = "Beschleunigen und Bremsen";
c.dwellMode = "GTFS-Stationshalte";
c.animate = false;
c.trainCount = 1;
c.durationMinutes = 1/60;
for v = 14:22
    c.cruiseSpeedKmh = 3.6*v;
    [p,~] = sbahn2.prepare(c);
    fprintf('v=%d lap=%g dep-return=%g\n',v,p.expectedLapSeconds, ...
        p.expectedLapSeconds-p.stationDwellSeconds(1));
end
c.cruiseSpeedKmh = 16*3.6;
c.durationMinutes = 20;
for mode = ["Ohne Blocksteuerung","Gleichmäßige Blockabschnitte"]
    c.blockMode = mode;
    c.blockLengthMeters = 500;
    for n = [8 12 16 20 24 28 32 36 40 44 48]
        c.trainCount = n;
        try
            [G,p,r] = sbahn2.simulate(c);
            fprintf('%s N=%d blocked=%g slow=%g departures=%d\n', ...
                mode,n,r.blockedTrainSeconds, ...
                nnz(G.velocity(2:end,:) < 16 & G.waitSteps(1:end-1,:) == 0), ...
                nnz(p.state.departureLog(:,3) == 1));
        catch e
            fprintf('%s N=%d REJECT %s\n',mode,n,e.identifier);
        end
    end
end
end
