classdef Road < handle
%ROAD Non-periodic Nagel-Schreckenberg road.
%
% u stores velocity in the real part and a global vehicle ID in the
% imaginary part; NaN denotes an empty cell. temp is the temporary
% continuation beyond the road end used by network nodes.

    properties
        u
        G
        vmax
        brake
        plot
        colormap
        t
        temp
        x
        y
    end

    properties (Access = private)
        h = []
    end

    methods

        function obj = Road(p)
        %ROAD Initialize one non-periodic road.

            arguments
                p.n (1,1) double {mustBePositive,mustBeInteger} = 200
                p.density (1,1) double {mustBeInRange(p.density,0,1)} = 0.2
                p.vmax (1,1) double {mustBePositive,mustBeInteger} = 8
                p.brake (1,1) double {mustBeInRange(p.brake,0,1)} = 0.05
                p.plot (1,1) double {mustBeInteger,mustBeBetween(p.plot,0,2)} = 1
                p.colormap (:,3) double = zeros(0,3)
                p.x (1,2) double = [0 1]
                p.y (1,2) double = [0 0]
            end

            obj.vmax = p.vmax;
            obj.brake = p.brake;
            obj.plot = p.plot;
            obj.t = 1;
            obj.x = p.x;
            obj.y = p.y;

            m = round(p.density*p.n);
            obj.u = nan(1,p.n);
            obj.u(randperm(p.n,m)) = 1i*(1:m);

            if isempty(p.colormap)
                if obj.plot == 1
                    obj.colormap = flipud(jet(obj.vmax+1));
                else
                    obj.colormap = parula(max(1,m));
                end
            else
                obj.colormap = p.colormap;
            end

            obj.G = [];
            obj.temp = [];

        end


        function update(obj)
        %UPDATE Advance the road by exactly one model step.

            xcar = find(~isnan(obj.u));
            v = real(obj.u(xcar));
            id = imag(obj.u(xcar));
            n = numel(obj.u);

            if ~isempty(xcar)
                d = [diff(xcar)-1, n-xcar(end)+numel(obj.temp)];
                v = min(obj.vmax,v+1);
                v = min(d,v);
                v = max(0,v-(rand(size(v)) < obj.brake));
                xcar = xcar+v;
                value = v+1i*id;

                obj.u(:) = nan;
                obj.temp(:) = nan;

                inside = xcar <= n;
                obj.u(xcar(inside)) = value(inside);

                q = xcar(~inside)-n;
                obj.temp(q) = value(~inside);
            else
                obj.temp(:) = nan;
            end

            obj.t = obj.t+1;

        end


        function save(obj)
        %SAVE Append the current state to the time-space history.

            obj.G(end+1,:) = obj.u;

        end


        function draw(obj,ax)
        %DRAW Draw or update the road.
        %
        % Graphics are created on the first call. Later calls update only
        % the vehicle positions and colors.

            if ~obj.plot
                return
            end

            if nargin < 2 || isempty(ax)
                ax = gca;
            end

            initialized = isstruct(obj.h) && isfield(obj.h,'ax') && isgraphics(obj.h.ax) && obj.h.ax == ax && isfield(obj.h,'street') && isgraphics(obj.h.street) && isfield(obj.h,'cars') && isgraphics(obj.h.cars);

            if ~initialized
                hold(ax,'on');
                obj.h.ax = ax;
                obj.h.street = quiver(ax,obj.x(1),obj.y(1),diff(obj.x),diff(obj.y),0,'LineWidth',2);
                obj.h.cars = scatter(ax,[],[],[],[],'filled');
            end

            pos = find(~isnan(obj.u));
            alpha = pos/numel(obj.u);

            obj.h.cars.XData = obj.x(1)+alpha*diff(obj.x);
            obj.h.cars.YData = obj.y(1)+alpha*diff(obj.y);

            if obj.plot == 1
                colind = real(obj.u(pos))+1;
            else
                colind = imag(obj.u(pos));
            end

            obj.h.cars.CData = obj.colormap(colind,:);

            drawnow;

        end


        function plotTimeSpace(obj,ax)
        %PLOTTIMESPACE Plot the saved time-space history.

            if nargin < 2 || isempty(ax)
                ax = gca;
            end

            if obj.plot == 1
                col = [1 1 1; obj.colormap];
                ind = real(obj.G)+2;
            else
                col = [1 1 1; obj.colormap];
                ind = imag(obj.G)+1;
            end

            image(ax,ind);
            colormap(ax,col);
            axis(ax,'tight');
            axis(ax,'off');

        end

    end

end
