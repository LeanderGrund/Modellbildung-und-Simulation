function h = plotDynamics(G,p)
%plotDynamics - Geschwindigkeit und Beschleunigung von Zug 1 anzeigen
%   H = sbahn.plotDynamics(G,P) zeigt die Fahrbewegung in km/h und m/s².
%
%   See also sbahn.plotResults

h = figure('Name','S-Bahn: Fahrbewegung von Zug 1','Color','w');
tiledlayout(h,2,1,'TileSpacing','compact','Padding','compact');
ax1 = nexttile;
plot(ax1,G.timeSeconds/60,G.velocity(:,1)*p.speedUnitKmh,'LineWidth',1);
ylabel(ax1,'Geschwindigkeit [km/h]');
title(ax1,'Zug 1: Geschwindigkeit');
grid(ax1,'on');
ax2 = nexttile;
acceleration = diff(G.velocity(:,1))*p.dxMeters/p.stepSeconds^2;
stairs(ax2,G.timeSeconds(2:end)/60,acceleration,'LineWidth',1);
ylabel(ax2,'Beschleunigung [m/s²]');
xlabel(ax2,'Zeit [min]');
title(ax2,'Positiv: Beschleunigen | Negativ: Bremsen');
grid(ax2,'on');
linkaxes([ax1 ax2],'x');
xlim(ax1,[0 G.timeSeconds(end)/60]);
sgtitle(p.config.motionModel);
end
