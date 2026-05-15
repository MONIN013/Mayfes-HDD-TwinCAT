function result = run_hdd_audio(action, varargin)
%RUN_HDD_AUDIO Entry point for HDD audio replay from MATLAB.
%
%   run_hdd_audio()
%       Open the offline control panel. This does not connect to ADS.
%
%   run_hdd_audio("panel", "Online", true)
%       Open the control panel with ADS communication enabled.
%
%   data = run_hdd_audio("generate")
%       Build the default command table without ADS communication.
%
%   run_hdd_audio("upload", "Online", true)
%       Build and upload the default command table.
%
%   run_hdd_audio("loop", "Online", true)
%       Build, upload, and start infinite loop playback.
%
%   run_hdd_audio("finite", "Online", true, "RepeatCount", 3)
%       Build, upload, and play the table three times.
%
%   run_hdd_audio("stop"|"estop"|"reset"|"status", "Online", true)
%       Send a control command or read PLC status.
%
%   Safety default:
%       Online is false by default. Without "Online", true this entry point
%       uses hddaudio.MockAdsTransport and never attempts ADS communication.

project_dir = fileparts(mfilename("fullpath"));
addpath(project_dir);

if nargin < 1 || strlength(strtrim(string(action))) == 0
    action = "panel";
end

opts = parse_options(varargin{:});
action = lower(strtrim(string(action)));

cfg = make_config(opts);
spec = opts.Spec;
result = struct("action", action, "online", opts.Online);

switch action
    case "panel"
        app = hddaudio.launchControlPanel(cfg);
        result.app = app;

    case "generate"
        [command, metadata] = build_preview_command(spec, cfg);
        result.command = command;
        result.metadata = metadata;
        assign_outputs(command, metadata);
        fprintf("Generated %d samples (%.3f s). Preview: %s\n", ...
            metadata.numSamples, metadata.durationSeconds, char(metadata.previewWavFile));

    case "upload"
        [command, metadata] = build_preview_command(spec, cfg);
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        result.metadata = ctrl.upload(command, metadata);
        result.status = safe_status(ctrl);
        assign_outputs(command, result.metadata);

    case {"loop", "start-loop"}
        [command, metadata] = build_preview_command(spec, cfg);
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        result.metadata = ctrl.upload(command, metadata);
        ctrl.start("loop");
        result.status = safe_status(ctrl);
        assign_outputs(command, result.metadata);

    case {"finite", "start-finite"}
        [command, metadata] = build_preview_command(spec, cfg);
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        result.metadata = ctrl.upload(command, metadata);
        ctrl.start("finite", "RepeatCount", opts.RepeatCount);
        result.status = safe_status(ctrl);
        assign_outputs(command, result.metadata);

    case "stop"
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        ctrl.stop();
        result.status = safe_status(ctrl);

    case "estop"
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        ctrl.estop();
        result.status = safe_status(ctrl);

    case "reset"
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        ctrl.reset();
        result.status = safe_status(ctrl);

    case "status"
        ctrl = hddaudio.AudioReplayController(cfg);
        result.controller = ctrl;
        result.status = ctrl.readStatus();
        print_status(result.status);

    case "test"
        test_dir = fullfile(project_dir, "tests");
        addpath(test_dir);
        run_audio_tests();
        result.passed = true;

    otherwise
        error("run_hdd_audio:invalidAction", ...
            "Action must be panel, generate, upload, loop, finite, stop, estop, reset, status, or test.");
end

if nargout == 0
    clear result;
end
end

function opts = parse_options(varargin)
p = inputParser;
p.addParameter("Online", false, @(x)islogical(x) || isnumeric(x));
p.addParameter("Config", struct(), @(x)isstruct(x));
p.addParameter("Spec", hddaudio.defaultSpec(), @(x)isstruct(x));
p.addParameter("RepeatCount", 1, @is_positive_integer);
p.parse(varargin{:});

opts = p.Results;
opts.Online = logical(opts.Online);
opts.RepeatCount = double(opts.RepeatCount);
end

function cfg = make_config(opts)
if opts.Online
    cfg = hddaudio.defaultConfig();
else
    cfg = hddaudio.offlineConfig();
end

if ~isempty(fieldnames(opts.Config))
    cfg = hddaudio.mergeConfig(cfg, opts.Config);
end
end

function [command, metadata] = build_preview_command(spec, cfg)
[command, metadata] = hddaudio.buildCommand(spec, cfg);
metadata = hddaudio.writePreviewWav(command, metadata, cfg);
end

function assign_outputs(command, metadata)
assignin("base", "hddAudioCommand", command);
assignin("base", "hddAudioMetadata", metadata);
end

function status = safe_status(ctrl)
try
    status = ctrl.readStatus();
    print_status(status);
catch err
    status = struct("readError", string(err.message));
    fprintf("Status read failed: %s\n", err.message);
end
end

function print_status(status)
fprintf("Statusword=0x%04X, Controlword=0x%04X, State=%s (%d), idx=%d/%d, repeat=%d, cycle=%d, output=%d, error=%d\n", ...
    status.statusword, status.controlword, status.stateName, status.state, ...
    status.idx, status.tableLen, status.repeatCount, status.cycleCount, ...
    status.outputValue, status.errorCode);
end

function tf = is_positive_integer(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0 && floor(value) == value;
end
