function h = myDrawnow(G,p,t,h)

if nargin < 4
    h = [];
end

if ~isfield(p,'plot') || ~p.plot
    h = [];
    return;
end

G = G(:,:,1:4);

switch p.plot

    case 1 % pixel plot --------------------------------------------------

        [n1,n2,~] = size(G);
        G = reshape(G,[n1 n2 2 2]);
        G = permute(G,[3 1 4 2]);
        G = reshape(G,[2*n1 2*n2]);

        if isempty(h)
            % initiate figure
            clf;
            switch 2
                case 1, colormap( gray(2) ); % background black
                case 2, colormap( flipud(gray(2)) ); % background white
            end
            h = imagesc(G,[0,1]);
            axis equal; axis off;
        else
            % update handles
            h.CData = G;
        end

    case 2 % sum plot ----------------------------------------------------

        s = sum(G,3);

        if isempty(h)
            % initiate figure
            clf;
            colormap( flipud(gray(5)) ); % background white
            h = imagesc(s,[0,5]);
            axis equal; axis off;
        else
            % update handles
            h.CData = s;
        end

    case 3 % coarse grained plot - imagesc -------------------------------

        cg = p.cg;
        d = coarse_graining(G,cg);

        if isempty(h)
            % initiate figure
            clf;
            colormap( parula(256) );
            switch 2
                case 1, h = imagesc(d,[0,max(d(:))]);
                case 2, h = imagesc(d);
            end
            axis equal; axis off;
            a = axis(); axis(a + [-1 +1 -1 +1]);
            colorbar;
        else
            % update handles
            h.CData = d;
        end

    case 4 % coarse grained plot - surf ----------------------------------

        cg = p.cg;
        d = coarse_graining(G,cg);

        if isempty(h)
            % initiate figure
            clf;
            colormap( parula(256) );
            h = surf(d);
            a = axis;
            axis([a(1:4) 0 max(d(:))]);
            colorbar;
        else
            % update handles
            h.ZData = d;
        end

    otherwise

        h = [];
        return

end

title( ['grid at timestep = ' num2str(t) ] );
drawnow;

end

% ------------------------------------------------------------------------

function d = coarse_graining(G,cg)
mx = size(G,1);
my = size(G,2);
N = squeeze( sum( reshape(G,[cg mx/cg cg my/cg 4]) , [1 3] ) ) / cg^2;
d = sum(N,3) / 4;
end

% ------------------------------------------------------------------------