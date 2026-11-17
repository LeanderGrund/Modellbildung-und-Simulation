function result = aufgabe2(out)
% AUFGABE2 Diffusion plots, runtime scaling, four random-walk models.
if nargin < 1, out = fullfile(fileparts(pwd),'ergebnisse'); end
if ~isfolder(out), mkdir(out); end
rng(2200,'twister');
result.field = field_experiment(out);
result.runtime = runtime_experiment(out);
result.walk = walk_experiment(out);
fid = fopen(fullfile(out,'aufgabe2_summary.json'),'w','n','UTF-8');
assert(fid >= 0); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
end

function result = field_experiment(out)
[G,p] = myInit([200 200],scenario="rechteck",periodic=true,cg=10,N=.5);
times = [0 100 1000 5000]; count = zeros(size(times));
f = figure('Visible','off','Theme','light','Position',[50 50 1300 360]);
tiledlayout(1,numel(times),'TileSpacing','compact'); t = 0;
for j = 1:numel(times)
    if times(j) > t, G = myUpdate(G,p,times(j)-t); end
    t = times(j); count(j) = nnz(G(:,:,1:4));
    assert(count(j) == p.sum);
    density = coarse_density(G,p.cg);
    nexttile; imagesc(density,[0 .5]); axis image off;
    title(sprintf('t=%d, N=%d',t,count(j))); colorbar;
end
colormap(f,parula(256));
exportgraphics(f,fullfile(out,'aufgabe2_diffusion.png'),'Resolution',160); close(f);
result = struct('size',[200 200],'times',times,'particleCounts',count, ...
    'meanFinalDensity',mean(density,'all'),'stdFinalDensity',std(density,0,'all'));
end

function density = coarse_density(G,cg)
[rows,cols,~] = size(G);
density = reshape(sum(reshape(double(G(:,:,1:4)), ...
    [cg rows/cg cg cols/cg 4]),[1 3 5]),rows/cg,cols/cg)/(4*cg^2);
end

function result = runtime_experiment(out)
% Median of five repetitions, initialisation and plotting excluded.
sides = [50 100 200 400]; nsteps = [10 30 100 300 1000]; repeats = 5;
sizeSeconds = zeros(numel(sides),repeats);
stepSeconds = zeros(numel(nsteps),repeats);
[warm,p] = myInit([50 50],cg=10); myUpdate(warm,p,10); % JIT warm-up
for i = 1:numel(sides)
    [G,p] = myInit([sides(i) sides(i)],scenario="cgx",plot=0,periodic=true);
    myUpdate(G,p,2);
    for j = 1:repeats
        started = tic; H = myUpdate(G,p,100); sizeSeconds(i,j) = toc(started);
        assert(nnz(H(:,:,1:4)) == p.sum);
    end
end
[G,p] = myInit([200 200],scenario="cgx",plot=0,periodic=true);
for i = 1:numel(nsteps)
    for j = 1:repeats
        started = tic; H = myUpdate(G,p,nsteps(i)); stepSeconds(i,j) = toc(started);
        assert(nnz(H(:,:,1:4)) == p.sum);
    end
end
cells = sides'.^2; medianSize = median(sizeSeconds,2); medianSteps = median(stepSeconds,2);
fitCells = polyfit(log(cells),log(medianSize),1);
fitSteps = polyfit(log(nsteps'),log(medianSteps),1);
sizeTable = table(cells,repmat(100,numel(cells),1),medianSize,min(sizeSeconds,[],2), ...
    max(sizeSeconds,[],2),'VariableNames',{'cells','steps','median_s','min_s','max_s'});
stepTable = table(repmat(40000,numel(nsteps),1),nsteps',medianSteps,min(stepSeconds,[],2), ...
    max(stepSeconds,[],2),'VariableNames',{'cells','steps','median_s','min_s','max_s'});
writetable(sizeTable,fullfile(out,'aufgabe2_laufzeit_zellen.csv'));
writetable(stepTable,fullfile(out,'aufgabe2_laufzeit_schritte.csv'));
f = figure('Visible','off','Theme','light','Position',[50 50 1100 420]); tiledlayout(1,2);
nexttile; loglog(cells,medianSize,'o-',cells,exp(polyval(fitCells,log(cells))),'--');
grid on; xlabel('Gitterorte M = N_x N_y'); ylabel('Laufzeit / s');
title(sprintf('100 Schritte, Exponent %.3f',fitCells(1)));
legend('Messung (Median)','Potenzfit','Location','best');
nexttile; loglog(nsteps,medianSteps,'o-',nsteps,exp(polyval(fitSteps,log(nsteps))),'--');
grid on; xlabel('Zeitschritte n'); ylabel('Laufzeit / s');
title(sprintf('200 x 200 Orte, Exponent %.3f',fitSteps(1)));
exportgraphics(f,fullfile(out,'aufgabe2_laufzeit.png'),'Resolution',160); close(f);
result = struct('matlab',version,'computer',computer,'repetitions',repeats, ...
    'cellExponent',fitCells(1),'stepExponent',fitSteps(1), ...
    'sizeMeasurements',sizeTable,'stepMeasurements',stepTable);
fprintf('Laufzeitexponenten: Zellen %.3f, Schritte %.3f\n',fitCells(1),fitSteps(1));
disp(sizeTable); disp(stepTable);
end

function result = walk_experiment(out)
% Model (i) follows exactly the collision/streaming direction transitions.
% Coordinates are unbounded: no modulo operation or finite lattice here.
rng(2400,'twister');
labels = ["(i) Block-CA","(ii) Diskretes Quadrat", ...
    "(iii) Kontinuierliches Quadrat","(iv) Gleichverteilte Kreisscheibe"];
expectedSlope = [1 4/3 2/3 1/2];
ensemble = 20000; steps = 1000; sampleEvery = 10;
times = [0 10 100 1000];
snap = zeros(ensemble,2,4,numel(times));
msd = zeros(steps+1,4); trajectories = zeros(steps+1,2,4);
meanPosition = zeros(4,2); variance = zeros(4,2);
for model = 1:4
    pos = zeros(ensemble,2);
    % k=1 up, k=2 left, k=3 right, k=4 down.
    direction = randi(4,ensemble,1);
    velocities = [0 1; -1 0; 1 0; 0 -1];
    clockwise = [3 1 4 2]; counterclockwise = [2 4 1 3];
    for t = 1:steps
        switch model
            case 1
                bit = rand(ensemble,1) < .5;
                next = reshape(counterclockwise(direction),[],1);
                next(bit) = clockwise(direction(bit)); direction = next;
                delta = velocities(direction,:);
            case 2
                delta = randi(3,ensemble,2)-2;
            case 3
                delta = 2*rand(ensemble,2)-1;
            case 4
                radius = sqrt(rand(ensemble,1)); angle = 2*pi*rand(ensemble,1);
                delta = radius.*[cos(angle) sin(angle)];
        end
        pos = pos+delta;
        msd(t+1,model) = mean(sum(pos.^2,2));
        trajectories(t+1,:,model) = pos(1,:);
        index = find(times == t,1);
        if ~isempty(index), snap(:,:,model,index) = pos; end
    end
    meanPosition(model,:) = mean(pos,1); variance(model,:) = var(pos,1,1);
end
theoryFinal = steps*expectedSlope;
relativeError = msd(end,:)./theoryFinal-1;
assert(all(abs(relativeError) < .04),'MSD weicht um mehr als 4 Prozent ab.');
f = figure('Visible','off','Theme','light','Position',[50 50 1100 850]); tiledlayout(2,2);
for model = 1:4
    nexttile; xy = trajectories(1:sampleEvery:end,:,model);
    plot(xy(:,1),xy(:,2),'.-','MarkerSize',6); hold on;
    plot(xy(1,1),xy(1,2),'go','MarkerFaceColor','g');
    plot(xy(end,1),xy(end,2),'ro','MarkerFaceColor','r');
    axis equal; grid on; xlim([-65 65]); ylim([-65 65]);
    xlabel('x'); ylabel('y'); title(labels(model));
end
sgtitle('Einzelwege: Position alle n=10 Schritte, insgesamt 1000 Schritte');
exportgraphics(f,fullfile(out,'aufgabe2_random_walk_wege.png'),'Resolution',160); close(f);
f = figure('Visible','off','Theme','light','Position',[50 50 1300 950]); tiledlayout(4,4);
for model = 1:4
    for j = 1:numel(times)
        nexttile;
        scatter(snap(1:2000,1,model,j),snap(1:2000,2,model,j),3,'.');
        axis equal; grid on; xlim([-90 90]); ylim([-90 90]);
        title(sprintf('%s, t=%d',labels(model),times(j)),'FontSize',8);
    end
end
sgtitle('Endpunktwolken: gleiche Laengen- und Zeitskalen, 2000 von 20000 Wegen');
exportgraphics(f,fullfile(out,'aufgabe2_random_walk_wolken.png'),'Resolution',160); close(f);
f = figure('Visible','off','Theme','light','Position',[50 50 1100 450]); tiledlayout(1,2);
colors = lines(4);
nexttile; hold on;
for model = 1:4
    plot(0:steps,msd(:,model),'Color',colors(model,:),'LineWidth',1.5);
end
for model = 1:4
    plot(0:steps,(0:steps)*expectedSlope(model),'--','Color',colors(model,:), ...
        'HandleVisibility','off');
end
grid on; xlabel('n'); ylabel('<x^2+y^2>'); legend(labels,'Location','northwest');
title('Durchgezogen: Simulation; gestrichelt: Theorie');
nexttile; hold on;
for model = 1:4
    plot(1:steps,msd(2:end,model)./((1:steps)'*expectedSlope(model)), ...
        'Color',colors(model,:));
end
yline(1,'k--'); grid on; ylim([.94 1.06]);
xlabel('n'); ylabel('MSD / theoretische MSD'); title('Vergleich mit der jeweiligen Schrittvarianz');
exportgraphics(f,fullfile(out,'aufgabe2_random_walk_msd.png'),'Resolution',160); close(f);
summary = table(labels',expectedSlope',expectedSlope'/4,msd(end,:)',theoryFinal', ...
    relativeError','VariableNames',{'model','theory_MSD_per_step','D','measured_MSD_n1000', ...
    'theory_MSD_n1000','relative_error'});
writetable(summary,fullfile(out,'aufgabe2_random_walk_vergleich.csv'));
writetable(table((0:steps)',msd(:,1),msd(:,2),msd(:,3),msd(:,4), ...
    'VariableNames',{'n','CA','discrete_square','continuous_square','disk'}), ...
    fullfile(out,'aufgabe2_random_walk_msd.csv'));
result = struct('ensemble',ensemble,'steps',steps,'sampleEvery',sampleEvery,'seed',2400, ...
    'summary',summary,'meanPosition',meanPosition,'variance',variance);
disp(summary);
end
