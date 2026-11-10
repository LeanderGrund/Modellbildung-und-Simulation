function styleFigure(fig)
%STYLEFIGURE Lesbare Exporte unabhängig vom hellen/dunklen MATLAB-Design.
fig.Color = 'w';
heatmap = strcmp(fig.Name,'Verkehrsstromuntersuchung');
for ax = findall(fig,'Type','axes')'
    ax.XColor = 'k'; ax.YColor = 'k';
    ax.Color = 'w';
    if heatmap, ax.Color = [0.8 0.8 0.8]; end
end
for label = findall(fig,'-property','String')'
    if isa(label,'matlab.graphics.primitive.Text') || ...
            isa(label,'matlab.graphics.illustration.subplot.Text')
        label.Color = 'k';
    end
end
for legendHandle = findall(fig,'Type','legend')'
    legendHandle.Color = 'w'; legendHandle.TextColor = 'k';
end
for colorbarHandle = findall(fig,'Type','colorbar')'
    colorbarHandle.Color = 'k';
end
% Titel von tiledlayout sind keine normalen Achsen-Textkinder.
for layout = findall(fig,'-isa','matlab.graphics.layout.TiledChartLayout')'
    layout.Title.Color = 'k';
    layout.Subtitle.Color = 'k';
    layout.XLabel.Color = 'k';
    layout.YLabel.Color = 'k';
end
end
