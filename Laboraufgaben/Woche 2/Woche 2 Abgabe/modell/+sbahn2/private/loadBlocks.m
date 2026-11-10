function blocks = loadBlocks(model)
%loadBlocks - Blockanfänge aus einem Zielabstand oder OSM-Daten erzeugen
%   BLOCKS = loadBlocks(MODEL) ordnet jede Ringzelle genau einem Abschnitt
%   zu. Ein Abschnitt beginnt einschließlich seiner angegebenen Startzelle.
%
%   See also sbahn2.prepare
blocks = struct('startCells',zeros(1,0),'lengthMeters',zeros(1,0), ...
    'cellBlock',zeros(1,model.cellCount),'roundingMeters',zeros(1,0), ...
    'source',"Keine Blocksteuerung");
mode = model.config.blockMode;
if mode == "Ohne Blocksteuerung", return; end
if mode == "Gleichmäßige Blockabschnitte"
    count = ceil(model.route.lengthMeters/model.config.blockLengthMeters);
    assert(count <= model.cellCount,'SBahn:BlockGrid', ...
        'Der Blockabstand ist kleiner als eine Rasterzelle.');
    distance = (0:count-1)*model.route.lengthMeters/count;
    blocks.source = "Gleichmäßige Modellabschnitte; keine realen Signalstandorte";
else
    file = fullfile(model.config.dataFolder,'s41_signalkandidaten.csv');
    assert(isfile(file),'SBahn:SignalData','Die lokale Tabelle der OSM-Signalkandidaten fehlt.');
    signals = readtable(file,'TextType','string','Encoding','UTF-8','VariableNamingRule','preserve');
    assert(height(signals) == 117 && all(ismember(signals.category,["main","combined"])) ...
        && all(diff(signals.distance_m) > 0) && signals.distance_m(1) >= 0 ...
        && signals.distance_m(end) < model.route.sourceLengthMeters ...
        && numel(unique(signals.osm_node_id)) == height(signals),'SBahn:SignalData', ...
        'Die OSM-Tabelle muss 117 geordnete Haupt-/Mehrabschnittssignale enthalten.');
    distance = signals.distance_m';
    blocks.source = "117 gerichtete OSM-Signalkandidaten (14.10.2026); betrieblich unbestätigt";
end
blocks.startCells = 1+mod(round(distance/model.dxMeters),model.cellCount);
assert(numel(unique(blocks.startCells)) == numel(distance),'SBahn:BlockGrid', ...
    'Mehrere Blockanfänge fallen auf dieselbe Rasterzelle.');
blocks.roundingMeters = (blocks.startCells-1)*model.dxMeters-distance;
blocks.lengthMeters = diff([blocks.startCells,blocks.startCells(1)+model.cellCount])*model.dxMeters;
for block = 1:numel(blocks.startCells)
    cells = mod(blocks.startCells(block)-1+(0:round(blocks.lengthMeters(block)/model.dxMeters)-1), ...
        model.cellCount)+1;
    blocks.cellBlock(cells) = block;
end
assert(all(blocks.cellBlock > 0),'SBahn:BlockCoverage','Die Blöcke decken den Ring nicht vollständig ab.');
end
