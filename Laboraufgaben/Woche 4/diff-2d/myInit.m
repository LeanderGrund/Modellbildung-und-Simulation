function [G,p] = myInit(siz,p)

arguments

    % Simulationsgebiet 2D
    siz (1,2) double {mustBePositive,mustBeInteger} = [200 400]

    p.scenario string = 'rechteck';

    % Coarse Graining Box Kantenlänge
    p.cg (1,1) double {mustBePositive,mustBeInteger} = 10;

    p.dt (1,1) double {mustBePositive,mustBeInteger} = 5;
    p.tend (1,1) double {mustBePositive,mustBeInteger} = 1000;

    p.plot (1,1) double {mustBeInteger,mustBeInRange(p.plot,0,4)} = 1;

    p.periodic (1,1) logical = true; % periodische Ränder?

    p.N (1,1) double {mustBeInRange(p.N,0,1)} = 0.5; % Konzentrationserhöhung
end

n3 = 4;
siz = ceil(siz/p.cg)*p.cg;
n1 = siz(1); n2 = siz(2);
cg = p.cg; N = p.N;

% create scenario
G = false([n1 n2 n3]);
switch p.scenario

    case 'one' % Ein Teilchen
        G(ceil(n1/2),ceil(n2/2),randi(4,1)) = true;

    case 'cg' % Eine cg Box
        G = reshape(G,[cg n1/cg cg n2/cg n3]);
        G(:,round(end/2),:,round(end/2),:) = rand(cg,1,cg,1,n3) < N;
        G = reshape(G,[n1 n2 n3]);

    case 'kreis' % Kleiner Kreis

        % Einen Kreis füllen
        [x1,x2] = ndgrid((1:n1)-n1/2,(1:n2)-n2/2);
        r2 = x1.^2 + x2.^2;
        ind = find( r2 < (min(n1,n2)/10)^2 );
        for i1 = 1:4
            G(ind + (i1-1)*n1*n2) = rand(1,numel(ind)) < N;
        end

    case 'rechteck' % Rechteck

        G = reshape(G,[cg n1/cg cg n2/cg n3]);
        i1 = max(1,round(0.4*n1/cg)):max(1,round(0.6*n1/cg));
        i2 = max(1,round(0.4*n2/cg)):max(1,round(0.6*n2/cg));
        G(:,i1,:,i2,:) = rand(cg,numel(i1),cg,numel(i2),n3) < N;
        G = reshape(G,[n1,n2,n3]);

    case 'cgx' % Viele cg Boxen

        G = reshape(G,[cg n1/cg cg n2/cg n3]);
        ind = rand(n1/cg,n2/cg) < 0.5;
        ind = find(ind);
        for i1 = 1:numel(ind)
            [i2,i4] = ind2sub([n1/cg n2/cg],ind(i1));
            G(:,i2,:,i4,:) = rand(cg,1,cg,1,n3) < N;
        end
        G = reshape(G,[n1 n2 n3]);

    otherwise
        error('unknown scenario');

end

% Feste Wände
solid = false([n1 n2]); % Hindernissfelder
if ~p.periodic
    % Rand solid machen
    solid([1 end],:) = true;
    solid(:,[1 end]) = true;
end

% Teilchen im Hinderniss abräumen
if numel(solid) ~= 0
    for i1 = 1:n3
        G(:,:,i1) = G(:,:,i1) & ~solid;
    end
end

% Prüfsumme
p.sum = nnz(G);

% G und solid zusammenfügen
G = cat(3,G,solid);

end

% ------------------------------------------------------------------------
