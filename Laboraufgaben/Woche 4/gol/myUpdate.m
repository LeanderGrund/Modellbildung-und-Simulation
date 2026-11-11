function G = myUpdate(G,~,dt)
% Game of Life by Conway
% periodic boundary conditions

for t = 1:dt
    s = circshift(G,[-1 -1]) + circshift(G,[0 -1]) + circshift(G,[+1 -1]) + ...
        circshift(G,[-1  0]) +                       circshift(G,[+1  0]) + ...
        circshift(G,[-1 +1]) + circshift(G,[0 +1]) + circshift(G,[+1 +1]);
    G = (s==3) | (s==2) & G;
end

end

% ------------------------------------------------------------------------