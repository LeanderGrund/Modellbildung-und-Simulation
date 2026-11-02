classdef Merge < nasch.node.Node
%MERGE Several incoming roads with fixed priority and one outgoing road.

    methods

        function obj = Merge(in,out)
            obj@nasch.node.Node(in,out);
        end

        function prepare(obj,~)
            obj.in(1).temp = obj.getTemp(obj.out);

            for k = 2:numel(obj.in)
                previous = obj.in(k-1);
                n = min(previous.vmax,numel(previous.u));

                if all(isnan(previous.u(end-n+1:end)))
                    obj.in(k).temp = obj.getTemp(obj.out);
                else
                    obj.in(k).temp = [];
                end
            end
        end

        function transfer(obj,~)
            for k = 1:numel(obj.in)
                obj.transferTemp(obj.in(k),obj.out);
            end
        end

    end

end
