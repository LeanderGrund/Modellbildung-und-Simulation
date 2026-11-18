function result = demo_feld(options)
% DEMO_FELD Fuenf Startfelder mit periodischen Raendern simulieren/pruefen.
arguments
    options.scenario (1,1) string {mustBeMember(options.scenario,["leer","voll","rand","mitte","donut"])} = "mitte"
    options.siz (1,2) double {mustBeInteger,mustBePositive,mustBeFinite} = [200 200]
    options.cg (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 10
    options.N (1,1) double {mustBeInRange(options.N,0,1)} = .5
    options.steps (1,1) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = 1000
    options.dt (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 5
    options.fps (1,1) double {mustBePositive,mustBeFinite} = 30
    options.seed (1,1) double {mustBeInteger,mustBeInRange(options.seed,0,4294967295)} = 2200
    options.plot (1,1) logical = true
end
names = ["leer","voll","rand","mitte","donut"];
scenarios = ["leer","voll","rechteck_rand","rechteck","donut"];
labels = ["Leeres Feld","Volles Feld (alle 4 Kanaele)", ...
    "Rechteck am linken Rand","Rechteck in der Mitte","Donut in der Mitte"];
index = find(names == options.scenario);
rng(options.seed,'twister');
[G,p] = myInit(options.siz,scenario=scenarios(index),cg=options.cg,N=options.N, ...
    periodic=true,plot=0,dt=options.dt,tend=max(1,options.steps));
initial = G; initialCount = p.sum;
times = (0:options.dt:options.steps)';
if times(end) ~= options.steps, times(end+1) = options.steps; end
counts = zeros(size(times)); counts(1) = initialCount;
opposite = zeros(size(times)); opposite(1) = nnz(G(:,end,1:4));
firstOppositeStep = NaN;
if opposite(1) > 0, firstOppositeStep = 0; end
f = [];
if options.plot
    f = figure('Theme','light','Name',labels(index),'NumberTitle','off', ...
        'Position',[60 100 1300 440]);
    layout = tiledlayout(f,1,3,'TileSpacing','compact');
    ax1 = nexttile(layout); rawImage = imagesc(ax1,sum(G(:,:,1:4),3)/4,[0 1]);
    axis(ax1,'image'); xlabel(ax1,'Spalte'); ylabel(ax1,'Zeile'); colorbar(ax1);
    title(ax1,'Belegung pro Ort (0 bis 1)'); colormap(ax1,parula(256));
    ax2 = nexttile(layout); cgImage = imagesc(ax2,coarse_density(G,p.cg),[0 1]);
    axis(ax2,'image'); xlabel(ax2,'Box-Spalte'); ylabel(ax2,'Box-Zeile'); colorbar(ax2);
    title(ax2,sprintf('Mittel ueber %d x %d Orte',p.cg,p.cg)); colormap(ax2,parula(256));
    ax3 = nexttile(layout); numberLine = animatedline(ax3,'Color',[0 .35 .7],'LineWidth',1.5);
    addpoints(numberLine,0,initialCount); grid(ax3,'on');
    xlim(ax3,[0 max(1,options.steps)]);
    ylim(ax3,[max(0,initialCount-max(1,.05*initialCount)),initialCount+max(1,.05*initialCount)]);
    xlabel(ax3,'Zeitschritt'); ylabel(ax3,'Gesamtteilchenzahl'); title(ax3,'Test: Teilchenzahl konstant');
    header = title(layout,sprintf('2b: %s | t=0 | N=%d | periodische Raender',labels(index),initialCount));
    drawnow;
end
last = 1;
for j = 2:numel(times)
    if options.plot && ~isgraphics(f), break; end
    frame = tic;
    % Den allerersten Randuebertritt bereits bei t=1 pruefen, auch bei dt>1.
    dt = times(j)-times(j-1);
    if j == 2 && options.scenario == "rand"
        G = myUpdate(G,p,1);
        if nnz(G(:,end,1:4)) > 0, firstOppositeStep = 1; end
        if dt > 1, G = myUpdate(G,p,dt-1); end
    else
        G = myUpdate(G,p,dt);
    end
    counts(j) = nnz(G(:,:,1:4));
    opposite(j) = nnz(G(:,end,1:4));
    assert(counts(j) == initialCount,'Teilchenzahl ist nicht erhalten.');
    if options.scenario == "leer" || options.scenario == "voll"
        assert(isequal(G,initial),'Leer-/Vollfeld wurde veraendert.');
    end
    if isnan(firstOppositeStep) && opposite(j) > 0, firstOppositeStep = times(j); end
    last = j;
    if options.plot
        rawImage.CData = sum(G(:,:,1:4),3)/4;
        cgImage.CData = coarse_density(G,p.cg);
        addpoints(numberLine,times(j),counts(j));
        header.String = sprintf('2b: %s | t=%d | N=%d | rechts: %d Teilchen', ...
            labels(index),times(j),counts(j),opposite(j));
        drawnow;
        if isgraphics(f), pause(max(0,1/options.fps-toc(frame))); end
    end
end
history = table(times(1:last),counts(1:last),opposite(1:last), ...
    'VariableNames',{'t','particles','right_edge_particles'});
checks = struct('massConserved',all(history.particles == initialCount), ...
    'unchanged',isequal(G,initial),'periodicBoundaryObserved', ...
    options.scenario == "rand" && firstOppositeStep == 1);
fprintf('2b: %s | Teilchenzahl %d -> %d | %d Schritte | Massenerhaltung bestanden.\n', ...
    labels(index),initialCount,history.particles(end),history.t(end));
if options.scenario == "rand"
    fprintf('Erster beobachteter Auftritt am rechten Rand: t=%g.\n',firstOppositeStep);
end
result = struct('scenario',options.scenario,'seed',options.seed,'parameters',p, ...
    'initialGrid',initial,'finalGrid',G,'history',history, ...
    'firstOppositeStep',firstOppositeStep,'checks',checks,'figure',f);
end

function density = coarse_density(G,cg)
[nx,ny,~] = size(G);
density = reshape(sum(reshape(double(G(:,:,1:4)), ...
    [cg nx/cg cg ny/cg 4]),[1 3 5]),nx/cg,ny/cg)/(4*cg^2);
end
