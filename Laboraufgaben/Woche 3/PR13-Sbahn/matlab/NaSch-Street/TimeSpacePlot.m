function TimeSpacePlot(G,p)
%TIMESPACEPLOT Plot the space-time evolution of the NaSch traffic model.
%
% G contains the street state at successive time steps:
%   rows    : time steps
%   columns : street cells
%
% The state is stored as a complex-valued matrix:
%   NaN     : empty cell
%   real(G) : vehicle velocity
%   imag(G) : vehicle ID
%
% Depending on p.plot, the space-time diagram is colored by
%   1 : vehicle velocity
%   2 : vehicle ID
%
% The average vehicle velocity is shown in a second plot.

if ~p.plot, return; end

% evaluate simulation data -----------------------------------------------

[nt,~] = size(G);

v  = real(G);
id = imag(G);

% average velocity at each time step
vmean = mean(v,2,'omitnan');

% plot ---------------------------------------------------------------

clf;
tiledlayout(1,4, 'TileSpacing', 'compact', 'Padding', 'compact');

% space-time diagram
ax1 = nexttile([1 3]);

% colormap
switch p.plot
    case 1 % color represents velocity
        col = [1 1 1; flipud(jet(p.vmax+1))];
        colind = v+2;

    case 2 % color represents vehicle ID
        maxID = max(id,[],'all','omitnan');
        if isempty(maxID) || isnan(maxID), maxID = 1; end
        col = [1 1 1; parula(maxID)];
        colind = id+1;
end

image(colind);
colormap(col);

% velocity colorbar
if p.plot == 1
    c = colorbar('YTickLabel',{0:p.vmax},'Ticks',1.5+(1:p.vmax+1));
    ylabel(c,'velocity');
end

axis tight;
grid on;
title('street occupation');
xlabel('place  \rightarrow');
ylabel('\leftarrow time');

% trajectory of vehicle with ID 1
hold on;
[tt,xx] = find(id == 1);
plot(xx,tt,'ok','MarkerSize',5);

% average velocity -------------------------------------------------------

ax2 = nexttile;
plot(vmean,1:nt);
title('average velocity');
xlabel('velocity  \rightarrow');
ylabel('\leftarrow time');
set(ax2,'YDir','reverse');
grid on;

% use identical time axes
linkaxes([ax1 ax2],'y');

end

% ------------------------------------------------------------------------