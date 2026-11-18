function result = demo_regel(options)
% DEMO_REGEL Einen tatsaechlichen Update-Schritt in seine Phasen zerlegen.
arguments
    options.occupation (1,4) logical = [true false false false]
    options.seed (1,1) double {mustBeInteger,mustBeInRange(options.seed,0,4294967295)} = 2201
    options.plot (1,1) logical = true
end
rng(options.seed,'twister');
G = false(5,5,5); G(3,3,1:4) = reshape(options.occupation,1,1,4);
% Dasselbe Zufallswort wie myUpdate ansehen, ohne den Generator vorzustellen.
state = rng;
z = randi([0 double(intmax('uint32'))],[5 5],'uint32');
xi = logical(bitget(z(3,3),1));
rng(state);
if xi, rotated = options.occupation([2 4 1 3]);
else, rotated = options.occupation([3 1 4 2]); end
actual = myUpdate(G,struct,1);
shifts = [-1 0; 0 -1; 0 1; 1 0];
expected = false(size(G));
for k = 1:4
    expected(3+shifts(k,1),3+shifts(k,2),k) = rotated(k);
end
assert(isequal(actual,expected),'Kollision/Streaming weicht von der Regel ab.');
channels = ["a: oben";"b: links";"c: rechts";"d: unten"];
occupations = table(channels,options.occupation',rotated', ...
    'VariableNames',{'channel','before','after_collision'});
disp(occupations);
fprintf('2a: xi=%d, %d Teilchen vor/nach dem Schritt. Regeltest bestanden.\n', ...
    xi,nnz(G(:,:,1:4)));
f = [];
if options.plot
    f = figure('Theme','light','Name','2a: Richtungswechsel und Streaming','NumberTitle','off');
    layout = tiledlayout(f,1,3,'TileSpacing','compact');
    velocities = [0 1;-1 0;1 0;0 -1];
    for phase = 1:3
        ax = nexttile(layout); hold(ax,'on');
        if phase == 1, occupied = options.occupation; else, occupied = rotated; end
        for k = find(occupied)
            if phase == 3, origin = velocities(k,:); else, origin = [0 0]; end
            scatter(ax,origin(1),origin(2),45,k,'filled');
            quiver(ax,origin(1),origin(2),.6*velocities(k,1),.6*velocities(k,2), ...
                0,'LineWidth',2,'MaxHeadSize',1);
        end
        plot(ax,0,0,'k+'); axis(ax,'equal'); grid(ax,'on');
        xlim(ax,[-2 2]); ylim(ax,[-2 2]); xlabel(ax,'x'); ylabel(ax,'y');
        labels = ["Vorher","Nach Kollision (gleicher Ort)","Nach Streaming"];
        title(ax,labels(phase));
    end
    title(layout,sprintf('2a: ein Schritt des gegebenen CA | xi=%d | Seed=%d',xi,options.seed));
end
result = struct('seed',options.seed,'xi',xi,'occupation',options.occupation, ...
    'afterCollision',rotated,'initialGrid',G,'finalGrid',actual, ...
    'occupations',occupations,'rulePassed',true,'figure',f);
end
