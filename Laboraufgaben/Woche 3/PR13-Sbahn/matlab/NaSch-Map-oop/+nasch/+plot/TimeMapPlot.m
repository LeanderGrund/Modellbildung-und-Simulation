function TimeMapPlot(map,varargin)
%TIMEMAPPLOT Plot selected results of a Map object.
%
% Optional inputs:
%   "map" : road-network topology
%   "avg" : mean velocity on all roads
%   [1 3] : time-space histories of selected roads

if ~map.plot, return; end

nroad = numel(map.roads);
showMap = false;
showAvg = false;
roads = [];

for k = 1:numel(varargin)
    arg = varargin{k};

    if ischar(arg) || (isstring(arg) && isscalar(arg))
        switch lower(string(arg))
            case "map", showMap = true;
            case "avg", showAvg = true;
            otherwise, error('Unknown option "%s".',string(arg));
        end
    elseif isnumeric(arg)
        roads = arg(:).';
    else
        error('Optional inputs must be "map", "avg", or road indices.');
    end
end

if any(roads < 1 | roads > nroad | roads ~= fix(roads))
    error('Road indices must be integers between 1 and %d.',nroad);
end

if ~showMap && ~showAvg && isempty(roads), return; end

% Use one common ID colormap for all roads.
colormapID = [];
if map.plot == 2
    maxID = 1;
    for k = 1:nroad
        id = max(imag(map.roads(k).G),[],'all','omitnan');
        if ~isempty(id) && ~isnan(id), maxID = max(maxID,id); end
    end

    if size(map.roads(1).colormap,1) >= maxID
        colormapID = map.roads(1).colormap;
    else
        colormapID = parula(maxID);
    end
end

clf;
tl = tiledlayout('flow','TileSpacing','compact','Padding','compact');

if showMap
    ax = nexttile(tl);
    G = digraph(map.node1,map.node2);
    h = plot(ax,G,'XData',map.nodex,'YData',map.nodey,'LineWidth',2);
    h.NodeLabel = {};
    labeledge(h,map.node1,map.node2,1:nroad);
    axis(ax,'equal');
    axis(ax,'off');
    title(ax,'road network');
end

if showAvg
    ax = nexttile(tl);
    hold(ax,'on');
    for k = 1:nroad
        vmean = mean(real(map.roads(k).G),2,'omitnan');
        plot(ax,1:numel(vmean),vmean,'DisplayName',sprintf('road %d',k));
    end
    grid(ax,'on');
    title(ax,'average velocity');
    xlabel(ax,'time');
    ylabel(ax,'velocity');
    legend(ax,'Location','best');
end

for k = roads
    ax = nexttile(tl);
    nasch.plot.TimeStreetPlot(map.roads(k),ax,colormapID);
    title(ax,sprintf('road %d',k));
end

end
