function result = demo_aufgabe1(teil,options)
% DEMO_AUFGABE1 Einzelne Life-Versuche mit Feld und Zellzahl animieren.
% Aufruf aus Woche 4:
%   demo_aufgabe1("a")           % Zufallsstart, N0=0.2
%   demo_aufgabe1("b")           % ungestoerter Gleiter
%   demo_aufgabe1("c")           % Gleiterstart, pDeath=1e-3
%   demo_aufgabe1("d")           % leeres Feld, pBirth=1e-3
%   demo_aufgabe1("d_beide")     % leeres Feld, Geburt und Sterben
% Optionen: steps=2000, siz=[100 100], fps=30, plot=true, seed=[]
% Ohne Grafik: r = demo_aufgabe1("c",plot=false);
% r.history enthaelt alle Zellzahlen, einschliesslich des Startzustands.
arguments
    teil (1,1) string {mustBeMember(teil,["a","b","c","d","d_beide"])} = "a"
    options.steps (1,1) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = 2000
    options.siz (1,2) double {mustBeInteger,mustBePositive,mustBeFinite} = [100 100]
    options.fps (1,1) double {mustBePositive,mustBeFinite} = 30
    options.plot (1,1) logical = true
    options.seed (1,:) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = []
end

% Konfigurationen entsprechen gol/aufgabe1.m und der Ausarbeitung.
switch teil
    case "a"
        name = "1a: Zufaellige Startkonfiguration";
        scenario = "random"; pDeath = 0; pBirth = 0; seed = 2101;
    case "b"
        name = "1b: Ungestoerter Gleiter";
        scenario = "glider"; pDeath = 0; pBirth = 0; seed = 2102;
    case "c"
        name = "1c: Gleiterstart mit zusaetzlichem Sterben";
        scenario = "glider"; pDeath = 1e-3; pBirth = 0; seed = 2103;
    case "d"
        name = "1d: Leeres Feld mit spontaner Geburt";
        scenario = "empty"; pDeath = 0; pBirth = 1e-3; seed = 2104;
    case "d_beide"
        name = "1d (Kombination): Spontane Geburt und Sterben";
        scenario = "empty"; pDeath = 1e-3; pBirth = 1e-3; seed = 2105;
end
if ~isempty(options.seed)
    if ~isscalar(options.seed) || options.seed > 2^32-1
        error('demo_aufgabe1:Seed','seed muss ein Skalar zwischen 0 und 2^32-1 sein.');
    end
    seed = options.seed;
end

% Beide Modelle besitzen myInit/myUpdate. Das Arbeitsverzeichnis waehlt Life.
root = fileparts(mfilename('fullpath'));
old = pwd;
oldRng = rng;
cleanup = onCleanup(@() restore_environment(old,oldRng)); %#ok<NASGU>
cd(fullfile(root,'gol'));
clear myInit myUpdate
rng(seed,'twister');
[G,p] = myInit(options.siz,scenario=scenario,N0=.2, ...
    pDeath=pDeath,pBirth=pBirth,dt=1,tend=max(1,options.steps),plot=double(options.plot));
initial = G;
population = zeros(options.steps+1,1); changed = population;
population(1) = nnz(G);
firstDeviation = NaN; firstEmpty = NaN;
if population(1) == 0, firstEmpty = 0; end
f = [];
if options.plot
    f = figure('Theme','light','Name',name,'NumberTitle','off', ...
        'Position',[80 100 1100 480]);
    layout = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
    gridAxes = nexttile(layout);
    gridImage = imagesc(gridAxes,G,[0 1]);
    colormap(gridAxes,flipud(gray(2))); axis(gridAxes,'image');
    set(gridAxes,'XTick',[],'YTick',[]);
    gridTitle = title(gridAxes,sprintf('t = 0 | Lebende Zellen: %d',population(1)));
    populationAxes = nexttile(layout);
    populationLine = animatedline(populationAxes,'Color',[0 .35 .7],'LineWidth',1.3);
    addpoints(populationLine,0,population(1));
    grid(populationAxes,'on'); xlim(populationAxes,[0 max(1,options.steps)]);
    xlabel(populationAxes,'Zeitschritt'); ylabel(populationAxes,'Lebende Zellen');
    title(populationAxes,'Zellzahl einschliesslich normaler Life-Geburten');
    title(layout,sprintf('%s | Seed %d | pDeath = %g | pBirth = %g', ...
        name,seed,pDeath,pBirth),'Interpreter','none');
    drawnow;
end

fprintf('%s: Feld %d x %d, N0=%g, pDeath=%g, pBirth=%g, Seed=%d, Schritte=%d\n', ...
    name,options.siz(1),options.siz(2),p.N0,pDeath,pBirth,seed,options.steps);
t = 0;
for step = 1:options.steps
    if options.plot && ~isgraphics(f), break; end
    frame = tic;
    previous = G;
    noisy = pDeath > 0 || pBirth > 0;
    if noisy && isnan(firstDeviation)
        deterministic = myUpdate(G,struct,1);
    end
    G = myUpdate(G,p,1);
    if noisy && isnan(firstDeviation) && ~isequal(G,deterministic)
        firstDeviation = step;
    end
    t = step;
    population(t+1) = nnz(G);
    changed(t+1) = nnz(xor(G,previous));
    if isnan(firstEmpty) && population(t+1) == 0, firstEmpty = t; end
    if options.plot
        gridImage.CData = G;
        gridTitle.String = sprintf('t = %d | Lebende Zellen: %d',t,population(t+1));
        addpoints(populationLine,t,population(t+1));
        drawnow;
        if isgraphics(f), pause(max(0,1/options.fps-toc(frame))); end
    end
end

history = table((0:t)',population(1:t+1),changed(1:t+1), ...
    'VariableNames',{'t','living','changed'});
[peak,peakIndex] = max(history.living);
result = struct('part',teil,'name',name,'seed',seed,'parameters',p, ...
    'initialGrid',initial,'finalGrid',G,'history',history,'completedSteps',t, ...
    'firstDeviationFromLife',firstDeviation,'firstEmptyStep',firstEmpty, ...
    'peakPopulation',peak,'peakStep',peakIndex-1,'figure',f);
fprintf('Ausgefuehrt: %d Schritte; Maximum: %d Zellen bei t=%d; zuletzt: %d Zellen.\n', ...
    t,peak,peakIndex-1,population(t+1));
end

function restore_environment(old,oldRng)
cd(old);
rng(oldRng);
end
