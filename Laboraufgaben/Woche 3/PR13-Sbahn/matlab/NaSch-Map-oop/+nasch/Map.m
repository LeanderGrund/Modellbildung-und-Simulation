classdef Map < handle
%MAP Nagel-Schreckenberg road network.
%
% Roads are connected by Source, Sink, Connector, Diverge, and Merge
% nodes inferred from node1 and node2. One call to update advances the
% complete network by exactly one model step.

    properties
        roads
        nodes
        node1
        node2
        nodex
        nodey
        times
        plot
        t
        nextID
        leave
    end

    properties (Access = private)
        h = []
    end

    methods

        function obj = Map(p)
        %MAP Construct, load, or randomly generate a road network.
        %
        % map = nasch.Map()
        % map = nasch.Map("file","network.mat")
        % map = nasch.Map("struct",data)
        % map = nasch.Map("node1",node1,"node2",node2,"nodex",x,"nodey",y)
        %
        % Explicit name-value arguments override values loaded from file
        % or struct.

            arguments
                p.file (1,1) string = ""
                p.struct struct = struct()
                p.node1 (1,:) double = []
                p.node2 (1,:) double = []
                p.nodex (1,:) double = []
                p.nodey (1,:) double = []
                p.times (1,:) double = []
                p.density double = []
                p.vmax double = []
                p.brake double = []
                p.plot double = []
                p.colormap (:,3) double = zeros(0,3)
            end

            data = struct("node1",[],"node2",[],"nodex",[],"nodey",[],"times",[],"density",0.2,"vmax",8,"brake",0.05,"plot",1,"colormap",zeros(0,3));

            if p.file ~= ""
                S = load(p.file,"data");
                loaded = S.data;
            elseif ~isempty(fieldnames(p.struct))
                loaded = p.struct;
            else
                loaded = struct();
            end

            names = fieldnames(loaded);
            for k = 1:numel(names)
                data.(names{k}) = loaded.(names{k});
            end

            names = {'node1','node2','nodex','nodey','times','density','vmax','brake','plot','colormap'};
            for k = 1:numel(names)
                value = p.(names{k});
                if ~isempty(value)
                    data.(names{k}) = value;
                end
            end

            if isempty(data.node1)
                G = nasch.editor.randomGraph();
                generated = nasch.editor.graphToMapData(G,data.vmax,data.density,data.brake);
                data.node1 = generated.node1;
                data.node2 = generated.node2;
                data.nodex = generated.nodex;
                data.nodey = generated.nodey;
                data.times = generated.times;
            end

            node1 = data.node1;
            node2 = data.node2;
            nodex = data.nodex;
            nodey = data.nodey;
            nroad = numel(node1);
            nnode = numel(nodex);

            if numel(node2) ~= nroad || numel(nodey) ~= nnode
                error('Inconsistent network dimensions.');
            end

            used = unique([node1 node2]);
            if any(used < 1) || any(used ~= round(used)) || ~isequal(used,1:nnode)
                error('Node indices must be consecutive integers from 1 to numel(nodex).');
            end

            if isempty(data.times)
                data.times = zeros(1,nroad);
            elseif numel(data.times) ~= nroad
                error('times must contain one value for every road.');
            end

            obj.node1 = node1;
            obj.node2 = node2;
            obj.nodex = nodex;
            obj.nodey = nodey;
            obj.times = data.times;
            obj.plot = data.plot;
            obj.t = 1;
            obj.leave = 0;

            obj.roads = nasch.Road.empty(1,0);
            nextID = 1;

            for k = 1:nroad
                len = max(1,round(hypot(nodex(node2(k))-nodex(node1(k)),nodey(node2(k))-nodey(node1(k)))));
                road = nasch.Road("n",len,"density",data.density,"vmax",data.vmax,"brake",data.brake,"plot",data.plot,"colormap",data.colormap,"x",[nodex(node1(k)) nodex(node2(k))],"y",[nodey(node1(k)) nodey(node2(k))]);

                pos = find(~isnan(road.u));
                m = numel(pos);
                road.u(pos) = real(road.u(pos))+1i*(nextID:nextID+m-1);
                nextID = nextID+m;
                road.save();
                obj.roads(k) = road;
            end

            obj.nextID = nextID;

            if obj.plot == 2 && isempty(data.colormap)
                col = parula(max(1,nextID-1));
                for k = 1:nroad
                    obj.roads(k).colormap = col;
                end
            end

            obj.nodes = cell(1,nnode);

            for k = 1:nnode
                inIndex = find(node2 == k);
                outIndex = find(node1 == k);
                in = obj.roads(inIndex);
                out = obj.roads(outIndex);

                if isempty(in) && numel(out) == 1
                    obj.nodes{k} = nasch.node.Source(out,obj.times(outIndex));
                elseif numel(in) == 1 && isempty(out)
                    obj.nodes{k} = nasch.node.Sink(in,obj.times(inIndex));
                elseif numel(in) == 1 && numel(out) == 1
                    obj.nodes{k} = nasch.node.Connector(in,out);
                elseif numel(in) == 1
                    obj.nodes{k} = nasch.node.Diverge(in,out);
                elseif numel(out) == 1
                    obj.nodes{k} = nasch.node.Merge(in,out);
                else
                    error('Node %d has unsupported MIMO topology.',k);
                end
            end

        end


        function update(obj)
        %UPDATE Advance the complete network by exactly one model step.
        %
        % The phases are executed sequentially for the whole network:
        % prepare nodes, update roads, transfer vehicles, save states.

            obj.t = obj.t+1;

            for k = 1:numel(obj.nodes)
                obj.nodes{k}.prepare(obj);
            end

            for k = 1:numel(obj.roads)
                obj.roads(k).update();
            end

            for k = 1:numel(obj.nodes)
                obj.nodes{k}.transfer(obj);
            end

            for k = 1:numel(obj.roads)
                obj.roads(k).save();
            end

        end


        function draw(obj,ax)
        %DRAW Draw or update the road network.
        %
        % The graphics objects are created on the first call. Later calls
        % update only vehicle positions, colors, and the time label.

            if ~obj.plot
                return
            end

            if nargin < 2 || isempty(ax)
                ax = gca;
            end

            initialized = isstruct(obj.h) && isfield(obj.h,'ax') && isgraphics(obj.h.ax) && obj.h.ax == ax && isfield(obj.h,'street') && isgraphics(obj.h.street) && isfield(obj.h,'cars') && isgraphics(obj.h.cars) && isfield(obj.h,'title') && isgraphics(obj.h.title);

            if ~initialized
                cla(ax);
                hold(ax,'on');

                nroad = numel(obj.roads);
                xroad = zeros(1,nroad);
                yroad = zeros(1,nroad);
                dx = zeros(1,nroad);
                dy = zeros(1,nroad);

                for k = 1:nroad
                    xroad(k) = obj.roads(k).x(1);
                    yroad(k) = obj.roads(k).y(1);
                    dx(k) = diff(obj.roads(k).x);
                    dy(k) = diff(obj.roads(k).y);
                end

                obj.h.ax = ax;
                obj.h.street = quiver(ax,xroad,yroad,dx,dy,0,'LineWidth',1);
                obj.h.cars = scatter(ax,[],[],[],[],'filled');
                obj.h.title = title(ax,'');
                obj.h.colormap = obj.roads(1).colormap;

                colormap(ax,obj.h.colormap);
                clim(ax,[1 max(2,size(obj.h.colormap,1))]);
                axis(ax,'equal');
                axis(ax,'off');
            end

            ncar = 0;
            for k = 1:numel(obj.roads)
                ncar = ncar+nnz(~isnan(obj.roads(k).u));
            end

            x = zeros(1,ncar);
            y = zeros(1,ncar);
            c = zeros(1,ncar);
            first = 1;

            for k = 1:numel(obj.roads)
                road = obj.roads(k);
                pos = find(~isnan(road.u));
                n = numel(pos);

                if n == 0
                    continue
                end

                ind = first:first+n-1;
                alpha = pos/numel(road.u);
                x(ind) = road.x(1)+alpha*diff(road.x);
                y(ind) = road.y(1)+alpha*diff(road.y);

                if obj.plot == 1
                    c(ind) = real(road.u(pos))+1;
                else
                    c(ind) = imag(road.u(pos));
                end

                first = first+n;
            end

            if obj.plot == 2 && obj.nextID-1 > size(obj.h.colormap,1)
                ncol = max(1,obj.nextID-1);
                obj.h.colormap = parula(ncol);
                for k = 1:numel(obj.roads)
                    obj.roads(k).colormap = obj.h.colormap;
                end
                colormap(obj.h.ax,obj.h.colormap);
                clim(obj.h.ax,[1 ncol]);
            end

            obj.h.cars.XData = x;
            obj.h.cars.YData = y;
            obj.h.cars.CData = c;
            obj.h.title.String = ['road network at timestep = ' num2str(obj.t)];

            drawnow;

        end

    end

end
