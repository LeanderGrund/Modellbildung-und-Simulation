classdef (Abstract) Node < handle
%NODE Base class for connections between roads.

    properties
        in
        out
    end

    methods

        function obj = Node(in,out)
            obj.in = in;
            obj.out = out;
        end

    end

    methods (Access = protected)

        function temp = getTemp(obj,outRoad)
        %GETTEMP Return the free beginning of an outgoing road.

            i = find(~isnan(outRoad.u),1);

            if isempty(i)
                n = min(outRoad.vmax,numel(outRoad.u));
            else
                n = min(outRoad.vmax,i-1);
            end

            temp = nan(1,n);

        end


        function transferTemp(obj,inRoad,outRoad)
        %TRANSFERTEMP Copy the temporary continuation to the outgoing road.

            outRoad.u(1:numel(inRoad.temp)) = inRoad.temp;

        end

    end

    methods (Abstract)
        prepare(obj,map)
        transfer(obj,map)
    end

end
