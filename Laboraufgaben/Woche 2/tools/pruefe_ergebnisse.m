function pruefe_ergebnisse
%PRUEFE_ERGEBNISSE Gespeicherte Daten und Fehlersensitivität nachprüfen.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'modell'));
out = fullfile(root,'ergebnisse');
file = fullfile(root,'..','Woche 1','NaSch-SBahn','daten', ...
    'ringbahn_2026-10-14','processed','s41_example_timetable.csv');
options = detectImportOptions(file,'TextType','string');
options = setvartype(options,{'arrival_time','departure_time'},'string');
t = readtable(file,options);
referenceSeconds = seconds(duration(t.arrival_time(end),'InputFormat','hh:mm:ss') - ...
    duration(t.departure_time(1),'InputFormat','hh:mm:ss'));
assert(referenceSeconds == 3558,'SBahn2:ReferenceImport','Referenzimport fehlerhaft.');

d = load(fullfile(out,'laeufe','zugzahl_40.mat'));
sanity_check(d.G,d.p,d.report);
% Absichtlich verfälschte Daten müssen von den Sanity Checks erkannt werden.
wrong = d.G; wrong.velocity(2,1) = d.p.vmax+1;
expectError(@() sanity_check(wrong,d.p,d.report),'SBahn2:Speed');
wrong = d.G; wrong.position(2,1) = wrong.position(2,1)+1;
expectError(@() sanity_check(wrong,d.p,d.report),'SBahn2:Movement');

% Zeitfenster an zwei Punkten im Sättigungsbereich separat auswerten.
windows = table();
for n = [32 36 40]
    d = load(fullfile(out,'laeufe',sprintf('zugzahl_%02d.mat',n)));
    for start = [3600 7200 10800]
        log = d.p.state.departureLog;
        count = nnz(log(:,3) == 1 & log(:,1) >= start & log(:,1) < start+3600);
        selected = d.G.timeSeconds(1:end-1) >= start & d.G.timeSeconds(1:end-1) < start+3600;
        blocked = d.G.blocked(2:end,:);
        wait = nnz(blocked(selected,:))/n;
        windows = [windows;table(n,start,count,wait,'VariableNames', ...
            {'train_count','window_start_s','throughput_trains_per_h','blocked_s_per_train_h'})]; %#ok<AGROW>
    end
end
writetable(windows,fullfile(out,'messfensterkontrolle.csv'));
disp(windows);
fprintf('Referenzimport, gespeicherte Daten und beide absichtlichen Fehler korrekt geprueft.\n');
end

function expectError(action,identifier)
try
    action();
catch e
    assert(strcmp(e.identifier,identifier),'SBahn2:WrongGuard','Falsche Fehlererkennung: %s.',e.identifier);
    return
end
error('SBahn2:MissingGuard','Absichtlicher Fehler wurde nicht erkannt.');
end
