function check_trafic_flow_graphics
%CHECK_TRAFIC_FLOW_GRAPHICS Gespeicherte Grafiken gestalten und prüfen.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'modell'));
out = strtrim(fileread(fullfile(root,'ergebnisse','trafic_flow','LETZTER_TEST.txt')));
files = dir(fullfile(out,'**','*.fig'));
checks = table();
for index = 1:numel(files)
    path = fullfile(files(index).folder,files(index).name);
    fig = openfig(path,'invisible');
    sbahn2.styleFigure(fig);
    heatmap = strcmp(fig.Name,'Verkehrsstromuntersuchung');
    axesHandles = findall(fig,'Type','axes');
    for ax = axesHandles'
        expected = [1 1 1];
        if heatmap, expected = [0.8 0.8 0.8]; end
        assert(isequal(ax.Color,expected) && isequal(ax.XColor,[0 0 0]) ...
            && isequal(ax.YColor,[0 0 0]));
    end
    for label = findall(fig,'-property','String')'
        if isa(label,'matlab.graphics.primitive.Text') || ...
                isa(label,'matlab.graphics.illustration.subplot.Text')
            assert(isequal(label.Color,[0 0 0]));
        end
    end
    for layout = findall(fig,'-isa','matlab.graphics.layout.TiledChartLayout')'
        assert(isequal(layout.Title.Color,[0 0 0]));
    end
    exportgraphics(fig,strrep(path,'.fig','.png'),'Resolution',160,'BackgroundColor','white');
    savefig(fig,path);
    checks = [checks;table(string(files(index).name),true, ...
        'VariableNames',{'figure','passed'})]; %#ok<AGROW>
    close(fig);
end
assert(height(checks) == 5);
writetable(checks,fullfile(out,'grafikpruefung.csv'));
disp(checks);
end
