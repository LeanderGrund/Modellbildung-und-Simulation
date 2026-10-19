function profile = loadDwellProfile(route)
%loadDwellProfile - Typische geplante S41-Haltezeiten aus GTFS bestimmen
%   PROFILE = loadDwellProfile(ROUTE) liefert den Median je Station
%   für den Fahrplantag 14.10.2026 sowie die Anzahl gültiger Quellhalte.
%   Anfang und Ende jedes GTFS-Trips werden ausgeschlossen.
%
%   See also sbahn.prepare, readtable
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
folder = fullfile(root,'daten','ringbahn_2026-10-14');
processed = fullfile(folder,'processed');
routes = readtable(fullfile(processed,'gtfs_routes.csv'),'TextType','string');
trips = readtable(fullfile(processed,'gtfs_trips.csv'),'TextType','string');
calendar = readtable(fullfile(processed,'gtfs_calendar.csv'),'TextType','string');
exceptions = readtable(fullfile(processed,'gtfs_calendar_dates.csv'),'TextType','string');
stops = readtable(fullfile(processed,'gtfs_stops.csv'),'TextType','string');
referenceDate = 20261014; % Mittwoch; keine Änderung auf das heutige Datum.
regular = calendar.start_date <= referenceDate & ...
    calendar.end_date >= referenceDate & calendar.wednesday == 1;
activeServices = string(calendar.service_id(regular));
added = exceptions.date == referenceDate & exceptions.exception_type == 1;
removed = exceptions.date == referenceDate & exceptions.exception_type == 2;
activeServices = setdiff(union(activeServices,string(exceptions.service_id(added))), ...
    string(exceptions.service_id(removed)));
s41 = string(routes.route_id(routes.route_short_name == "S41"));
selected = ismember(string(trips.route_id),s41) & ...
    ismember(string(trips.service_id),activeServices);
tripIds = string(trips.trip_id(selected));
assert(~isempty(tripIds),'SBahn:DwellServices', ...
    'Keine aktiven S41-Fahrten für den gespeicherten Fahrplantag gefunden.');
file = fullfile(processed,'gtfs_stop_times.csv');
options = detectImportOptions(file,'TextType','string');
options = setvartype(options,{'arrival_time','departure_time'},'string');
times = readtable(file,options);
times = times(ismember(string(times.trip_id),tripIds),:);
group = findgroups(string(times.trip_id));
first = splitapply(@min,times.stop_sequence,group);
last = splitapply(@max,times.stop_sequence,group);
interior = times.stop_sequence > first(group) & times.stop_sequence < last(group);
times = times(interior & ~ismissing(times.arrival_time) & ...
    ~ismissing(times.departure_time),:);
parent = stops.parent_station;
missingParent = ismissing(parent) | strlength(parent) == 0;
parent(missingParent) = stops.stop_id(missingParent);
[known,index] = ismember(times.stop_id,stops.stop_id);
assert(all(known),'SBahn:DwellStops','Ein GTFS-Halt hat keine bekannte Station.');
parents = parent(index);
secondsAtStop = seconds(duration(times.departure_time,'InputFormat','hh:mm:ss') ...
    -duration(times.arrival_time,'InputFormat','hh:mm:ss'));
assert(all(isfinite(secondsAtStop) & secondsAtStop >= 0), ...
    'SBahn:DwellTimes','Ungültige geplante GTFS-Haltezeit.');
profile.seconds = zeros(1,numel(route.stationNames));
profile.sampleCounts = zeros(1,numel(route.stationNames));
for station = 1:numel(route.stationNames)
    values = secondsAtStop(parents == route.gtfsParentStationIds(station));
    assert(~isempty(values),'SBahn:DwellMissing', ...
        'Für die Station %s fehlen gültige GTFS-Haltezeiten.',route.stationNames(station));
    profile.seconds(station) = median(values);
    profile.sampleCounts(station) = numel(values);
end
profile.source = "VBB-GTFS: Median gültiger S41-Zwischenhalte am 14.10.2026; geplante Zeiten, keine Ist-Messungen";
end
