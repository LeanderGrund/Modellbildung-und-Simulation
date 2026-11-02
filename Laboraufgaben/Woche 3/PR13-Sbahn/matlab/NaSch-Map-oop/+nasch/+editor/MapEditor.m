classdef MapEditor < handle
%MAPEDITOR Interactive editor for roundabout road networks.
%
% The editable network is stored as a digraph with node coordinates x and
% y. Roads may be directed or bidirectional. Saving also creates the flat
% constructor data used by nasch.Map.

    properties
        G = digraph([],[])
        mode = "addNode"
        vmax = 8
        density = 0.2
        brake = 0.05
    end

    properties (Access = private)
        h = []
        selected = []
        dragging = []
    end

    methods

        function obj = MapEditor(G)
        %MAPEDITOR Open the editor, optionally with an existing digraph.

            if nargin > 0
                obj.G = G;
            end

            obj.ensureXY();
            obj.createGUI();
            obj.draw();

        end


        function i = addNode(obj,x,y)
        %ADDNODE Add one roundabout center.

            obj.G = addnode(obj.G,1);
            i = numnodes(obj.G);
            obj.G.Nodes.x(i) = x;
            obj.G.Nodes.y(i) = y;
            obj.draw();

        end


        function removeNode(obj,i)
        %REMOVENODE Remove a node and all incident roads.

            obj.G = rmnode(obj.G,i);
            obj.selected = [];
            obj.draw();

        end


        function addRoad(obj,i,j)
        %ADDROAD Add the directed road i -> j.

            if i ~= j && findedge(obj.G,i,j) == 0
                obj.G = addedge(obj.G,i,j);
            end

            obj.selected = [];
            obj.draw();

        end


        function addTwoWayRoad(obj,i,j)
        %ADDTWOWAYROAD Add both directions between two nodes.

            if i ~= j
                if findedge(obj.G,i,j) == 0
                    obj.G = addedge(obj.G,i,j);
                end
                if findedge(obj.G,j,i) == 0
                    obj.G = addedge(obj.G,j,i);
                end
            end

            obj.selected = [];
            obj.draw();

        end


        function removeRoad(obj,i,j)
        %REMOVEROAD Remove both directions of one geometric road.

            if findedge(obj.G,i,j) ~= 0
                obj.G = rmedge(obj.G,i,j);
            end
            if findedge(obj.G,j,i) ~= 0
                obj.G = rmedge(obj.G,j,i);
            end

            obj.draw();

        end


        function generateRandom(obj,n,dmin,dmax)
        %GENERATERANDOM Replace the graph by a random Delaunay network.

            if nargin < 2, n = 10; end
            if nargin < 3, dmin = 100; end
            if nargin < 4, dmax = 300; end
            obj.G = nasch.editor.randomGraph(n,dmin,dmax);
            obj.selected = [];
            obj.dragging = [];
            obj.draw();

        end


        function save(obj,filename)
        %SAVE Save the editable graph and nasch.Map constructor data.

            if nargin < 2
                [file,path] = uiputfile('*.mat','Save NaSch map');
                if isequal(file,0), return, end
                filename = fullfile(path,file);
            end

            data = nasch.editor.graphToMapData(obj.G,obj.vmax,obj.density,obj.brake);
            data.G = obj.G;
            save(filename,'data');

        end


        function load(obj,filename)
        %LOAD Load a graph saved by this editor.

            if nargin < 2
                [file,path] = uigetfile('*.mat','Load NaSch map');
                if isequal(file,0), return, end
                filename = fullfile(path,file);
            end

            S = load(filename,'data');
            obj.G = S.data.G;

            if isfield(S.data,'vmax'), obj.vmax = S.data.vmax; end
            if isfield(S.data,'density'), obj.density = S.data.density; end
            if isfield(S.data,'brake'), obj.brake = S.data.brake; end

            obj.ensureXY();
            obj.selected = [];
            obj.dragging = [];
            obj.draw();

        end


        function draw(obj)
        %DRAW Redraw the editor after a topology or geometry change.

            ax = obj.h.ax;
            cla(ax);
            hold(ax,'on');
            x = obj.G.Nodes.x;
            y = obj.G.Nodes.y;
            ends = obj.G.Edges.EndNodes;

            if ~isempty(ends)
                pairs = unique(sort(ends,2),'rows');

                for k = 1:size(pairs,1)
                    i = pairs(k,1);
                    j = pairs(k,2);
                    p1 = [x(i) y(i)];
                    d = [x(j)-x(i) y(j)-y(i)];
                    plot(ax,[x(i) x(j)],[y(i) y(j)],'LineWidth',1.2);

                    if norm(d) > 0
                        u = d/norm(d);
                        a = 0.08*norm(d);

                        if findedge(obj.G,i,j) ~= 0
                            c = p1+0.58*d;
                            q = c-a/2*u;
                            quiver(ax,q(1),q(2),a*u(1),a*u(2),0,'LineWidth',1.2,'MaxHeadSize',0.8);
                        end

                        if findedge(obj.G,j,i) ~= 0
                            c = p1+0.42*d;
                            q = c+a/2*u;
                            quiver(ax,q(1),q(2),-a*u(1),-a*u(2),0,'LineWidth',1.2,'MaxHeadSize',0.8);
                        end
                    end
                end
            end

            scatter(ax,x,y,70,'filled');

            if ~isempty(obj.selected)
                scatter(ax,x(obj.selected),y(obj.selected),160,'LineWidth',2);
            end

            for i = 1:numnodes(obj.G)
                text(ax,x(i),y(i)+20,num2str(i),'HorizontalAlignment','center');
            end

            axis(ax,'equal');
            grid(ax,'on');
            box(ax,'on');
            obj.updateStatus();

        end

    end


    methods (Access = private)

        function createGUI(obj)
        %CREATEGUI Create the editor window and controls.

            obj.h.fig = figure('Name','NaSch Map Editor','NumberTitle','off','MenuBar','none','ToolBar','figure','WindowButtonDownFcn',@(~,~)obj.onClick(),'WindowButtonMotionFcn',@(~,~)obj.onMouseMove(),'WindowButtonUpFcn',@(~,~)obj.onMouseUp());
            obj.h.ax = axes('Parent',obj.h.fig,'Units','normalized','Position',[0.05 0.08 0.70 0.87]);
            xlim(obj.h.ax,[0 1000]);
            ylim(obj.h.ax,[0 1000]);
            axis(obj.h.ax,'equal');
            grid(obj.h.ax,'on');
            box(obj.h.ax,'on');

            panel = uipanel('Parent',obj.h.fig,'Units','normalized','Position',[0.78 0.08 0.20 0.87],'Title','Edit');
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.88 0.84 0.07],'String','+ Node','Callback',@(~,~)obj.setMode("addNode"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.79 0.84 0.07],'String','Move Node','Callback',@(~,~)obj.setMode("moveNode"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.70 0.84 0.07],'String','- Node','Callback',@(~,~)obj.setMode("deleteNode"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.57 0.84 0.07],'String','-> Road','Callback',@(~,~)obj.setMode("addRoad"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.48 0.84 0.07],'String','<-> Road','Callback',@(~,~)obj.setMode("addTwoWayRoad"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.39 0.84 0.07],'String','- Road','Callback',@(~,~)obj.setMode("deleteRoad"));
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.25 0.84 0.08],'String','Random network','Callback',@(~,~)obj.onRandomNetwork());
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.08 0.12 0.39 0.07],'String','Save','Callback',@(~,~)obj.save());
            uicontrol(panel,'Style','pushbutton','Units','normalized','Position',[0.53 0.12 0.39 0.07],'String','Load','Callback',@(~,~)obj.load());
            obj.h.status = uicontrol(obj.h.fig,'Style','text','Units','normalized','Position',[0.05 0.01 0.93 0.04],'HorizontalAlignment','left');

        end


        function setMode(obj,mode)
            obj.mode = mode;
            obj.selected = [];
            obj.dragging = [];
            obj.draw();
        end


        function onClick(obj)
            target = hittest(obj.h.fig);
            ax = ancestor(target,'axes');
            if isempty(ax) || ax ~= obj.h.ax
                return
            end

            p = obj.h.ax.CurrentPoint;
            x = p(1,1);
            y = p(1,2);

            switch obj.mode
                case "addNode"
                    obj.addNode(x,y);
                case "moveNode"
                    obj.dragging = obj.findNode(x,y);
                    obj.selected = obj.dragging;
                    obj.draw();
                case "deleteNode"
                    i = obj.findNode(x,y);
                    if ~isempty(i), obj.removeNode(i); end
                case "addRoad"
                    i = obj.findNode(x,y);
                    if ~isempty(i), obj.selectRoadEndpoint(i,false); end
                case "addTwoWayRoad"
                    i = obj.findNode(x,y);
                    if ~isempty(i), obj.selectRoadEndpoint(i,true); end
                case "deleteRoad"
                    [i,j] = obj.findRoad(x,y);
                    if ~isempty(i), obj.removeRoad(i,j); end
            end
        end


        function onMouseMove(obj)
            if isempty(obj.dragging), return, end
            p = obj.h.ax.CurrentPoint;
            obj.G.Nodes.x(obj.dragging) = p(1,1);
            obj.G.Nodes.y(obj.dragging) = p(1,2);
            obj.draw();
        end


        function onMouseUp(obj)
            obj.dragging = [];
            obj.selected = [];
        end


        function onRandomNetwork(obj)
            a = inputdlg({'Number of nodes','Minimum distance','Maximum distance'},'Random network',1,{'10','100','300'});
            if isempty(a), return, end
            v = str2double(a);
            obj.generateRandom(v(1),v(2),v(3));
        end


        function selectRoadEndpoint(obj,i,twoWay)
            if isempty(obj.selected)
                obj.selected = i;
                obj.draw();
                return
            end

            j = i;
            i = obj.selected;

            if twoWay
                obj.addTwoWayRoad(i,j);
            else
                obj.addRoad(i,j);
            end
        end


        function i = findNode(obj,x,y)
            if numnodes(obj.G) == 0
                i = [];
                return
            end

            d = hypot(obj.G.Nodes.x-x,obj.G.Nodes.y-y);
            [dmin,i] = min(d);
            scale = max([diff(xlim(obj.h.ax)) diff(ylim(obj.h.ax))]);
            if dmin > 0.035*scale, i = []; end
        end


        function [i,j] = findRoad(obj,x,y)
            i = [];
            j = [];
            pairs = unique(sort(obj.G.Edges.EndNodes,2),'rows');
            best = inf;
            p = [x y];

            for k = 1:size(pairs,1)
                a = pairs(k,1);
                b = pairs(k,2);
                p1 = [obj.G.Nodes.x(a) obj.G.Nodes.y(a)];
                d = [obj.G.Nodes.x(b)-p1(1) obj.G.Nodes.y(b)-p1(2)];
                dd = dot(d,d);
                if dd == 0
                    dist = norm(p-p1);
                else
                    s = min(1,max(0,dot(p-p1,d)/dd));
                    dist = norm(p-(p1+s*d));
                end

                if dist < best
                    best = dist;
                    i = a;
                    j = b;
                end
            end

            scale = max([diff(xlim(obj.h.ax)) diff(ylim(obj.h.ax))]);
            if best > 0.025*scale, i = []; j = []; end
        end


        function ensureXY(obj)
            n = numnodes(obj.G);
            vars = obj.G.Nodes.Properties.VariableNames;
            if ~ismember('x',vars), obj.G.Nodes.x = zeros(n,1); end
            if ~ismember('y',vars), obj.G.Nodes.y = zeros(n,1); end
        end


        function updateStatus(obj)
            switch obj.mode
                case "addNode", text = 'Add node: click a position.';
                case "moveNode", text = 'Move node: drag a node.';
                case "deleteNode", text = 'Delete node: click a node.';
                case "addRoad", text = 'Add road: click start and end node.';
                case "addTwoWayRoad", text = 'Add two-way road: click both nodes.';
                case "deleteRoad", text = 'Delete road: click the road.';
            end
            obj.h.status.String = text;
        end

    end

end
