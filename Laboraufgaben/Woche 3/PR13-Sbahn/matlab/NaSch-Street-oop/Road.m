classdef Road < handle
%ROAD Periodic Nagel-Schreckenberg road with elliptical visualization.
%
% u stores the velocity in the real part and the vehicle ID in the
% imaginary part; NaN denotes an empty cell. G stores the complete
% time-space history.

    properties
        u
        G
        vmax
        brake
        plot
        colormap
        t
        ratio
    end

    properties (Access = private)
        h = []
    end

    methods

        function obj = Road(p)
        %ROAD Initialize one periodic road.

            arguments
                p.n (1,1) double {mustBePositive,mustBeInteger} = 200
                p.density (1,1) double {mustBeInRange(p.density,0,1)} = 0.2
                p.vmax (1,1) double {mustBePositive,mustBeInteger} = 8
                p.brake (1,1) double {mustBeInRange(p.brake,0,1)} = 0.05
                p.plot (1,1) double {mustBeInteger,mustBeBetween(p.plot,0,2)} = 1
                p.colormap (:,3) double = zeros(0,3)
                p.ratio (1,1) double {mustBePositive} = 0.5
            end

            obj.vmax = p.vmax;
            obj.brake = p.brake;
            obj.plot = p.plot;
            obj.t = 1;
            obj.ratio = p.ratio;

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

            obj.G = obj.u;

        end


        function update(obj)
        %UPDATE Advance the periodic road by exactly one model step.

            xcar = find(~isnan(obj.u));

            if ~isempty(xcar)
                v = real(obj.u(xcar));
                id = imag(obj.u(xcar));
                n = numel(obj.u);

                % Free cells in front, including the periodic boundary.
                d = [diff(xcar)-1, xcar(1)+n-xcar(end)-1];

                % Nagel-Schreckenberg update.
                v = min(obj.vmax,v+1);
                v = min(d,v);
                v = max(0,v-(rand(size(v)) < obj.brake));

                % Move vehicles and wrap around periodically.
                xcar = mod(xcar+v-1,n)+1;

                obj.u(:) = nan;
                obj.u(xcar) = v+1i*id;
            end

            obj.t = obj.t+1;
            obj.G(end+1,:) = obj.u;

        end


        function draw(obj,ax)
        %DRAW Draw or update the periodic road as an ellipse.
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

                phi = linspace(0,2*pi,300);

                obj.h.ax = ax;
                obj.h.street = plot(ax,cos(phi),obj.ratio*sin(phi),'LineWidth',2);
                obj.h.cars = scatter(ax,[],[],[],[],'filled');
                obj.h.title = title(ax,'');

                axis(ax,'equal');
                axis(ax,'off');
            end

            pos = find(~isnan(obj.u));
            phi = 2*pi*pos/numel(obj.u);

            obj.h.cars.XData = cos(phi);
            obj.h.cars.YData = obj.ratio*sin(phi);

            if obj.plot == 1
                colind = real(obj.u(pos))+1;
            else
                colind = imag(obj.u(pos));
            end

            obj.h.cars.CData = obj.colormap(colind,:);
            obj.h.title.String = ['road at timestep = ' num2str(obj.t)];

            drawnow;

        end


        function plotTimeSpace(obj,ax)
        %PLOTTIMESPACE Plot the time-space history.

            if ~obj.plot
                return
            end

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
