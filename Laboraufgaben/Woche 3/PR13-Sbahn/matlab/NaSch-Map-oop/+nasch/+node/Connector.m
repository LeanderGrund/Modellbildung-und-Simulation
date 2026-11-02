classdef Connector < nasch.node.Node
%CONNECTOR One incoming and one outgoing road.

    methods

        function obj = Connector(in,out)
            obj@nasch.node.Node(in,out);
        end

        function prepare(obj,~)
            obj.in.temp = obj.getTemp(obj.out);
        end

        function transfer(obj,~)
            obj.transferTemp(obj.in,obj.out);
        end

    end

end
