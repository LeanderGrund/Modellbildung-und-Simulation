function uiResults = pruefe_live_geschwindigkeit
%PRUEFE_LIVE_GESCHWINDIGKEIT Native MLX-Konvertierung und Eingabe bis Modell prüfen.
% Der tatsächlich gespeicherte Code wird ausgeführt; nur Testdauer,
% Wiedergabe und der Editorpfad werden für den Batchlauf überschrieben.
root = fileparts(fileparts(mfilename('fullpath')));
project = fullfile(root,'..','Woche 1','NaSch-SBahn');
addpath(project);
out = fullfile(root,'ergebnisse','ui_geschwindigkeit');
if ~isfolder(out), mkdir(out); end
sourceFile = fullfile(project,'SBahn_demo.mlx');
convertedFile = fullfile(out,'SBahn_demo_import.m');
matlab.internal.liveeditor.openAndConvert(sourceFile,convertedFile);
template = fileread(convertedFile);
assert(contains(template,"'cruiseSpeedKmh',maximalgeschwindigkeitKmh"), ...
    'SBahn:LiveSpeedConfig','Die Live-Eingabe ist nicht mit der Konfiguration verbunden.');
template = strrep(template, ...
    'projektordner = fileparts(matlab.desktop.editor.getActiveFilename);', ...
    sprintf('projektordner = ''%s'';',strrep(project,'''','''''')));
template = regexprep(template,'(?m)^simulationsdauerMinuten\s*=\s*[^;\r\n]+;', ...
    'simulationsdauerMinuten = 2;');
template = regexprep(template,'(?m)^animation\s*=\s*[^;\r\n]+;', ...
    'animation = false;');
visibility = get(groot,'DefaultFigureVisible');
restoreVisibility = onCleanup(@() set(groot,'DefaultFigureVisible',visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
uiResults = table();
for requested = [57.6 60 80]
    previousFigures = findall(groot,'Type','figure');
    executable = regexprep(template,'(?m)^maximalgeschwindigkeitKmh\s*=\s*[^;\r\n]+;', ...
        sprintf('maximalgeschwindigkeitKmh = %.15g;',requested));
    capturedOutput = evalc(executable); %#ok<NASGU>
    assert(laufErfolgreich,'SBahn:LiveSpeedRun','Der aus dem Live-Skript importierte Lauf ist fehlgeschlagen.');
    assert(vergleich.available && isfinite(vergleich.freeAbsoluteErrorSeconds), ...
        'SBahn:LiveTimetable','Der freie GTFS-Fehler wird nicht ausgegeben.');
    assert(vergleich.completedTripCount == 0 && isnan(vergleich.measuredAbsoluteErrorSeconds), ...
        'SBahn:LiveTimetablePartial','Ein unvollständiger Lauf darf keinen gemessenen Fehler ausgeben.');
    assert(any(fahrplanvergleich.Fahrplanvergleich == "Absoluter Fehler frei gegenüber GTFS [s]"), ...
        'SBahn:LiveTimetableDisplay','Die Fehlertabelle fehlt im Live-Skript.');
    axesHandles = findall(raumZeitDiagramm,'Type','axes');
    for axisHandle = axesHandles'
        assert(isequal(axisHandle.XColor,[0 0 0]) && isequal(axisHandle.YColor,[0 0 0]), ...
            'SBahn:PlotContrast','Die Achsenbeschriftung ist nicht schwarz.');
    end
    for textHandle = findall(raumZeitDiagramm,'Type','text')'
        if ~isempty(textHandle.String)
            assert(isequal(textHandle.Color,[0 0 0]),'SBahn:PlotContrast','Ein Diagrammtext ist nicht schwarz.');
        end
    end
    expected = floor(requested/3.6)*3.6;
    assert(p.config.cruiseSpeedKmh == requested && abs(p.driveSpeedKmh-expected) < 1e-10, ...
        'SBahn:LiveSpeedValue','Eingabe und tatsächlich verwendete Geschwindigkeitsstufe stimmen nicht.');
    assert(abs(report.maxObservedSpeedKmh-expected) < 1e-10 && report.checksPassed, ...
        'SBahn:LiveSpeedBound','Der Lauf verwendet nicht die erwartete maximale Geschwindigkeitsstufe.');
    displayed = aktiveEinstellungen.Wert(aktiveEinstellungen.Einstellung == ...
        "Eingegebene Maximalgeschwindigkeit [km/h]");
    assert(isequal(displayed,string(compose('%.2f km/h',requested))), ...
        'SBahn:LiveSpeedDisplay','Die Anzeige enthält nicht die eingegebene Grenze.');
    if requested == 57.6
        firstTrace = G;
    elseif requested == 60
        assert(isequaln(firstTrace,G),'SBahn:LiveSpeedRounding', ...
            '57,6 und 60 km/h sollten dieselbe diskrete Geschwindigkeitsstufe ergeben.');
    end
    uiResults = [uiResults;table(requested,p.vmax,p.driveSpeedKmh,report.maxObservedSpeedKmh, ...
        report.checksPassed,'VariableNames',{'input_kmh','speed_level_mps','effective_limit_kmh', ...
        'observed_max_kmh','passed'})]; %#ok<AGROW>
    if requested == 80
        exportgraphics(raumZeitDiagramm,fullfile(out,'raumzeit_schwarze_beschriftung.png'), ...
            'Resolution',160,'BackgroundColor','white');
    end
    delete(setdiff(findall(groot,'Type','figure'),previousFigures));
end
writetable(uiResults,fullfile(out,'live_eingabepruefung.csv'));
disp(uiResults);
fprintf('Native MLX-Datei, Weitergabe, Anzeige und Geschwindigkeitsgrenzen geprüft.\n');
end
