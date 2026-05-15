classdef AudioReplayController < handle
    %AUDIOREPLAYCONTROLLER High-level control API for Axis A audio replay.

    properties
        Config
        Transport
        LastMetadata = struct()
    end

    properties (Access = private)
        OwnsTransport = false
    end

    methods
        function obj = AudioReplayController(cfg)
            if nargin < 1 || isempty(cfg)
                cfg = hddaudio.defaultConfig();
            else
                cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
            end

            obj.Config = cfg;
            if isfield(cfg, "transport") && ~isempty(cfg.transport)
                obj.Transport = cfg.transport;
            else
                obj.Transport = hddaudio.AdsTransport(cfg);
                obj.OwnsTransport = true;
            end
        end

        function delete(obj)
            if obj.OwnsTransport && ~isempty(obj.Transport)
                obj.Transport.close();
            end
        end

        function metadata = upload(obj, command, metadata, progressCallback)
            if nargin < 3 || isempty(metadata)
                metadata = struct();
            end
            if nargin < 4
                progressCallback = [];
            end

            notifyProgress(progressCallback, 0.05, "Upload: normalizing command");
            command = hddaudio.normalizeCommand(command, obj.Config);
            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();

            notifyProgress(progressCallback, 0.15, "Upload: resetting replay");
            obj.Transport.writeScalar(symbols.runReq, false, types.bool);
            obj.Transport.writeScalar(symbols.resetReq, true, types.bool);
            pause(obj.Config.resetPulseSeconds);
            obj.Transport.writeScalar(symbols.resetReq, false, types.bool);
            notifyProgress(progressCallback, 0.35, "Upload: writing command table");
            obj.Transport.writeArray(symbols.commandTable, command, types.i16);
            notifyProgress(progressCallback, 0.85, "Upload: writing table length");
            obj.Transport.writeScalar(symbols.tableLen, uint32(numel(command)), types.u32);

            metadata.numSamples = numel(command);
            metadata.taskRateHz = obj.Config.taskRateHz;
            metadata.durationSeconds = double(numel(command)) / double(obj.Config.taskRateHz);
            metadata.amsNetId = obj.Config.amsNetId;
            metadata.plcPort = obj.Config.plcPort;
            metadata.namespace = obj.Config.namespace;
            metadata.started = false;
            metadata.mode = "uploaded";
            obj.LastMetadata = metadata;
            notifyProgress(progressCallback, 1.00, "Upload complete");

            if obj.OwnsTransport
                fprintf("Uploaded %d samples to %s:%d.\n", ...
                    numel(command), char(obj.Config.amsNetId), obj.Config.plcPort);
            else
                fprintf("Uploaded %d samples to injected transport.\n", numel(command));
            end
        end

        function start(obj, mode, varargin)
            if nargin < 2 || strlength(strtrim(string(mode))) == 0
                mode = "finite";
            end

            p = inputParser;
            p.addParameter("RepeatCount", 1, @is_positive_integer);
            p.parse(varargin{:});

            mode = lower(strtrim(string(mode)));
            switch mode
                case "loop"
                    repeatCount = uint32(0);
                case "finite"
                    repeatCount = uint32(p.Results.RepeatCount);
                otherwise
                    error("hddaudio:invalidStartMode", "Start mode must be loop or finite.");
            end

            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.repeatCount, repeatCount, types.u32);
            obj.Transport.writeScalar(symbols.runReq, true, types.bool);

            obj.LastMetadata.repeatCount = double(repeatCount);
            obj.LastMetadata.started = true;
            obj.LastMetadata.mode = mode;
        end

        function stop(obj)
            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.runReq, false, types.bool);
            obj.LastMetadata.started = false;
            obj.LastMetadata.mode = "stopped";
        end

        function estop(obj)
            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.estopReq, true, types.bool);
            obj.Transport.writeScalar(symbols.runReq, false, types.bool);
            obj.LastMetadata.started = false;
            obj.LastMetadata.mode = "estop";
        end

        function reset(obj)
            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.runReq, false, types.bool);
            obj.Transport.writeScalar(symbols.estopReq, false, types.bool);
            obj.Transport.writeScalar(symbols.resetReq, true, types.bool);
            pause(obj.Config.resetPulseSeconds);
            obj.Transport.writeScalar(symbols.resetReq, false, types.bool);
            obj.LastMetadata.started = false;
            obj.LastMetadata.mode = "reset";
        end

        function status = readStatus(obj)
            symbols = hddaudio.symbols(obj.Config.namespace);
            types = hddaudio.netTypes();

            status = struct();
            status.statusword = double(obj.Transport.readScalar(symbols.statusword, types.u16));
            status.controlword = double(obj.Transport.readScalar(symbols.controlword, types.u16));
            status.state = double(obj.Transport.readScalar(symbols.state, types.u16));
            status.stateName = hddaudio.stateName(status.state);
            status.idx = double(obj.Transport.readScalar(symbols.idx, types.u32));
            status.tableLen = double(obj.Transport.readScalar(symbols.tableLen, types.u32));
            status.repeatCount = double(obj.Transport.readScalar(symbols.repeatCount, types.u32));
            status.cycleCount = double(obj.Transport.readScalar(symbols.cycleCount, types.u32));
            status.playbackDone = logical(obj.Transport.readScalar(symbols.playbackDone, types.bool));
            status.errorCode = double(obj.Transport.readScalar(symbols.errorCode, types.u32));
            status.outputValue = double(obj.Transport.readScalar(symbols.outputValue, types.i16));
        end
    end
end

function tf = is_positive_integer(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0 && floor(value) == value;
end

function notifyProgress(callback, fraction, message)
if isempty(callback)
    return;
end
callback(min(max(double(fraction), 0), 1), string(message));
end
