classdef MockAdsTransport < handle
    %MOCKADSTRANSPORT Offline transport for controller tests.

    properties
        Writes = struct("kind", {}, "symbol", {}, "value", {}, "netType", {})
        Reads = struct("symbol", {}, "netType", {})
    end

    properties (Access = private)
        ReadValues
    end

    methods
        function obj = MockAdsTransport()
            obj.ReadValues = containers.Map("KeyType", "char", "ValueType", "any");
        end

        function clear(obj)
            obj.Writes = struct("kind", {}, "symbol", {}, "value", {}, "netType", {});
            obj.Reads = struct("symbol", {}, "netType", {});
        end

        function setRead(obj, symbol, value)
            obj.ReadValues(char(symbol)) = value;
        end

        function writeScalar(obj, symbol, value, netType)
            obj.appendWrite("scalar", symbol, value, netType);
            obj.ReadValues(char(symbol)) = value;
            obj.updateReplayRegisters(symbol, value);
            obj.updateDiskRegisters(symbol, value);
        end

        function writeArray(obj, symbol, values, netType)
            obj.appendWrite("array", symbol, values, netType);
        end

        function value = readScalar(obj, symbol, netType)
            obj.Reads(end + 1) = struct( ...
                "symbol", string(symbol), ...
                "netType", string(netType));

            key = char(symbol);
            if isKey(obj.ReadValues, key)
                value = obj.ReadValues(key);
            else
                value = obj.defaultReadValue(netType);
            end
        end
    end

    methods (Access = private)
        function appendWrite(obj, kind, symbol, value, netType)
            obj.Writes(end + 1) = struct( ...
                "kind", string(kind), ...
                "symbol", string(symbol), ...
                "value", value, ...
                "netType", string(netType));
        end

        function value = defaultReadValue(~, netType)
            switch char(netType)
                case "System.Boolean"
                    value = false;
                case "System.Int16"
                    value = int16(0);
                case "System.UInt16"
                    value = uint16(0);
                case "System.UInt32"
                    value = uint32(0);
                case "System.Double"
                    value = double(0);
                otherwise
                    value = [];
            end
        end

        function updateReplayRegisters(obj, symbol, value)
            symbol = string(symbol);

            if endsWith(symbol, ".estopReq") && logical(value)
                obj.setSibling(symbol, "state", uint16(4));
                obj.setSibling(symbol, "outputValue", int16(0));
                obj.setSibling(symbol, "playbackDone", false);
                return;
            end

            if endsWith(symbol, ".resetReq") && logical(value)
                if ~logical(obj.getSibling(symbol, "estopReq", false))
                    obj.setSibling(symbol, "state", uint16(0));
                    obj.setSibling(symbol, "idx", uint32(0));
                    obj.setSibling(symbol, "cycleCount", uint32(0));
                    obj.setSibling(symbol, "playbackDone", false);
                    obj.setSibling(symbol, "errorCode", uint32(0));
                    obj.setSibling(symbol, "outputValue", int16(0));
                end
                return;
            end

            if endsWith(symbol, ".runReq")
                if logical(value)
                    tableLen = double(obj.getSibling(symbol, "tableLen", uint32(0)));
                    estopReq = logical(obj.getSibling(symbol, "estopReq", false));
                    if tableLen > 0 && ~estopReq
                        obj.setSibling(symbol, "state", uint16(1));
                        obj.setSibling(symbol, "playbackDone", false);
                    end
                else
                    estopReq = logical(obj.getSibling(symbol, "estopReq", false));
                    if ~estopReq
                        obj.setSibling(symbol, "state", uint16(0));
                        obj.setSibling(symbol, "idx", uint32(0));
                        obj.setSibling(symbol, "playbackDone", false);
                        obj.setSibling(symbol, "outputValue", int16(0));
                    end
                end
            end
        end

        function updateDiskRegisters(obj, symbol, value)
            symbol = string(symbol);

            if endsWith(symbol, ".RunCmd")
                if logical(value)
                    obj.setSibling(symbol, "AngleIncDemand", ...
                        double(obj.getSibling(symbol, "AngleIncTarget", 10.0)));
                    obj.setSibling(symbol, "TorqueDemand", ...
                        int16(obj.getSibling(symbol, "TorqueTarget", int16(3000))));
                else
                    obj.setSibling(symbol, "AngleIncDemand", 0.0);
                    obj.setSibling(symbol, "TorqueDemand", int16(0));
                    obj.setSibling(symbol, "TorqueCmd", int16(0));
                    obj.setSibling(symbol, "TargetTorque", int16(0));
                end
                return;
            end

            if endsWith(symbol, ".AngleIncTarget") && ...
                    logical(obj.getSibling(symbol, "RunCmd", false))
                obj.setSibling(symbol, "AngleIncDemand", double(value));
                return;
            end

            if endsWith(symbol, ".TorqueTarget") && ...
                    logical(obj.getSibling(symbol, "RunCmd", false))
                obj.setSibling(symbol, "TorqueDemand", int16(value));
            end
        end

        function setSibling(obj, symbol, name, value)
            obj.ReadValues(char(siblingSymbol(symbol, name))) = value;
        end

        function value = getSibling(obj, symbol, name, defaultValue)
            key = char(siblingSymbol(symbol, name));
            if isKey(obj.ReadValues, key)
                value = obj.ReadValues(key);
            else
                value = defaultValue;
            end
        end
    end
end

function sibling = siblingSymbol(symbol, name)
parts = split(string(symbol), ".");
parts(end) = string(name);
sibling = join(parts, ".");
end
