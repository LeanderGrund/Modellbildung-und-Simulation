function h = plotResults(G,p,plotView,train)
%plotResults - Raum-Zeit-Trajektorien nach Geschwindigkeit einfärben
%   H = sbahn.plotResults(G,P) zeigt den gesamten Ring und hebt Zug 1
%   schwarz hervor. Farben kennzeichnen ausschließlich km/h.
%
%   H = sbahn.plotResults(G,P,plotView) wählt "Übersicht" oder "Detail".
%   Der Detailausschnitt folgt dem ersten relevanten Ereignis.
%
%   H = sbahn.plotResults(G,P,plotView,TRAIN) hebt stattdessen TRAIN hervor.
%
%   See also plotMeanSpeed, plotDynamics
arguments
    G (1,1) struct
    p (1,1) struct
    plotView (1,1) string {mustBeMember(plotView,["Übersicht","Detail"])} = "Übersicht"
    train (1,1) double {mustBeInteger,mustBePositive} = 1
end
assert(train <= p.trainCount,'SBahn:PlotTrain','Der Auswertungszug muss zwischen 1 und %g liegen.',p.trainCount);
lengthKm = p.route.lengthMeters/1000;
time = G.timeSeconds/60;
[center,eventTime,eventDuration,eventName] = focusEvent(G,p,train);
detail = plotView == "Detail";
if detail
    xRange = center+[-2.5 2.5];
    tRange = [max(0,eventTime-4),min(time(end),eventTime+max(8,eventDuration+4))];
else
    xRange = [0 lengthKm];
    tRange = [0 time(end)];
end
h = figure('Name',char("S-Bahn: Raum-Zeit-"+plotView),'Color','w','Position',[100 100 1000 650]);
ax = axes(h);
hold(ax,'on');
stationKm = mapPosition((p.route.stationCells-1)*p.dxMeters/1000,center,lengthKm,detail);
for station = find(stationKm >= xRange(1) & stationKm <= xRange(2))
    xline(ax,stationKm(station),':','Color',[0.86 0.86 0.86],'HandleVisibility','off');
    if detail
        text(ax,stationKm(station)+0.025,tRange(2)-0.02*diff(tRange),p.route.stationNames(station), ...
            'Rotation',90,'FontSize',8,'Color',[0.3 0.3 0.3], ...
            'VerticalAlignment','top','Clipping','on');
    end
end
for id = 1:p.trainCount
    x = mapPosition((G.position(:,id)-1)*p.dxMeters/1000,center,lengthKm,detail);
    % Jede Spalte ist genau ein Zeitintervall. Die Geschwindigkeit der
    % Zielzeile gehört zum gerade zurückgelegten Weg; Ringsprünge entfallen.
    segments = [x(1:end-1)';x(2:end)'];
    segments(:,abs(diff(x)) > lengthKm/2) = NaN;
    speed = G.velocity(2:end,id)'*p.speedUnitKmh;
    surface(ax,segments,[time(1:end-1)';time(2:end)'],zeros(size(segments)), ...
        [speed;speed],'FaceColor','none','EdgeColor','flat', ...
        'MeshStyle','column','LineWidth',1.35,'HandleVisibility','off');
end
anchors = [0.95 0.35 0.05;1 0.85 0.15;0.35 0.8 0.6;0.1 0.65 0.85;0.1 0.2 0.65];
colormap(ax,interp1(linspace(0,1,size(anchors,1)),anchors,linspace(0,1,256)));
clim(ax,[0 p.maxSpeedKmh]);
colorScale = colorbar(ax);
colorScale.Label.String = 'Geschwindigkeit [km/h]';
colorScale.Ticks = 0:20:p.maxSpeedKmh;
x = mapPosition((G.position(:,train)-1)*p.dxMeters/1000,center,lengthKm,detail);
wraps = [false;abs(diff(x)) > lengthKm/2];
% NaN nur für die schwarze Orientierungslinie, nicht für die Modelldaten.
pathX = x; pathX(wraps) = NaN;
highlight = plot(ax,pathX,time,'k-','LineWidth',0.55, ...
    'DisplayName',sprintf('Zug %g',train));
marks = 1:max(1,round(60/p.stepSeconds)):numel(time);
plot(ax,x(marks),time(marks),'ko','MarkerSize',3,'HandleVisibility','off');
handles = highlight;
events = p.state.stopLog;
selected = events(:,5) > 0 | (events(:,2) == train & events(:,6) > 0);
events = events(selected,:);
if ~isempty(events)
    locations = mapPosition((p.route.stationCells(events(:,3))-1)*p.dxMeters/1000,center,lengthKm,detail);
    handles(end+1) = scatter(ax,locations,events(:,1)/60,45,'k','d', ...
        'LineWidth',1,'DisplayName','Zusatzhalt ausgelöst');
end
if p.config.closureEnabled && p.config.closureStartSeconds < G.timeSeconds(end)
    location = (p.blocks.startCells(p.config.closureBlock)-1)*p.dxMeters/1000;
    location = mapPosition(location,center,lengthKm,detail);
    closedTime = [p.config.closureStartSeconds, ...
        min(G.timeSeconds(end),p.config.closureStartSeconds+p.config.closureDurationSeconds)]/60;
    handles(end+1) = plot(ax,[location location],closedTime,'k--','LineWidth',1.5, ...
        'DisplayName','Blockzugang gesperrt');
end
set(ax,'YDir','reverse','Layer','top','FontSize',10);
view(ax,2);
xlim(ax,xRange); ylim(ax,tRange);
if detail
    ticks = ax.XTick;
    ax.XTick = ticks;
    ax.XTickLabel = compose('%.2f',mod(ticks,lengthKm));
    title(ax,{sprintf('Detail: %s',eventName), ...
        'Ringübergang zusammenhängend; Positionsangaben modulo Ringlänge'});
else
    title(ax,sprintf('%g Züge | %.3f km | %g Stationen',p.trainCount,lengthKm,p.stationCount));
end
xlabel(ax,'Position auf dem Ring [km]');
ylabel(ax,'Zeit [min]');
legend(ax,handles,'Location','southoutside','Orientation','horizontal','Box','off');
end

function x = mapPosition(x,center,lengthKm,detail)
%mapPosition - Den Ring für den Detailausschnitt um das Ereignis aufschneiden
if detail, x = center+mod(x-center+lengthKm/2,lengthKm)-lengthKm/2; end
end

function [position,time,duration,name] = focusEvent(G,p,train)
%focusEvent - Einen nachvollziehbaren Mittelpunkt für den Detailplot wählen
events = p.state.stopLog;
event = find(events(:,5) > 0,1);
duration = 0;
if ~isempty(event)
    name = "gezielter Zusatzhalt";
elseif p.config.closureEnabled && p.config.closureStartSeconds < G.timeSeconds(end)
    position = (p.blocks.startCells(p.config.closureBlock)-1)*p.dxMeters/1000;
    time = p.config.closureStartSeconds/60;
    duration = p.config.closureDurationSeconds/60;
    name = "zeitweise Blocksperre · Block "+string(p.config.closureBlock);
    return
else
    event = find(events(:,2) == train & events(:,6) > 0,1);
    name = "zufälliger Zusatzhalt";
end
if isempty(event)
    row = find(G.blocked(:,train),1);
    name = "erster blockierter Halt des Auswertungszuges";
    if isempty(row)
        event = find(events(:,2) == train,1);
        name = "erster Stationshalt des Auswertungszuges";
        if isempty(event), name = "Startposition des Auswertungszuges"; end
        row = 1;
    end
    position = (G.position(row,train)-1)*p.dxMeters/1000;
    time = G.timeSeconds(row)/60;
end
if ~isempty(event)
    position = (p.route.stationCells(events(event,3))-1)*p.dxMeters/1000;
    time = events(event,1)/60;
    duration = sum(events(event,4:6))/60;
    name = name+" · "+p.route.stationNames(events(event,3));
end
end
