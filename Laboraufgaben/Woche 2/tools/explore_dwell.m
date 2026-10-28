function explore_dwell
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'modell'));
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.motionModel = "Beschleunigen und Bremsen";
c.cruiseSpeedKmh = 16*3.6;
c.blockMode = "Gleichmäßige Blockabschnitte";
c.blockLengthMeters = 500;
c.animate = false;
c.durationMinutes = 5;
for n = [28 32 36]
    c.trainCount = n;
    for h = [15 20 25 30 34 40 45 50 55 60]
        c.stopSeconds = h;
        try
            [~,~,r] = sbahn2.simulate(c);
            fprintf('N=%d h=%d blocked=%g lap=%g\n',n,h,r.blockedTrainSeconds,r.expectedLapSeconds);
        catch e
            fprintf('N=%d h=%d REJECT %s\n',n,h,e.identifier);
        end
    end
end
end
