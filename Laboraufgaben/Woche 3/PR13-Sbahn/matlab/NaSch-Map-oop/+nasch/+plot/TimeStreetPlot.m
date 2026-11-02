function TimeStreetPlot(road,ax,colormapID)
%TIMESTREETPLOT Plot the time-space history of one Road object.

if ~road.plot, return; end
if nargin < 2 || isempty(ax), ax = gca; end

if road.plot == 1
    col = [1 1 1; road.colormap];
    ind = real(road.G)+2;
else
    if nargin < 3 || isempty(colormapID)
        maxID = max(imag(road.G),[],'all','omitnan');
        if isempty(maxID) || isnan(maxID), maxID = 1; end
        if size(road.colormap,1) >= maxID
            colormapID = road.colormap;
        else
            colormapID = parula(maxID);
        end
    end

    col = [1 1 1; colormapID];
    ind = imag(road.G)+1;
end

image(ax,ind);
colormap(ax,col);
axis(ax,'tight');
axis(ax,'off');

end
