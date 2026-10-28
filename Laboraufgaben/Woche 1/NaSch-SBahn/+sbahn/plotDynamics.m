function h = plotDynamics(G,p,train)
%plotDynamics - Fahrbewegung des Auswertungszuges anzeigen
%   H = sbahn.plotDynamics(G,P) zeigt die Fahrbewegung in km/h und m/s².
%
%   H = sbahn.plotDynamics(G,P,TRAIN) zeigt stattdessen TRAIN.
%
%   See also plotResults, plotMeanSpeed

arguments
    G (1,1) struct
    p (1,1) struct
    train (1,1) double {mustBeInteger,mustBePositive} = 1
end
assert(train <= p.trainCount,'SBahn:PlotTrain','Der Auswertungszug muss zwischen 1 und %g liegen.',p.trainCount);
h = figure('Name','S-Bahn: Fahrbewegung des Auswertungszuges','Color','w');
tiledlayout(h,2,1,'TileSpacing','compact','Padding','compact');
ax1 = nexttile;
plot(ax1,G.timeSeconds/60,G.velocity(:,train)*p.speedUnitKmh,'LineWidth',1);
ylabel(ax1,'Geschwindigkeit [km/h]');
title(ax1,sprintf('Zug %g: Geschwindigkeit',train));
grid(ax1,'on');
ax2 = nexttile;
acceleration = diff(G.velocity(:,train))*p.dxMeters/p.stepSeconds^2;
stairs(ax2,G.timeSeconds(2:end)/60,acceleration,'LineWidth',1);
ylabel(ax2,'Beschleunigung [m/s²]');
xlabel(ax2,'Zeit [min]');
title(ax2,'Positiv: Beschleunigen | Negativ: Bremsen');
grid(ax2,'on');
linkaxes([ax1 ax2],'x');
xlim(ax1,[0 G.timeSeconds(end)/60]);
sgtitle(p.config.motionModel);
end
