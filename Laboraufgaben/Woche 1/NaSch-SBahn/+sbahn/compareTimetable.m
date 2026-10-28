function comparison = compareTimetable(p)
%COMPARETIMETABLE Fahrzeitfehler gegenüber dem lokalen S41-GTFS bestimmen.
% Verglichen wird Abfahrt Beusselstraße bis Rückkehrankunft, ohne den
% Aufenthalt am Startbahnhof. Der gemessene Fehler ist der Betrag der
% Differenz zwischen mittlerer vollständig beobachteter Fahrzeit und GTFS.
arguments
    p (1,1) struct
end
comparison = struct('available',false,'referenceSeconds',NaN, ...
    'freeModelSeconds',NaN,'freeAbsoluteErrorSeconds',NaN, ...
    'measuredMeanSeconds',NaN,'measuredAbsoluteErrorSeconds',NaN, ...
    'completedTripCount',0,'samplesSeconds',zeros(0,1), ...
    'status',"GTFS-Vergleich benötigt die reale Ringbahn S41.");
if p.config.trackMode ~= "Reale Ringbahn S41", return; end
root = fileparts(fileparts(mfilename('fullpath')));
file = fullfile(root,'daten','ringbahn_2026-10-14','processed','s41_example_timetable.csv');
options = detectImportOptions(file,'TextType','string');
options = setvartype(options,{'arrival_time','departure_time'},'string');
timetable = readtable(file,options);
assert(timetable.gtfs_parent_station_id(1) == p.route.gtfsParentStationIds(1), ...
    'SBahn:TimetableStart','Modell und GTFS müssen an derselben Station beginnen.');
comparison.available = true;
comparison.referenceSeconds = seconds( ...
    duration(timetable.arrival_time(end),'InputFormat','hh:mm:ss') - ...
    duration(timetable.departure_time(1),'InputFormat','hh:mm:ss'));
comparison.freeModelSeconds = p.expectedLapSeconds-p.stationDwellSeconds(1);
comparison.freeAbsoluteErrorSeconds = abs(comparison.freeModelSeconds-comparison.referenceSeconds);
for train = 1:p.trainCount
    departures = p.state.departureLog;
    arrivals = p.state.arrivalLog;
    departures = departures(departures(:,2) == train & departures(:,3) == 1,1);
    arrivals = arrivals(arrivals(:,2) == train & arrivals(:,3) == 1,1);
    for departure = departures'
        returned = arrivals(find(arrivals > departure,1));
        if ~isempty(returned)
            comparison.samplesSeconds(end+1,1) = returned-departure; %#ok<AGROW>
        end
    end
end
comparison.completedTripCount = numel(comparison.samplesSeconds);
if comparison.completedTripCount > 0
    comparison.measuredMeanSeconds = mean(comparison.samplesSeconds);
    comparison.measuredAbsoluteErrorSeconds = abs(comparison.measuredMeanSeconds-comparison.referenceSeconds);
    comparison.status = "Abfahrt Beusselstraße bis Rückkehrankunft; gemessen über vollständig beobachtete Ringfahrten.";
else
    comparison.status = "Noch keine vollständige Ringfahrt beobachtet: gemessener Fehler ist NaN. Für diesen Wert länger simulieren.";
end
end
