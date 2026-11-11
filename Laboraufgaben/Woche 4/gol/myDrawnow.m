function h = myDrawnow(G,p,t,h)

if nargin < 4
    h = [];
end

if ~isfield(p,'plot') || ~p.plot
    h = [];
    return;
end

switch p.plot
    
    case 1 % pixel plot

        if isempty(h)
            % initiate figure
            h = imagesc(G,[0,1]);
            colormap( gca, flipud(gray(2)) ); % background white
            axis equal; axis off; axis tight;
        else
            % update handles
            h.CData = G;
        end

    otherwise

        h = [];
        return

end

sgtitle( ['grid at timestep = ' num2str(t) ] );
drawnow limitrate;

end

% ------------------------------------------------------------------------