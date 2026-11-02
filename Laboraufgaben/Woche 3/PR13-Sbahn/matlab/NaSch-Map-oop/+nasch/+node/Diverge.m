classdef Diverge < nasch.node.Node
%DIVERGE One incoming and several outgoing roads.

    properties (Access = private)
        selected
    end

    methods

        function obj = Diverge(in,out)
            obj@nasch.node.Node(in,out);
        end

        function prepare(obj,~)
            obj.selected = randi(numel(obj.out));
            obj.in.temp = obj.getTemp(obj.out(obj.selected));
        end

        function transfer(obj,~)
            obj.transferTemp(obj.in,obj.out(obj.selected));
        end

    end

end
