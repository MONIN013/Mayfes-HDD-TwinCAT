classdef AdsTransport < handle
    %ADSTRANSPORT TwinCAT ADS transport for AudioReplayController.

    properties (Access = private)
        Client = []
        Handles
    end

    methods
        function obj = AdsTransport(cfg)
            if nargin < 1 || isempty(cfg)
                cfg = hddaudio.defaultConfig();
            else
                cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
            end

            obj.Handles = containers.Map("KeyType", "char", "ValueType", "any");
            hddaudio.AdsTransport.loadAdsAssembly(cfg.adsAssembly);
            obj.Client = TwinCAT.Ads.TcAdsClient();
            obj.Client.Connect(char(cfg.amsNetId), int32(cfg.plcPort));
        end

        function delete(obj)
            obj.close();
        end

        function close(obj)
            if isempty(obj.Client)
                return;
            end

            keys = obj.Handles.keys;
            for idx = 1:numel(keys)
                try
                    obj.Client.DeleteVariableHandle(obj.Handles(keys{idx}));
                catch
                end
            end
            obj.Handles = containers.Map("KeyType", "char", "ValueType", "any");

            try
                obj.Client.Dispose();
            catch
            end
            obj.Client = [];
        end

        function writeScalar(obj, symbol, value, netType)
            handle = obj.variableHandle(symbol);
            obj.Client.WriteAny(handle, hddaudio.AdsTransport.toNetScalar(value, netType));
        end

        function writeArray(obj, symbol, values, netType)
            handle = obj.variableHandle(symbol);
            values = values(:);

            switch char(netType)
                case "System.Int16"
                    netArray = hddaudio.AdsTransport.toNetInt16Array(values);
                otherwise
                    error("hddaudio:unsupportedArrayType", "Unsupported array type: %s.", string(netType));
            end

            obj.Client.WriteAny(handle, netArray);
        end

        function value = readScalar(obj, symbol, netType)
            handle = obj.variableHandle(symbol);
            type = System.Type.GetType(char(netType));
            value = obj.Client.ReadAny(handle, type);
            value = hddaudio.AdsTransport.fromNetScalar(value, netType);
        end
    end

    methods (Access = private)
        function handle = variableHandle(obj, symbol)
            key = char(symbol);
            if isKey(obj.Handles, key)
                handle = obj.Handles(key);
                return;
            end

            handle = obj.Client.CreateVariableHandle(key);
            obj.Handles(key) = handle;
        end
    end

    methods (Static, Access = private)
        function loadAdsAssembly(explicitAssembly)
            candidates = strings(0, 1);
            explicitAssembly = string(explicitAssembly);
            if strlength(strtrim(explicitAssembly)) > 0
                candidates(end + 1, 1) = explicitAssembly;
            end

            knownPath = "C:\Program Files (x86)\Beckhoff\TwinCAT\Functions\TE14xx-ToolsForMatlabAndSimulink\TE140x\NET\TwinCAT.Ads.dll";
            if isfile(knownPath)
                candidates(end + 1, 1) = knownPath;
            end
            candidates(end + 1, 1) = "TwinCAT.Ads";

            [~, uniqueIdx] = unique(candidates, "stable");
            candidates = candidates(uniqueIdx);

            lastError = [];
            for idx = 1:numel(candidates)
                try
                    NET.addAssembly(char(candidates(idx)));
                    return;
                catch err
                    lastError = err;
                end
            end

            error("hddaudio:assemblyLoadFailed", ...
                "Failed to load TwinCAT.Ads assembly: %s", lastError.message);
        end

        function value = toNetScalar(value, netType)
            switch char(netType)
                case "System.Boolean"
                    value = logical(value);
                case "System.UInt16"
                    value = uint16(value);
                case "System.UInt32"
                    value = uint32(value);
                case "System.Int16"
                    value = int16(value);
                case "System.Double"
                    value = double(value);
                otherwise
                    error("hddaudio:unsupportedScalarType", "Unsupported scalar type: %s.", string(netType));
            end
        end

        function netArray = toNetInt16Array(values)
            values = int16(values(:));
            try
                netArray = NET.convertArray(values, "System.Int16");
            catch
                netArray = NET.createArray("System.Int16", numel(values));
                for idx = 1:numel(values)
                    netArray(idx) = values(idx);
                end
            end
        end

        function value = fromNetScalar(value, netType)
            switch char(netType)
                case "System.Boolean"
                    value = logical(value);
                case "System.UInt16"
                    value = uint16(value);
                case "System.UInt32"
                    value = uint32(value);
                case "System.Int16"
                    value = int16(value);
                case "System.Double"
                    value = double(value);
                otherwise
                    error("hddaudio:unsupportedScalarType", "Unsupported scalar type: %s.", string(netType));
            end
        end
    end
end
