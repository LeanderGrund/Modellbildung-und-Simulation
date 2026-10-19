function traffic = trafficLimits(position,p)
%trafficLimits - Freien Fahrweg und Blockbelegung aus Zugpositionen bestimmen
%   TRAFFIC = trafficLimits(POSITION,P) enthält den freien Fahrweg distance,
%   die Einzellimits bodyDistance und blockDistance, den Blockbesitz
%   blockOwner und die räumliche Zugreihenfolge order. POSITION ist die
%   Zugspitze; ihr Körper reicht TRAINCELLS-1 Zellen zurück, auch über den Ring.
%
%   See also sbahn.simulate
[sorted,traffic.order] = sort(position);
traffic.bodyDistance = zeros(size(position));
traffic.bodyDistance(traffic.order) = ...
    [diff(sorted),p.cellCount+sorted(1)-sorted(end)]-p.trainCells;
assert(all(traffic.bodyDistance >= 0),'SBahn:TrainOverlap', ...
    'Zugkörper überlappen. Bitte die Zugzahl verringern.');
traffic.blockDistance = inf(size(position));
traffic.blockOwner = zeros(size(p.blocks.startCells));
if ~isempty(traffic.blockOwner)
    for train = 1:numel(position)
        body = mod(position(train)-1-(0:p.trainCells-1),p.cellCount)+1;
        occupied = unique(p.blocks.cellBlock(body));
        assert(all(traffic.blockOwner(occupied) == 0),'SBahn:InitialBlockOverlap', ...
            ['Mehrere Züge belegen denselben Block. Bitte die Zugzahl oder den ' ...
            'gewählten Blockabstand verringern.']);
        traffic.blockOwner(occupied) = train;
    end
    % Blockzugänge begrenzen den Fahrweg unabhängig von der Geschwindigkeitswahl.
    for train = 1:numel(position)
        foreign = p.blocks.startCells(traffic.blockOwner > 0 & traffic.blockOwner ~= train);
        if ~isempty(foreign)
            traffic.blockDistance(train) = min(mod(foreign-position(train),p.cellCount))-1;
        end
    end
end
traffic.distance = min(traffic.bodyDistance,traffic.blockDistance);
end
