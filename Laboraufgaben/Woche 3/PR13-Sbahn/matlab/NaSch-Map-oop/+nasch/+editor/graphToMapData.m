function data = graphToMapData(G,vmax,density,brake)
%GRAPHTOMAPDATA Replace every graph node by a roundabout.
%
% Roundabout approaches use the directions of the global graph edges.
% Long ring sections are split so that their length is at most 3*vmax.
% Short roads are allowed. Sources and sinks use period 2.

arguments
    G (1,1) digraph
    vmax (1,1) double {mustBePositive,mustBeInteger} = 8
    density (1,1) double {mustBeInRange(density,0,1)} = 0.2
    brake (1,1) double {mustBeInRange(brake,0,1)} = 0.05
end

if numnodes(G) == 0
    error('The graph is empty.');
end

if ~all(ismember({'x','y'},G.Nodes.Properties.VariableNames))
    error('Graph nodes require x and y coordinates.');
end

x = G.Nodes.x;
y = G.Nodes.y;
ends = G.Edges.EndNodes;
nGlobal = numnodes(G);
node1 = [];
node2 = [];
nodex = [];
nodey = [];
neighbors = cell(1,nGlobal);
inPort = cell(1,nGlobal);
outPort = cell(1,nGlobal);

for i = 1:nGlobal
    e = ends(ends(:,1) == i | ends(:,2) == i,:);
    nbr = unique(e(:));
    nbr(nbr == i) = [];

    if isempty(nbr)
        error('Node %d is isolated.',i);
    end

    phi = mod(atan2(y(nbr)-y(i),x(nbr)-x(i)),2*pi);
    [phi,order] = sort(phi);
    nbr = nbr(order);
    neighbors{i} = nbr(:)';
    m = numel(nbr);

    if m == 1
        radius = vmax/2;
    else
        gap = diff([phi; phi(1)+2*pi]);
        radius = max(vmax/2*cot(gap/4));
    end

    outer = radius+2*vmax;
    halfLane = vmax/2;
    div = zeros(1,m);
    merge = zeros(1,m);
    exit = zeros(1,m);
    entry = zeros(1,m);

    for k = 1:m
        er = [cos(phi(k)) sin(phi(k))];
        et = [-sin(phi(k)) cos(phi(k))];
        div(k) = addPoint([x(i) y(i)]+radius*er-halfLane*et);
        merge(k) = addPoint([x(i) y(i)]+radius*er+halfLane*et);
        exit(k) = addPoint([x(i) y(i)]+outer*er-halfLane*et);
        entry(k) = addPoint([x(i) y(i)]+outer*er+halfLane*et);
        addRoad(div(k),merge(k));
        addRoad(div(k),exit(k));
        addRoad(entry(k),merge(k));
    end

    for k = 1:m
        addSplitRoad(merge(k),div(mod(k,m)+1));
    end

    inPort{i} = entry;
    outPort{i} = exit;
end

for e = 1:size(ends,1)
    i = ends(e,1);
    j = ends(e,2);
    a = outPort{i}(neighbors{i} == j);
    b = inPort{j}(neighbors{j} == i);

    addRoad(a,b);
end

times = zeros(1,numel(node1));

for i = 1:numel(nodex)
    in = find(node2 == i);
    out = find(node1 == i);

    if isempty(in) && numel(out) == 1
        times(out) = 2;
    elseif numel(in) == 1 && isempty(out)
        times(in) = 2;
    end
end

data = struct("node1",node1,"node2",node2,"nodex",nodex,"nodey",nodey,"times",times,"vmax",vmax,"density",density,"brake",brake);


    function id = addPoint(p)
        nodex(end+1) = p(1);
        nodey(end+1) = p(2);
        id = numel(nodex);
    end


    function addRoad(a,b)
        node1(end+1) = a;
        node2(end+1) = b;
    end


    function addSplitRoad(a,b)
        p1 = [nodex(a) nodey(a)];
        p2 = [nodex(b) nodey(b)];
        len = norm(p2-p1);
        n = max(1,ceil(len/(3*vmax)));
        previous = a;

        for q = 1:n-1
            current = addPoint(p1+q/n*(p2-p1));
            addRoad(previous,current);
            previous = current;
        end

        addRoad(previous,b);
    end

end
