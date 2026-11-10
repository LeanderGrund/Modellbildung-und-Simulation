function h = drawState(state,p,h)
%drawState - Den aktuellen Zustand auf Ring oder Streckenverlauf anzeigen
%   H = drawState(STATE,P,H) aktualisiert die laufende Animation.
%
%   See also sbahn2.simulate
id = 1:numel(state.position);
x = state.position;
stopped = state.velocity == 0 | state.waitSteps(id) > 0;
colors = [0.85 0.25 0.15;0.1 0.6 0.35];
color = colors(double(~stopped)+1,:);
color(state.blockedLastStep(id),:) = repmat([0.95 0.55 0.05],nnz(state.blockedLastStep(id)),1);
extraHold = state.extraWaitSteps > 0 & state.waitSteps == state.extraWaitSteps;
color(extraHold,:) = repmat([0.55 0.15 0.8],nnz(extraHold),1);
[tx,ty] = coordinates((x-1)*p.dxMeters,p);
if isempty(h) || ~isgraphics(h.ax)
    h.fig = figure('Name','S-Bahn: laufende Simulation','Color','w');
    h.ax = axes(h.fig);
    hold(h.ax,'on');
    [rx,ry] = coordinates(linspace(0,p.route.lengthMeters,1500),p);
    plot(h.ax,rx,ry,'Color',[0.25 0.25 0.25],'LineWidth',1.5);
    [sx,sy] = coordinates((p.route.stationCells-1)*p.dxMeters,p);
    scatter(h.ax,sx,sy,28,[0.4 0.4 0.4],'s','filled');
    if p.config.displayMode == "Geografischer Streckenverlauf"
        labels = compose('%02d',1:p.stationCount);
        xlabel(h.ax,'Ost-West-Abstand [km]');
        ylabel(h.ax,'Nord-Süd-Abstand [km]');
    else
        if p.config.trackMode == "Reale Ringbahn S41"
            labels = compose('%02d',1:p.stationCount);
        else
            labels = p.route.stationNames;
        end
        quiver(h.ax,-0.15,0.05,0.3,0,0,'k');
        text(h.ax,0,0.16,'Im Uhrzeigersinn','HorizontalAlignment','center');
        axis(h.ax,'off');
    end
    if p.config.displayMode == "Schematischer Ring"
        sx = 1.12*sx; sy = 1.2*sy;
    end
    text(h.ax,sx,sy,labels,'FontSize',8, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom');
    h.blocks = gobjects(0);
    if ~isempty(p.blocks.startCells)
        [bx,by] = coordinates((p.blocks.startCells-1)*p.dxMeters,p);
        h.blocks = scatter(h.ax,bx,by,12,'filled');
    end
    h.body = gobjects(1,numel(id));
    for train = id
        h.body(train) = plot(h.ax,NaN,NaN,'LineWidth',4);
    end
    h.trains = scatter(h.ax,tx,ty,24,color,'filled');
    [lx,ly] = labelCoordinates(tx,ty,p);
    h.labels = text(h.ax,lx,ly,compose('%d',id),'FontSize',9, ...
        'FontWeight','bold','HorizontalAlignment','center');
    h.status = text(h.ax,0.01,0.06,'','Units','normalized','FontSize',9, ...
        'VerticalAlignment','bottom','BackgroundColor','w','Margin',1);
    axis(h.ax,'equal');
    xlim(h.ax,[min(rx)-0.2*range(rx),max(rx)+0.2*range(rx)]);
    ylim(h.ax,[min(ry)-0.2*range(ry),max(ry)+0.2*range(ry)]);
else
    h.trains.XData = tx;
    h.trains.YData = ty;
    h.trains.CData = color;
    [lx,ly] = labelCoordinates(tx,ty,p);
    for j = 1:numel(id)
        h.labels(j).Position = [lx(j),ly(j),0];
        h.labels(j).String = sprintf('%d',id(j));
    end
end
for train = id
    cells = linspace(0,p.trainCells-1,min(p.trainCells,32));
    distance = mod(x(train)-1-cells,p.cellCount)*p.dxMeters;
    [bx,by] = coordinates(distance,p);
    breaks = [false,abs(diff(distance)) > p.route.lengthMeters/2];
    bx(breaks) = NaN; by(breaks) = NaN;
    h.body(train).XData = bx; h.body(train).YData = by;
    h.body(train).Color = color(train,:);
end
if ~isempty(h.blocks)
    traffic = trafficLimits(state.position,p);
    owner = traffic.blockOwner;
    blockColors = repmat([0.2 0.65 0.35],numel(owner),1);
    blockColors(owner > 0,:) = repmat([0.8 0.15 0.15],nnz(owner > 0),1);
    if state.closureActive
        blockColors(p.config.closureBlock,:) = [0.55 0.15 0.8];
    end
    h.blocks.CData = blockColors;
end
heading = {sprintf('S-Bahn: %.1f min | %g Züge blockiert', ...
    state.timeSeconds/60,nnz(state.blockedLastStep)), ...
    'Züge: Grün Fahrt | Rot Halt | Orange blockiert'};
if ~isempty(h.blocks)
    heading{end+1} = 'Blockpunkte: Grün frei | Rot belegt | Violett gesperrt';
end
if any(extraHold), heading{end+1} = 'Violette Züge: zusätzlicher Stationshalt'; end
title(h.ax,heading,'FontSize',9);
if state.blockedLastStep(1)
    if state.closureBlockedLastStep(1)
        status = 'Zug 1: wartet vor zeitweise gesperrtem Blockzugang';
    elseif state.signalBlockedLastStep(1)
        status = 'Zug 1: wartet vor belegtem Block';
    else
        status = 'Zug 1: wartet hinter Zugende';
    end
elseif extraHold(1)
    status = sprintf('Zug 1: Zusatzhalt %s | noch %g s', ...
        p.route.stationNames(state.dwellStation(1)),state.extraWaitSteps(1));
elseif state.waitSteps(1) > 0
    status = sprintf('Zug 1: %s | noch %g s Halt', ...
        p.route.stationNames(state.dwellStation(1)),state.waitSteps(1));
else
    status = sprintf('Zug 1: nächste Station %s',p.route.stationNames(state.nextStation(1)));
end
status = sprintf('%s | %.1f km/h',status,state.velocity(1)*p.speedUnitKmh);
h.status.String = status;
drawnow
end

function [x,y] = coordinates(distance,p)
%coordinates - Streckenposition in Darstellungskoordinaten umrechnen
if p.config.displayMode == "Geografischer Streckenverlauf"
    track = p.route.track;
    distance = distance*track.distance_m(end)/p.route.lengthMeters;
    lon = interp1(track.distance_m,track.longitude,distance,'linear');
    lat = interp1(track.distance_m,track.latitude,distance,'linear');
    originLat = mean(track.latitude);
    originLon = mean(track.longitude);
    x = (lon-originLon)*111.32*cosd(originLat);
    y = (lat-originLat)*111.32;
else
    phi = -2*pi*distance/p.route.lengthMeters;
    x = cos(phi);
    y = 0.5*sin(phi);
end
end

function [x,y] = labelCoordinates(x,y,p)
%labelCoordinates - Zugnummern von Stationsbeschriftungen trennen
if p.config.displayMode == "Schematischer Ring"
    x = 0.88*x;
    y = 0.80*y;
else
    y = y-0.25;
end
end
