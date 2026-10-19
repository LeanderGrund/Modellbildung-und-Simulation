function [route,cellCount] = loadRoute(config)
%loadRoute - Die Strecke einmal laden und auf das gewählte Raster abbilden
%   [ROUTE,CELLCOUNT] = loadRoute(CONFIG) trennt Quellgeometrie und
%   gerundete Modellpositionen. Jeder Datenstand wird nur einmal gelesen.
%
%   See also sbahn.prepare

if config.trackMode == "Idealisierter Ring"
    route.lengthMeters = 37000;
    route.stationNames = compose("H%02d",1:27);
    route.stationDistanceMeters = (0:26)*37000/27;
    route.source = "Idealisierter Ring; gleichmäßige Stationsabstände";
    route.track = table();
else
    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    folder = fullfile(root,'daten','ringbahn_2026-10-14');
    stationFile = fullfile(folder,'s41_stations.csv');
    trackFile = fullfile(folder,'s41_track_points.csv');
    assert(isfile(stationFile) && isfile(trackFile),'SBahn:DataMissing', ...
        'Die lokalen S41-Streckendaten fehlen im Projektordner daten.');
    stations = readtable(stationFile,'TextType','string','Encoding','UTF-8');
    track = readtable(trackFile,'TextType','string','Encoding','UTF-8');
    assert(height(stations) == 27 && numel(unique(stations.station_name)) == 27, ...
        'SBahn:Stations','Der S41-Datenstand muss 27 eindeutige Stationen enthalten.');
    assert(isequal(stations.station_sequence,(1:27)') && ...
        stations.distance_m(1) == 0 && all(diff(stations.distance_m) > 0), ...
        'SBahn:StationOrder','Ungültige Stationsreihenfolge im S41-Datenstand.');
    assert(track.distance_m(1) == 0 && all(diff(track.distance_m) > 0) && ...
        norm([track.latitude(1)-track.latitude(end), ...
        track.longitude(1)-track.longitude(end)]) < 1e-8, ...
        'SBahn:Track','Der geografische Streckenverlauf muss ein geschlossener Ring sein.');
    route.lengthMeters = track.distance_m(end);
    assert(stations.distance_m(end) < route.lengthMeters, ...
        'SBahn:StationDistance','Stationsposition außerhalb des Rings.');
    route.stationNames = stations.station_name';
    route.stationDistanceMeters = stations.distance_m';
    route.gtfsParentStationIds = stations.gtfs_parent_station_id';
    route.track = track;
    route.source = "OpenStreetMap, S41; lokaler Datenstand 14.10.2026";
end
route.sourceLengthMeters = route.lengthMeters;
if config.motionModel == "Beschleunigen und Bremsen"
    cellCount = round(route.lengthMeters);
    route.lengthMeters = cellCount;
else
    cellCount = 2790;
end
dx = route.lengthMeters/cellCount;
if config.trackMode == "Idealisierter Ring" && config.motionModel == "On/Off"
    route.stationCells = 1+floor((0:26)*cellCount/27); % Bisherige Vergleichstrajektorie.
else
    route.stationCells = 1+mod(round(route.stationDistanceMeters/dx),cellCount);
end
assert(all(diff(route.stationCells) > 0),'SBahn:StationCells', ...
    'Die gerundeten Stationspositionen sind nicht eindeutig geordnet.');
route.stationRoundingMeters = (route.stationCells-1)*dx-route.stationDistanceMeters;
if config.trackMode == "Idealisierter Ring" && config.motionModel == "On/Off"
    route.stationRoundingMeters = ...
        (route.stationCells-1)*route.lengthMeters/cellCount-route.stationDistanceMeters;
end
end
