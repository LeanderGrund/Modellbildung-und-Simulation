function G = randomGraph(n,dmin,dmax)
%RANDOMGRAPH Generate a bidirectional random Delaunay network.
%
% Nodes lie in [0,1000]^2. Each new node has a nearest-neighbor distance
% between dmin and dmax. Every Delaunay edge is inserted in both directions.

arguments
    n (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(n,3)} = 10
    dmin (1,1) double {mustBePositive} = 100
    dmax (1,1) double {mustBePositive} = 300
end

if dmax <= dmin, error('dmax must be larger than dmin.'), end

L = 1000;
x = zeros(n,1);
y = zeros(n,1);
x(1) = L*rand;
y(1) = L*rand;

for k = 2:n
    accepted = false;

    for trial = 1:20000
        i = randi(k-1);
        r = dmin+(dmax-dmin)*rand;
        phi = 2*pi*rand;
        p = [x(i)+r*cos(phi) y(i)+r*sin(phi)];

        if all(p >= 0) && all(p <= L)
            d = hypot(x(1:k-1)-p(1),y(1:k-1)-p(2));
            if min(d) >= dmin && min(d) <= dmax
                x(k) = p(1);
                y(k) = p(2);
                accepted = true;
                break
            end
        end
    end

    if ~accepted, error('Could not place all nodes with the requested distances.'), end
end

E = edges(delaunayTriangulation(x,y));
G = digraph([E(:,1); E(:,2)],[E(:,2); E(:,1)],n);
G.Nodes.x = x;
G.Nodes.y = y;

end
