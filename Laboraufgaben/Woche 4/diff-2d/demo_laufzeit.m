function result = demo_laufzeit(options)
% DEMO_LAUFZEIT Echte myUpdate-Laufzeiten ohne Grafik/Initialisierung messen.
arguments
    options.sides (1,:) double {mustBeInteger,mustBePositive,mustBeFinite} = [50 100 200 400 800]
    options.stepCounts (1,:) double {mustBeInteger,mustBePositive,mustBeFinite} = [10 30 100 300 1000]
    options.repeats (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 5
    options.fixedSteps (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 100
    options.fixedSize (1,2) double {mustBeInteger,mustBePositive,mustBeFinite} = [200 200]
    options.seed (1,1) double {mustBeInteger,mustBeInRange(options.seed,0,4294967295)} = 2200
    options.plot (1,1) logical = true
end
assert(numel(unique(options.sides)) >= 2 && numel(unique(options.stepCounts)) >= 2, ...
    'Fuer beide Fits werden mindestens zwei verschiedene Werte benoetigt.');
rng(options.seed,'twister');
sizeSeconds = zeros(numel(options.sides),options.repeats);
stepSeconds = zeros(numel(options.stepCounts),options.repeats);
% cg=1 verhindert das Aufrunden benutzerdefinierter Gittergroessen.
[warm,p] = myInit([30 30],cg=1,scenario="cgx",periodic=true,plot=0);
myUpdate(warm,p,10);
for k = 1:numel(options.sides)
    side = options.sides(k);
    [G,p] = myInit([side side],cg=1,scenario="cgx",periodic=true,plot=0);
    myUpdate(G,p,2);
    for j = 1:options.repeats
        started = tic; H = myUpdate(G,p,options.fixedSteps); sizeSeconds(k,j) = toc(started);
        assert(nnz(H(:,:,1:4)) == p.sum,'Massenerhaltung im Laufzeittest verletzt.');
    end
end
[G,p] = myInit(options.fixedSize,cg=1,scenario="cgx",periodic=true,plot=0);
myUpdate(G,p,2);
for k = 1:numel(options.stepCounts)
    for j = 1:options.repeats
        started = tic; H = myUpdate(G,p,options.stepCounts(k)); stepSeconds(k,j) = toc(started);
        assert(nnz(H(:,:,1:4)) == p.sum,'Massenerhaltung im Laufzeittest verletzt.');
    end
end
cells = options.sides'.^2;
medianSize = median(sizeSeconds,2); medianSteps = median(stepSeconds,2);
fitCells = polyfit(log(cells),log(medianSize),1);
fitSteps = polyfit(log(options.stepCounts'),log(medianSteps),1);
sizeTable = table(cells,repmat(options.fixedSteps,numel(cells),1), ...
    medianSize,min(sizeSeconds,[],2),max(sizeSeconds,[],2), ...
    'VariableNames',{'cells','steps','median_s','min_s','max_s'});
stepTable = table(repmat(prod(options.fixedSize),numel(options.stepCounts),1), ...
    options.stepCounts',medianSteps,min(stepSeconds,[],2),max(stepSeconds,[],2), ...
    'VariableNames',{'cells','steps','median_s','min_s','max_s'});
fprintf('2c: %d Wiederholungen; Initialisierung und Grafik nicht mitgemessen.\n',options.repeats);
disp(sizeTable); disp(stepTable);
fprintf('Fitexponenten: Orte %.3f, Schritte %.3f. Theoretisch jeweils 1.\n',fitCells(1),fitSteps(1));
f = [];
if options.plot
    f = figure('Theme','light','Name','2c: Laufzeitskalierung','NumberTitle','off', ...
        'Position',[60 100 1100 460]);
    layout = tiledlayout(f,1,2);
    nexttile(layout);
    loglog(cells,medianSize,'o-',cells,exp(polyval(fitCells,log(cells))),'--');
    grid on; xlabel('Gitterorte M'); ylabel('Laufzeit / s');
    title(sprintf('%d Schritte | Fitexponent %.3f',options.fixedSteps,fitCells(1)));
    legend('Messung: Median','Potenzfit','Location','best');
    nexttile(layout);
    loglog(options.stepCounts,medianSteps,'o-',options.stepCounts, ...
        exp(polyval(fitSteps,log(options.stepCounts))),'--');
    grid on; xlabel('Zeitschritte n'); ylabel('Laufzeit / s');
    title(sprintf('%d x %d Orte | Fitexponent %.3f',options.fixedSize,fitSteps(1)));
    title(layout,'2c: Erwartete Komplexitaet O(M n), rechnerabhaengige Messungen');
end
result = struct('seed',options.seed,'matlab',version,'computer',computer, ...
    'repeats',options.repeats,'sizeMeasurements',sizeTable,'stepMeasurements',stepTable, ...
    'sizeSeconds',sizeSeconds,'stepSeconds',stepSeconds, ...
    'cellExponent',fitCells(1),'stepExponent',fitSteps(1),'figure',f);
end
