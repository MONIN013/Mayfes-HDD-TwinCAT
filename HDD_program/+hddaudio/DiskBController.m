classdef DiskBController < handle
    %DISKBCONTROLLER High-level ADS control API for Disk_B.

    properties
        Config
        Transport
        LastStatus = struct()
    end

    properties (Access = private)
        OwnsTransport = false
    end

    methods
        function obj = DiskBController(cfg)
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

        function applySettings(obj, settings)
            if nargin < 2 || isempty(settings)
                settings = struct();
            end

            torqueTarget = settingValue(settings, "TorqueTarget", obj.Config.diskDefaultTorqueTarget);
            torqueRampStep = settingValue(settings, "TorqueRampStep", obj.Config.diskDefaultTorqueRampStep);
            angleIncTarget = settingValue(settings, "AngleIncTarget", obj.Config.diskDefaultAngleIncTarget);
            angleIncRampStep = settingValue(settings, "AngleIncRampStep", obj.Config.diskDefaultAngleIncRampStep);

            if torqueRampStep <= 0 || angleIncRampStep <= 0
                error("hddaudio:invalidDiskSettings", ...
                    "TorqueRampStep and AngleIncRampStep must be positive.");
            end

            symbols = hddaudio.diskSymbols(obj.Config.diskNamespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.torqueTarget, toInt16(torqueTarget, "TorqueTarget"), types.i16);
            obj.Transport.writeScalar(symbols.torqueRampStep, toInt16(torqueRampStep, "TorqueRampStep"), types.i16);
            obj.Transport.writeScalar(symbols.angleIncTarget, double(angleIncTarget), types.f64);
            obj.Transport.writeScalar(symbols.angleIncRampStep, double(angleIncRampStep), types.f64);
        end

        function start(obj)
            symbols = hddaudio.diskSymbols(obj.Config.diskNamespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.runCmd, true, types.bool);
        end

        function stop(obj)
            symbols = hddaudio.diskSymbols(obj.Config.diskNamespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.runCmd, false, types.bool);
        end

        function safeRestart(obj, settings)
            if nargin < 2 || isempty(settings)
                settings = struct();
            end

            obj.stop();
            obj.waitForZeroSpeed();
            obj.resetInternalMotion();
            obj.applySettings(settings);
            obj.start();
        end

        function status = readStatus(obj)
            symbols = hddaudio.diskSymbols(obj.Config.diskNamespace);
            types = hddaudio.netTypes();

            status = struct();
            status.statusword = double(obj.Transport.readScalar(symbols.statusword, types.u16));
            status.statusName = driveStateName(status.statusword);
            status.controlword = double(obj.Transport.readScalar(symbols.controlword, types.u16));
            status.swMasked = double(obj.Transport.readScalar(symbols.swMasked, types.u16));
            status.runCmd = logical(obj.Transport.readScalar(symbols.runCmd, types.bool));
            status.targetTorque = double(obj.Transport.readScalar(symbols.targetTorque, types.i16));
            status.torqueActual = double(obj.Transport.readScalar(symbols.torqueActual, types.i16));
            status.torqueCmd = double(obj.Transport.readScalar(symbols.torqueCmd, types.i16));
            status.torqueTarget = double(obj.Transport.readScalar(symbols.torqueTarget, types.i16));
            status.torqueRampStep = double(obj.Transport.readScalar(symbols.torqueRampStep, types.i16));
            status.torqueDemand = double(obj.Transport.readScalar(symbols.torqueDemand, types.i16));
            status.commutationAngle = double(obj.Transport.readScalar(symbols.commutationAngle, types.u16));
            status.angle = double(obj.Transport.readScalar(symbols.angle, types.f64));
            status.angleIncTarget = double(obj.Transport.readScalar(symbols.angleIncTarget, types.f64));
            status.angleIncActual = double(obj.Transport.readScalar(symbols.angleIncActual, types.f64));
            status.angleIncRampStep = double(obj.Transport.readScalar(symbols.angleIncRampStep, types.f64));
            status.angleIncDemand = double(obj.Transport.readScalar(symbols.angleIncDemand, types.f64));
            obj.LastStatus = status;
        end
    end

    methods (Access = private)
        function waitForZeroSpeed(obj)
            deadline = tic();
            timeout = double(obj.Config.diskRestartTimeoutSeconds);
            threshold = double(obj.Config.diskRestartZeroThreshold);
            pollSeconds = double(obj.Config.diskRestartPollSeconds);

            while true
                status = obj.readStatus();
                if abs(status.angleIncActual) <= threshold
                    return;
                end

                if toc(deadline) >= timeout
                    error("hddaudio:diskRestartTimeout", ...
                        "Disk_B did not decelerate below %.3f within %.3f seconds.", ...
                        threshold, timeout);
                end

                pause(pollSeconds);
            end
        end

        function resetInternalMotion(obj)
            symbols = hddaudio.diskSymbols(obj.Config.diskNamespace);
            types = hddaudio.netTypes();
            obj.Transport.writeScalar(symbols.angle, 0.0, types.f64);
            obj.Transport.writeScalar(symbols.angleIncActual, 0.0, types.f64);
            obj.Transport.writeScalar(symbols.torqueCmd, int16(0), types.i16);
        end
    end
end

function value = settingValue(settings, fieldName, defaultValue)
fieldName = char(fieldName);
lowerName = lowerFirst(fieldName);
if isfield(settings, fieldName)
    value = settings.(fieldName);
elseif isfield(settings, lowerName)
    value = settings.(lowerName);
else
    value = defaultValue;
end

if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
    error("hddaudio:invalidDiskSettings", "%s must be a finite numeric scalar.", fieldName);
end
value = double(value);
end

function value = toInt16(value, fieldName)
value = round(double(value));
if value < -32768 || value > 32767
    error("hddaudio:invalidDiskSettings", "%s must fit in a PLC INT.", fieldName);
end
value = int16(value);
end

function name = lowerFirst(name)
name = char(name);
name(1) = lower(name(1));
end

function name = driveStateName(statusword)
masked = bitand(uint16(statusword), uint16(hex2dec('006F')));
faulted = bitand(uint16(statusword), uint16(hex2dec('0008'))) ~= 0;
if faulted
    name = "FAULT";
elseif masked == uint16(hex2dec('0027'))
    name = "OPERATION_ENABLED";
elseif masked == uint16(hex2dec('0023'))
    name = "SWITCHED_ON";
elseif masked == uint16(hex2dec('0021'))
    name = "READY_TO_SWITCH_ON";
elseif masked == uint16(hex2dec('0040'))
    name = "SWITCH_ON_DISABLED";
else
    name = "UNKNOWN";
end
end
