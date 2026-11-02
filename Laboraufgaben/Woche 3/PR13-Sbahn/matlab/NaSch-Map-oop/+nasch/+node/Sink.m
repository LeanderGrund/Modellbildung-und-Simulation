classdef Sink < nasch.node.Node
%SINK Remove vehicles periodically from one incoming road.

    properties
        period
    end

    methods

        function obj = Sink(in,period)
            obj@nasch.node.Node(in,nasch.Road.empty(1,0));
            obj.period = period;
        end

        function prepare(obj,map)
            if obj.period > 0 && mod(map.t,obj.period) == 0
                obj.in.temp = nan(1,obj.in.vmax);
            else
                obj.in.temp = [];
            end
        end

        function transfer(obj,map)
            map.leave = map.leave+nnz(~isnan(obj.in.temp));
        end

    end

end
