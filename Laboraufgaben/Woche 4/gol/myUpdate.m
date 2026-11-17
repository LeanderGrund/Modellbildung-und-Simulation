function G = myUpdate(G,p,dt)
% Game of Life by Conway
% periodic boundary conditions; noise follows the deterministic Life step.
% Missing parameters preserve the original deterministic update.
pDeath = 0; pBirth = 0;
if isfield(p,'pDeath'), pDeath = p.pDeath; end
if isfield(p,'pBirth'), pBirth = p.pBirth; end

for t = 1:dt
    s = circshift(G,[-1 -1]) + circshift(G,[0 -1]) + circshift(G,[+1 -1]) + ...
        circshift(G,[-1  0]) +                       circshift(G,[+1  0]) + ...
        circshift(G,[-1 +1]) + circshift(G,[0 +1]) + circshift(G,[+1 +1]);
    G = (s==3) | (s==2) & G;
    if pDeath > 0
        G = G & (rand(size(G)) >= pDeath);
    end
    if pBirth > 0
        G = G | (rand(size(G)) < pBirth);
    end
end

end

% ------------------------------------------------------------------------
