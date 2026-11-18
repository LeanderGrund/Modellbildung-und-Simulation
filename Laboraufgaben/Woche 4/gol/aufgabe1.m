function result = aufgabe1(out)
% AUFGABE1 Reproducible Life experiments, all parts (a)-(d).
if nargin < 1, out = fullfile(fileparts(pwd),'ergebnisse'); end
if ~isfolder(out), mkdir(out); end
names = ["Zufallsstart", "Gleiter", "Gleiter mit Sterben", ...
    "Leeres Feld mit Geburt", "Geburt und Sterben"];
scenarios = ["random","glider","glider","empty","empty"];
death = [0 0 1e-3 0 1e-3]; birth = [0 0 0 1e-3 1e-3];
times = [0 10 100 1000 2000];
steps = times(end); siz = [100 100];
population = zeros(steps+1,5); changed = population;
snapshots = cell(5,numel(times));
firstNoise = NaN(1,5);
for k = 1:5
    rng(2100+k,'twister');
    [G,p] = myInit(siz,scenario=scenarios(k),pDeath=death(k),pBirth=birth(k));
    population(1,k) = nnz(G); snapshots{k,1} = G;
    for t = 1:steps
        previous = G;
        if k == 3 && isnan(firstNoise(k))
            state = rng;
            deterministic = myUpdate(G,struct,1);
            rng(state);
        end
        G = myUpdate(G,p,1);
        if k == 3 && isnan(firstNoise(k)) && ~isequal(G,deterministic)
            firstNoise(k) = t;
        end
        population(t+1,k) = nnz(G);
        changed(t+1,k) = nnz(xor(G,previous));
        index = find(times == t,1);
        if ~isempty(index), snapshots{k,index} = G; end
    end
end
f = figure('Visible','off','Theme','light','Position',[50 50 1400 1000]);
layout = tiledlayout(5,5,'TileSpacing','compact','Padding','compact');
for k = 1:5
    for j = 1:numel(times)
        ax = nexttile;
        imagesc(ax,snapshots{k,j},[0 1]); axis(ax,'image');
        set(ax,'XTick',[],'YTick',[]);
        title(ax,sprintf('%s, t=%d',names(k),times(j)),'FontSize',9);
    end
end
colormap(f,flipud(gray(2)));
title(layout,'Aufgabe 1: Game of Life, periodisches 100 x 100 Feld');
exportgraphics(f,fullfile(out,'aufgabe1_zustaende.png'),'Resolution',160); close(f);

f = figure('Visible','off','Theme','light','Position',[50 50 1100 750]);
tiledlayout(3,1);
nexttile; plot(0:steps,population(:,1),'LineWidth',1); grid on;
xlabel('Zeitschritt'); ylabel('Lebende Zellen'); title('Zufällige Startkonfiguration');
ax = nexttile; palette = lines(5); colororder(ax,palette(2:5,:));
plot(0:steps,population(:,2:5),'LineWidth',1); grid on;
xlabel('Zeitschritt'); ylabel('Lebende Zellen'); legend(names(2:5),'Location','best');
nexttile; plot(0:steps,changed,'LineWidth',1); grid on;
legend(names,'Location','best');
xlabel('Zeitschritt'); ylabel('Geänderte Zellen pro Schritt');
exportgraphics(f,fullfile(out,'aufgabe1_verlauf.png'),'Resolution',160); close(f);

% Show the four glider phases at a readable scale, without a large empty field.
[G,p] = myInit([20 20],scenario="glider");
f = figure('Visible','off','Theme','light','Position',[50 50 1200 280]);
tiledlayout(1,5,'TileSpacing','compact');
for t = 0:4
    nexttile; imagesc(G(7:15,7:15),[0 1]); axis image;
    set(gca,'XTick',[],'YTick',[]); title(sprintf('Gleiter: t=%d',t));
    G = myUpdate(G,p,1);
end
colormap(f,flipud(gray(2)));
exportgraphics(f,fullfile(out,'aufgabe1_gleiter.png'),'Resolution',160); close(f);
data = table((0:steps)',population(:,1),population(:,2),population(:,3), ...
    population(:,4),population(:,5),'VariableNames', ...
    {'t','random','glider','death','birth','birth_and_death'});
writetable(data,fullfile(out,'aufgabe1_population.csv'));
result = struct('seed',2101:2105,'size',siz,'times',times, ...
    'firstGliderDeath',firstNoise(3),'finalPopulation',population(end,:), ...
    'firstEmptyGlider',find(population(:,3)==0,1)-1, ...
    'birthRangeLast500',[min(population(end-499:end,4)),max(population(end-499:end,4))], ...
    'meanLast500',mean(population(end-499:end,:),1), ...
    'finalChanged',changed(end,:));
write_json(fullfile(out,'aufgabe1_summary.json'),result);
fprintf('Aufgabe 1: erstes zusätzliches Sterben bei t=%g.\n',firstNoise(3));
disp(data([1 11 101 1001 2001],:));
end

function write_json(file,value)
fid = fopen(file,'w','n','UTF-8');
assert(fid >= 0,'Datei konnte nicht geöffnet werden.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
