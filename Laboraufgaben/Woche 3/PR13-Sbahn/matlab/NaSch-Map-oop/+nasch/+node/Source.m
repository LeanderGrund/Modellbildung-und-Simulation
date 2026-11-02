classdef Source < nasch.node.Node
%SOURCE Insert vehicles periodically into one outgoing road.

    properties
        period
    end

    methods

        function obj = Source(out,period)
            obj@nasch.node.Node(nasch.Road.empty(1,0),out);
            obj.period = period;
        end

        function prepare(obj,~)
        end

        function transfer(obj,map)
            if obj.period > 0 && mod(map.t,obj.period) == 0 && isnan(obj.out.u(1))
                obj.out.u(1) = obj.out.vmax+1i*map.nextID;
                map.nextID = map.nextID+1;
            end
        end

    end

end
