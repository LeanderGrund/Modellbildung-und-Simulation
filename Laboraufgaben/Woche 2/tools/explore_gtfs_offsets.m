function explore_gtfs_offsets
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'modell'));
c = sbahn2.defaultConfig;
c.trackMode = "Reale Ringbahn S41";
c.motionModel = "Beschleunigen und Bremsen";
c.dwellMode = "GTFS-Stationshalte";
c.blockMode = "Gleichmäßige Blockabschnitte";
c.blockLengthMeters = 500;
c.cruiseSpeedKmh = 16*3.6;
c.trainCount = 36;
c.animate = false;
c.initialPhaseSearch = true;
for offset = 0:6:30
    c.dwellOffsetSeconds = offset;
    [p,~] = sbahn2.prepare(c);
    fprintf('GTFS+%g s: Mittel=%g s, Umlauf=%g s, Phasenverschiebung=%g s\n', ...
        offset,mean(p.stationDwellSeconds),p.expectedLapSeconds,p.initialPhaseShiftSeconds);
end
end
