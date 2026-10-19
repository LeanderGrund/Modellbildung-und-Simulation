function h = plotResults(G,p)
%plotResults - Zeit-Weg-Diagramm in physikalischen Einheiten zeichnen
%   H = sbahn.plotResults(G,P) zeigt Trajektorien und Geschwindigkeiten.
%
%   See also sbahn.simulate

h = figure('Name','S-Bahn: Raum-Zeit-Diagramm','Color','w');
tiledlayout(h,1,4,'TileSpacing','compact','Padding','compact');
ax1 = nexttile([1 3]);
hold(ax1,'on');
stationKm = (p.route.stationCells-1)*p.dxMeters/1000;
for station = 1:p.stationCount
    xline(ax1,stationKm(station),':','Color',[0.8 0.8 0.8], ...
        'HandleVisibility','off');
end
colors = lines(p.trainCount);
for train = 1:p.trainCount
    x = (G.position(:,train)-1)*p.dxMeters/1000;
    time = G.timeSeconds/60;
    % Break trajectories at the periodic boundary instead of drawing
    % a diagonal line across the complete ring.
    wraps = find(diff(G.position(:,train)) < 0);
    nPoints = numel(x)+numel(wraps);
    xp = nan(nPoints,1);
    tp = nan(nPoints,1);
    pointIndex = (1:numel(x))'+[0;cumsum(diff(G.position(:,train)) < 0)];
    xp(pointIndex) = x;
    tp(pointIndex) = time;
    plot(ax1,xp,tp,'Color',colors(train,:),'LineWidth',1.1);
    stopped = G.velocity(:,train) == 0;
    scatter(ax1,x(stopped),time(stopped),4,[0.15 0.15 0.15], ...
        'filled','HandleVisibility','off');
    obstructed = G.blocked(:,train);
    scatter(ax1,x(obstructed),time(obstructed),10,[0.95 0.55 0.05], ...
        'filled','HandleVisibility','off');
    extraHold = G.extraWaitSteps(:,train) > 0 & G.waitSteps(:,train) == G.extraWaitSteps(:,train);
    disturbed = extraHold | G.closureBlocked(:,train);
    scatter(ax1,x(disturbed),time(disturbed),10,[0.55 0.15 0.8], ...
        'filled','HandleVisibility','off');
end
set(ax1,'YDir','reverse');
xlim(ax1,[0 p.route.lengthMeters/1000]);
ylim(ax1,[0 G.timeSeconds(end)/60]);
xlabel(ax1,'Position auf dem Ring [km]');
ylabel(ax1,'Zeit [min]');
title(ax1,sprintf('%g Züge: Fahrt und Stationshalte',p.trainCount));
grid(ax1,'on');
ax2 = nexttile;
meanSpeed = mean(G.velocity,2)*p.speedUnitKmh;
plot(ax2,meanSpeed,G.timeSeconds/60,'LineWidth',1.2);
hold(ax2,'on');
xline(ax2,p.averageSpeedKmh,'--','Umlaufmittel', ...
    'LabelOrientation','aligned');
set(ax2,'YDir','reverse');
xlim(ax2,[0 p.driveSpeedKmh*1.1]);
xlabel(ax2,'Geschwindigkeit [km/h]');
title(ax2,'Mittel über alle Züge');
grid(ax2,'on');
linkaxes([ax1 ax2],'y');
sgtitle(sprintf('%g km | %g Stationen | Halt %g–%g s | v_{max} = %.2f km/h', ...
    p.route.lengthMeters/1000,p.stationCount,min(p.stationDwellSeconds), ...
    max(p.stationDwellSeconds),p.driveSpeedKmh));
end
