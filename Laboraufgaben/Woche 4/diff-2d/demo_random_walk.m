function result = demo_random_walk(options)
% DEMO_RANDOM_WALK Ein Modell aus 2d mit unbeschraenkten Koordinaten testen.
arguments
    options.model (1,1) string {mustBeMember(options.model,["i","ii","iii","iv"])} = "i"
    options.steps (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 1000
    options.ensemble (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 20000
    options.sampleEvery (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 10
    options.seed (1,:) double {mustBeInteger,mustBeNonnegative,mustBeFinite} = []
    options.tolerance (1,1) double {mustBePositive,mustBeFinite} = .04
    options.plot (1,1) logical = true
end
models = ["i","ii","iii","iv"];
labels = ["Block-CA (90-Grad-Drehung)","Diskretes Quadrat", ...
    "Kontinuierliches Quadrat","Gleichverteilte Kreisscheibe"];
slopes = [1 4/3 2/3 1/2]; index = find(models == options.model);
seed = 2399+index;
if ~isempty(options.seed)
    if ~isscalar(options.seed) || options.seed > 2^32-1
        error('demo_random_walk:Seed','seed muss ein Skalar zwischen 0 und 2^32-1 sein.');
    end
    seed = options.seed;
end
rng(seed,'twister');
pos = zeros(options.ensemble,2);
trajectory = zeros(options.steps+1,2); exampleSteps = zeros(options.steps,2);
msd = zeros(options.steps+1,1);
velocities = [0 1;-1 0;1 0;0 -1];
clockwise = [3 1 4 2]; counterclockwise = [2 4 1 3];
if index == 1, direction = randi(4,options.ensemble,1); end
for t = 1:options.steps
    switch index
        case 1
            previousVelocity = velocities(direction,:);
            bit = rand(options.ensemble,1) < .5;
            next = reshape(counterclockwise(direction),[],1);
            next(bit) = clockwise(direction(bit)); direction = next;
            delta = velocities(direction,:);
            assert(all(sum(delta.^2,2) == 1) && all(sum(previousVelocity.*delta,2) == 0), ...
                'CA-Schritt muss Laenge 1 und eine 90-Grad-Drehung haben.');
        case 2
            delta = randi(3,options.ensemble,2)-2;
            assert(all(abs(delta) <= 1 & delta == round(delta),'all'));
        case 3
            delta = 2*rand(options.ensemble,2)-1;
            assert(all(abs(delta) <= 1,'all'));
        case 4
            radius = sqrt(rand(options.ensemble,1)); angle = 2*pi*rand(options.ensemble,1);
            delta = radius.*[cos(angle) sin(angle)];
            assert(all(sum(delta.^2,2) <= 1+10*eps));
    end
    if t == 1, firstSteps = delta; end
    pos = pos+delta;
    trajectory(t+1,:) = pos(1,:); exampleSteps(t,:) = delta(1,:);
    msd(t+1) = mean(sum(pos.^2,2));
end
times = (0:options.steps)'; theory = times*slopes(index);
relativeError = msd(end)/theory(end)-1;
withinTolerance = abs(relativeError) <= options.tolerance;
history = table(times,msd,theory,'VariableNames',{'t','measured_MSD','theory_MSD'});
sampleTimes = unique([0:options.sampleEvery:options.steps options.steps])';
sampled = table(sampleTimes,trajectory(sampleTimes+1,1),trajectory(sampleTimes+1,2), ...
    'VariableNames',{'t','x','y'});
fprintf('2d (%s): %s | %d Wege, %d Schritte, Seed %d\n', ...
    options.model,labels(index),options.ensemble,options.steps,seed);
fprintf('MSD: gemessen %.4f, Theorie %.4f; Abweichung %+.3f Prozent.\n', ...
    msd(end),theory(end),100*relativeError);
fprintf('Schrittregeln bestanden; statistischer MSD-Test (Toleranz %.1f Prozent): %d.\n', ...
    100*options.tolerance,withinTolerance);
f = [];
if options.plot
    f = figure('Theme','light','Name',"2d: "+labels(index),'NumberTitle','off', ...
        'Position',[50 50 1150 850]);
    layout = tiledlayout(f,2,2,'TileSpacing','compact');
    ax = nexttile(layout); hold(ax,'on');
    % Einzelne Liniensegmente vermeiden Spitzen an scharfen Knicken im Export.
    xy = [sampled.x sampled.y];
    sx = [xy(1:end-1,1),xy(2:end,1),NaN(size(xy,1)-1,1)]';
    sy = [xy(1:end-1,2),xy(2:end,2),NaN(size(xy,1)-1,1)]';
    plot(ax,sx(:),sy(:),'-','Color',[0 .35 .7]);
    scatter(ax,sampled.x,sampled.y,12,[0 .35 .7],'filled');
    scatter(ax,0,0,55,'g','filled'); scatter(ax,xy(end,1),xy(end,2),55,'r','filled');
    axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'x'); ylabel(ax,'y');
    title(ax,sprintf('Einzelweg: Position alle %d Schritte',options.sampleEvery));
    ax = nexttile(layout); shown = min(2000,options.ensemble);
    scatter(ax,pos(1:shown,1),pos(1:shown,2),6,'.');
    axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'x'); ylabel(ax,'y');
    title(ax,sprintf('Endpunkte nach %d Schritten (%d Wege)',options.steps,shown));
    ax = nexttile(layout); plot(ax,times,msd,'-',times,theory,'--','LineWidth',1.4);
    grid(ax,'on'); xlabel(ax,'Zeitschritt'); ylabel(ax,'Mittlere quadratische Entfernung');
    legend(ax,'Simulation','Theorie','Location','northwest');
    title(ax,sprintf('Endabweichung: %+.2f Prozent',100*relativeError));
    ax = nexttile(layout); scatter(ax,firstSteps(1:shown,1),firstSteps(1:shown,2),12,'.');
    axis(ax,'equal'); xlim(ax,[-1.1 1.1]); ylim(ax,[-1.1 1.1]); grid(ax,'on');
    xlabel(ax,'Delta x'); ylabel(ax,'Delta y'); title(ax,'Verteilung der ersten Schritte');
    title(layout,sprintf('2d (%s): %s | Seed=%d | Koordinaten in der unendlichen Ebene', ...
        options.model,labels(index),seed));
end
checks = struct('stepConstraintsPassed',true,'msdWithinTolerance',withinTolerance, ...
    'relativeError',relativeError,'tolerance',options.tolerance);
result = struct('model',options.model,'name',labels(index),'seed',seed, ...
    'ensemble',options.ensemble,'steps',options.steps,'sampleEvery',options.sampleEvery, ...
    'theorySlope',slopes(index),'D',slopes(index)/4,'history',history, ...
    'trajectory',trajectory,'exampleSteps',exampleSteps,'sampledPositions',sampled, ...
    'firstSteps',firstSteps,'finalPositions',pos,'checks',checks,'figure',f);
end
