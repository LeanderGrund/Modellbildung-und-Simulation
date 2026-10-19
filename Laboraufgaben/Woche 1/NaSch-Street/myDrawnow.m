function h = myDrawnow(u,p,t,h)
%MYDRAWNOW Visualize the current state of the NaSch traffic model.
%
% The street state is stored as a complex-valued vector:
%   NaN     : empty cell
%   real(u) : vehicle velocity
%   imag(u) : vehicle ID
%
% On the first call, the function creates the visualization and returns
% its graphics handles in h. On subsequent calls, the existing graphics
% objects are updated.

if nargin < 3, t = []; end
if nargin < 4, h = []; end
if ~p.plot, return; end

n = numel(u);
ratio = 0.2; % plot ratio height vs width

% vehicle positions, velocities, and IDs
x  = find(~isnan(u));
v  = real(u(x));
id = imag(u(x));

% select colors ----------------------------------------------------------
if p.plot == 1
    col = flipud(jet(p.vmax+1));
    colind = v+1;
else
    maxID = max([1 id]);

    if isempty(h) || ~isfield(h,'colormap') || size(h.colormap,1) < maxID
        col = parula(maxID);
    else
        col = h.colormap;
    end

    colind = id;
end

if isempty(h)
    % initialize visualization -------------------------------------------

    clf;
    h.fig = gcf;
    h.ax = gca;
    h.ratio = ratio;
    h.colormap = col;
    hold(h.ax,'on');

    % street
    phi = linspace(0,2*pi,100);
    h.street = plot(cos(phi),ratio*sin(phi));

    % driving direction
    ell = 0.5;
    h.direction = quiver(-ell/2,-1.1*ratio,ell,0,0,'k');

    % vehicles
    phi = 2*pi*x/n;
    h.cars = scatter(cos(phi),ratio*sin(phi),[],col(colind,:),'filled');

    % track the first available vehicle
    if isempty(id)
        trackID = [];
        h.track = plot(nan,nan,'ok','MarkerSize',10,'Visible','off');
    else
        trackID = id(1);
        h.track = plot(h.cars.XData(1),h.cars.YData(1),'ok','MarkerSize',10);
    end
    h.track.UserData = trackID;

    axis equal;
    axis off;
    axis tight;

else
    % update visualization -----------------------------------------------

    h.colormap = col;
    phi = 2*pi*x/n;

    % vehicles
    h.cars.XData = cos(phi);
    h.cars.YData = ratio*sin(phi);
    h.cars.CData = col(colind,:);

    % tracked vehicle
    trackID = h.track.UserData;
    ind = find(id == trackID,1);

    % if the tracked vehicle was deleted, track the first available one
    if isempty(ind) && ~isempty(id)
        trackID = id(1);
        h.track.UserData = trackID;
        ind = 1;
    end

    if isempty(ind)
        % no vehicles available
        h.track.UserData = [];
        h.track.Visible = 'off';
    else
        h.track.XData = h.cars.XData(ind);
        h.track.YData = h.cars.YData(ind);
        h.track.Visible = 'on';
    end
end

title(['grid at timestep = ' num2str(t)]);
drawnow;

end
