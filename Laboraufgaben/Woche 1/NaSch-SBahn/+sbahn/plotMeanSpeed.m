function h = plotMeanSpeed(G,p)
%plotMeanSpeed - Mittlere Geschwindigkeit aller Züge einschließlich Halten zeigen
%   H = sbahn.plotMeanSpeed(G,P) stellt das Netzmittel in km/h über der
%   Zeit dar. Die Referenzlinie beschreibt den störungsfreien freien Umlauf.
%
%   See also plotResults, plotDynamics
arguments
    G (1,1) struct
    p (1,1) struct
end
h = figure('Name','S-Bahn: mittlere Geschwindigkeit','Color','w','Position',[100 100 1000 320]);
ax = axes(h);
mittelungsdauerSekunden = 300;  % Zeitfenster: 5 Minuten
fenster = max(1,round(mittelungsdauerSekunden/p.stepSeconds));

netzmittel = mean(G.velocity,2)*p.speedUnitKmh;
geglaettet = movmean(netzmittel,fenster,'Endpoints','shrink');

plot(ax,G.timeSeconds/60,geglaettet,'LineWidth',1.5, ...
    'DisplayName',sprintf('Netzmittel, über %g min geglättet', ...
    mittelungsdauerSekunden/60));
hold(ax,'on');
yline(ax,p.averageSpeedKmh,'k--','DisplayName','Freier Referenzumlauf');
xlim(ax,[0 G.timeSeconds(end)/60]);
ylim(ax,[0 p.maxSpeedKmh]);
xlabel(ax,'Zeit [min]');
ylabel(ax,'Mittlere Geschwindigkeit [km/h]');
title(ax,'Netzmittel als ergänzende Auswertung');
legend(ax,'Location','southoutside','Orientation','horizontal','Box','off');
grid(ax,'on');
end
