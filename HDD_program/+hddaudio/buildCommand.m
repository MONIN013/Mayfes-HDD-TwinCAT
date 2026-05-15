function [command, metadata] = buildCommand(spec, cfg, progressCallback)
%BUILDCOMMAND Build an int16 PLC command table from a replay spec.

if nargin < 1 || isempty(spec)
    spec = hddaudio.defaultSpec();
end
if nargin < 2 || isempty(cfg)
    cfg = hddaudio.defaultConfig();
else
    cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
end
if nargin < 3
    progressCallback = [];
end

if ~isstruct(spec) || ~isfield(spec, "items")
    error("hddaudio:invalidSpec", "Spec must be a struct with an items field.");
end

items = spec.items;
if isstruct(items)
    items = num2cell(items);
end
if ~iscell(items) || isempty(items)
    error("hddaudio:invalidSpec", "Spec items must be a non-empty cell array or struct array.");
end

segments = cell(numel(items), 1);
item_metadata = repmat(empty_item_metadata(), numel(items), 1);
source_files = strings(numel(items), 1);
source_count = 0;
notify_progress(progressCallback, 0.05, "Rebuild: preparing command table");

for idx = 1:numel(items)
    item = items{idx};
    if ~isstruct(item) || ~isfield(item, "type")
        error("hddaudio:invalidSpecItem", "Each spec item must be a struct with a type field.");
    end

    item_type = lower(strtrim(string(item.type)));
    switch item_type
        case "square"
            duration_seconds = item_value(item, "durationSeconds", 1.0);
            amplitude = item_value(item, "amplitude", cfg.commandLimit);
            period_seconds = item_value(item, "periodSeconds", 1.0);
            segment = build_square_command(cfg.taskRateHz, duration_seconds, amplitude, period_seconds);
            label = sprintf("square %.3fs", duration_seconds);
            source_file = "";
            source_format = "";
            source_sample_rate_hz = cfg.taskRateHz;
            was_resampled = false;
            resample_method = "none";
            motion_amplitude = 0;
            motion_frequency_hz = 0;
            motion_headroom_scale = 1;

        case {"wav", "audio"}
            file_name = string(item_value(item, "file", ""));
            if strlength(strtrim(file_name)) == 0
                error("hddaudio:invalidSpecItem", "Audio items must define a file field.");
            end

            file_path = resolve_audio_path(file_name, cfg.soundDir);
            [samples, source_sample_rate_hz, source_format] = read_mono_audio(file_path);
            [samples, was_resampled, resample_method] = match_sample_rate( ...
                samples, source_sample_rate_hz, cfg.taskRateHz);

            trim_tail_seconds = item_value(item, "trimTailSeconds", 0);
            if trim_tail_seconds > 0
                samples = trim_tail(samples, trim_tail_seconds * cfg.taskRateHz, file_name);
            end

            clip_level = item_value(item, "clip", cfg.defaultAudioClip);
            motion_amplitude = item_value(item, "motionAmplitude", 0);
            motion_frequency_hz = item_value(item, "motionFrequencyHz", cfg.defaultVisibleMotionFrequencyHz);
            use_amp = isfield(item, "amp") || ~isfield(item, "scale");
            if use_amp
                audio_amplitude = item_value(item, "amp", cfg.defaultAudioAmplitude);
                segment = scale_audio_to_amplitude(samples, clip_level, audio_amplitude);
                scale_motion_headroom = false;
            else
                torque_scale = item_value(item, "scale", cfg.defaultTorqueScale);
                segment = scale_audio(samples, clip_level, torque_scale);
                scale_motion_headroom = true;
            end
            [segment, motion_headroom_scale, motion_frequency_hz] = add_visible_motion( ...
                segment, cfg.taskRateHz, motion_amplitude, motion_frequency_hz, cfg.commandLimit, scale_motion_headroom);
            label = char(file_name);
            source_file = file_name;
            source_count = source_count + 1;
            source_files(source_count, 1) = file_name;

        otherwise
            error("hddaudio:unsupportedSpecItem", "Unsupported spec item type: %s.", item_type);
    end

    segment = clamp(segment, -cfg.commandLimit, cfg.commandLimit);
    segments{idx} = segment(:);
    item_metadata(idx, 1) = struct( ...
        "type", item_type, ...
        "label", string(label), ...
        "sourceFile", string(source_file), ...
        "sourceFormat", string(source_format), ...
        "sourceSampleRateHz", double(source_sample_rate_hz), ...
        "wasResampled", logical(was_resampled), ...
        "resampleMethod", string(resample_method), ...
        "numSamples", numel(segment), ...
        "durationSeconds", double(numel(segment)) / double(cfg.taskRateHz), ...
        "motionAmplitude", double(motion_amplitude), ...
        "motionFrequencyHz", double(motion_frequency_hz), ...
        "motionHeadroomScale", double(motion_headroom_scale), ...
        "minCommand", double(min(segment)), ...
        "maxCommand", double(max(segment)));
    notify_progress(progressCallback, 0.05 + 0.85 * idx / numel(items), ...
        sprintf("Rebuild: item %d / %d", idx, numel(items)));
end

raw_command = vertcat(segments{:});
notify_progress(progressCallback, 0.94, "Rebuild: normalizing command");
command = hddaudio.normalizeCommand(raw_command, cfg);
source_files = source_files(1:source_count, 1);

metadata = struct( ...
    "specName", string(item_value(spec, "name", "unnamed")), ...
    "taskRateHz", cfg.taskRateHz, ...
    "sampleRateHz", cfg.taskRateHz, ...
    "tableMaxN", cfg.tableMaxN, ...
    "commandLimit", cfg.commandLimit, ...
    "numSamples", numel(command), ...
    "durationSeconds", double(numel(command)) / double(cfg.taskRateHz), ...
    "minCommand", double(min(command)), ...
    "maxCommand", double(max(command)), ...
    "sourceFiles", source_files, ...
    "items", item_metadata);
notify_progress(progressCallback, 1.00, "Rebuild complete");
end

function meta = empty_item_metadata()
meta = struct( ...
    "type", string.empty(0, 1), ...
    "label", string.empty(0, 1), ...
    "sourceFile", string.empty(0, 1), ...
    "sourceFormat", string.empty(0, 1), ...
    "sourceSampleRateHz", [], ...
    "wasResampled", [], ...
    "resampleMethod", string.empty(0, 1), ...
    "numSamples", [], ...
    "durationSeconds", [], ...
    "motionAmplitude", [], ...
    "motionFrequencyHz", [], ...
    "motionHeadroomScale", [], ...
    "minCommand", [], ...
    "maxCommand", []);
end

function value = item_value(item, field_name, default_value)
if isfield(item, field_name)
    value = item.(field_name);
else
    value = default_value;
end
end

function [mono, fs, source_format] = read_mono_audio(file_path)
if ~isfile(file_path)
    error("hddaudio:fileNotFound", "Audio file not found: %s", file_path);
end

[y, fs] = audioread(file_path);
if isempty(y)
    error("hddaudio:emptyAudio", "Audio file is empty: %s", file_path);
end

[~, ~, ext] = fileparts(file_path);
source_format = upper(erase(string(ext), "."));
if strlength(source_format) == 0
    source_format = "unknown";
end

mono = mean(double(y), 2);
end

function [out, was_resampled, resample_method] = match_sample_rate(samples, actual_rate, target_rate)
actual_rate = double(actual_rate);
target_rate = double(target_rate);
if actual_rate <= 0 || target_rate <= 0
    error("hddaudio:invalidSampleRate", "Audio sample rates must be positive.");
end

was_resampled = actual_rate ~= target_rate;
if ~was_resampled
    out = samples(:);
    resample_method = "none";
    return;
end

out = resample_polyphase(samples(:), actual_rate, target_rate);
resample_method = "polyphase";
end

function out = resample_polyphase(samples, actual_rate, target_rate)
target_count = max(1, round(numel(samples) * target_rate / actual_rate));
if numel(samples) == 1
    out = repmat(double(samples(1)), target_count, 1);
    return;
end

[p, q] = rat(target_rate / actual_rate, 1e-12);
out = resample(double(samples(:)), p, q);
out = force_sample_count(out, target_count);
end

function out = force_sample_count(samples, target_count)
samples = double(samples(:));
if numel(samples) > target_count
    out = samples(1:target_count);
elseif numel(samples) < target_count
    out = [samples; repmat(samples(end), target_count - numel(samples), 1)];
else
    out = samples;
end
end

function out = scale_audio(samples, clip_level, torque_scale)
validate_clip_level(clip_level);
samples = clamp(double(samples(:)), -clip_level, clip_level);
out = samples * double(torque_scale);
end

function out = scale_audio_to_amplitude(samples, clip_level, target_amplitude)
validate_clip_level(clip_level);
if ~isnumeric(target_amplitude) || ~isscalar(target_amplitude) || ...
        ~isfinite(target_amplitude) || target_amplitude < 0
    error("hddaudio:invalidSpecItem", "amp must be a finite non-negative scalar.");
end

samples = clamp(double(samples(:)), -clip_level, clip_level);
peak = max(abs(samples));
if peak == 0 || target_amplitude == 0
    out = zeros(size(samples));
else
    out = samples .* (double(target_amplitude) ./ peak);
end
end

function validate_clip_level(clip_level)
if ~isnumeric(clip_level) || ~isscalar(clip_level) || ~isfinite(clip_level) || clip_level <= 0
    error("hddaudio:invalidSpecItem", "clip must be a finite positive scalar.");
end
end

function [out, headroom_scale, frequency_hz] = add_visible_motion(segment, sample_rate_hz, amplitude, frequency_hz, command_limit, scale_headroom)
if nargin < 6
    scale_headroom = true;
end
if ~isnumeric(amplitude) || ~isscalar(amplitude)
    error("hddaudio:invalidSpecItem", "motionAmplitude must be a finite non-negative scalar.");
end
amplitude = double(amplitude);
command_limit = double(command_limit);
headroom_scale = 1;

if ~isfinite(amplitude) || amplitude < 0
    error("hddaudio:invalidSpecItem", "motionAmplitude must be a finite non-negative scalar.");
end
if amplitude == 0
    out = double(segment(:));
    frequency_hz = 0;
    return;
end
if amplitude > command_limit
    error("hddaudio:invalidSpecItem", "motionAmplitude must be less than or equal to commandLimit.");
end
if ~isnumeric(frequency_hz) || ~isscalar(frequency_hz)
    error("hddaudio:invalidSpecItem", "motionFrequencyHz must be positive when motionAmplitude is non-zero.");
end
frequency_hz = double(frequency_hz);
if ~isfinite(frequency_hz) || frequency_hz <= 0
    error("hddaudio:invalidSpecItem", "motionFrequencyHz must be positive when motionAmplitude is non-zero.");
end

segment = double(segment(:));
available_audio = max(command_limit - amplitude, 0);
peak_audio = max(abs(segment));
if scale_headroom && peak_audio > available_audio && peak_audio > 0
    headroom_scale = available_audio / peak_audio;
    segment = segment * headroom_scale;
end

t = (0:numel(segment) - 1)' ./ double(sample_rate_hz);
motion = amplitude * sin(2 * pi * frequency_hz * t);
out = segment + motion;
end

function out = trim_tail(samples, trim_count, label)
trim_count = round(double(trim_count));
if trim_count >= numel(samples)
    error("hddaudio:trimTooLong", ...
        "Trim length (%d samples) is not shorter than %s (%d samples).", ...
        trim_count, label, numel(samples));
end
out = samples(1:end - trim_count);
end

function out = build_square_command(sample_rate_hz, duration_seconds, amplitude, period_seconds)
if duration_seconds <= 0 || period_seconds <= 0
    error("hddaudio:invalidSpecItem", "Square durationSeconds and periodSeconds must be positive.");
end

num_samples = round(duration_seconds * sample_rate_hz) + 1;
t = (0:num_samples - 1)' / sample_rate_hz;
out = double(amplitude) * ones(num_samples, 1);
out(mod(t, period_seconds) >= (period_seconds / 2)) = -double(amplitude);
end

function file_path = resolve_audio_path(file_name, sound_dir)
if is_absolute_path(file_name)
    file_path = char(file_name);
else
    file_path = char(fullfile(sound_dir, file_name));
end
end

function tf = is_absolute_path(path_value)
path_value = string(path_value);
path_text = char(path_value);
tf = startsWith(path_value, filesep) || startsWith(path_value, "\\") || ...
    ~isempty(regexp(path_text, "^[A-Za-z]:[\\/]", "once"));
end

function out = clamp(values, min_value, max_value)
out = min(max(values, min_value), max_value);
end

function notify_progress(callback, fraction, message)
if isempty(callback)
    return;
end
callback(min(max(double(fraction), 0), 1), string(message));
end
