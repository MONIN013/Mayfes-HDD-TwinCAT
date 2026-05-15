function [driveCommands, driveConfig] = expandDriveCommands(command, cfg)
%EXPANDDRIVECOMMANDS Apply per-drive gain, delay, and polarity to a command.

if nargin < 2 || isempty(cfg)
    cfg = hddaudio.defaultConfig();
else
    cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
end

command = hddaudio.normalizeCommand(command, cfg);
gains = double(cfg.audioDriveGains(:)).';
delays = double(cfg.audioDriveDelaySamples(:)).';
polarities = double(cfg.audioDrivePolarities(:)).';

drive_count = numel(gains);
if drive_count < 1 || drive_count > 3
    error("hddaudio:invalidAudioDriveConfig", ...
        "audioDriveGains must define between 1 and 3 drives.");
end

delays = match_drive_vector(delays, drive_count, "audioDriveDelaySamples");
polarities = match_drive_vector(polarities, drive_count, "audioDrivePolarities");
if any(~isfinite(gains)) || any(gains < 0)
    error("hddaudio:invalidAudioDriveConfig", ...
        "audioDriveGains must be finite non-negative values.");
end
if any(~isfinite(delays)) || any(delays < 0) || any(floor(delays) ~= delays)
    error("hddaudio:invalidAudioDriveConfig", ...
        "audioDriveDelaySamples must be finite non-negative integers.");
end
if any(~ismember(polarities, [-1 1]))
    error("hddaudio:invalidAudioDriveConfig", ...
        "audioDrivePolarities must contain only -1 or 1.");
end

base = double(command(:));
driveCommands = zeros(numel(base), drive_count, "int16");
for drive_idx = 1:drive_count
    delayed = delay_command(base, delays(drive_idx));
    scaled = delayed .* gains(drive_idx) .* polarities(drive_idx);
    scaled = round(min(max(scaled, -double(cfg.commandLimit)), double(cfg.commandLimit)));
    driveCommands(:, drive_idx) = int16(scaled);
end

driveConfig = struct( ...
    "driveCount", double(drive_count), ...
    "audioDriveGains", gains, ...
    "audioDriveDelaySamples", delays, ...
    "audioDrivePolarities", polarities);
end

function out = delay_command(values, delay_samples)
delay_samples = double(delay_samples);
if delay_samples == 0
    out = values(:);
    return;
end

out = zeros(size(values(:)));
if delay_samples < numel(values)
    out(delay_samples + 1:end) = values(1:end - delay_samples);
end
end

function values = match_drive_vector(values, drive_count, field_name)
values = double(values(:)).';
if numel(values) == drive_count
    return;
end
if numel(values) == 1
    values = repmat(values, 1, drive_count);
    return;
end
if drive_count == 1
    values = values(1);
    return;
end

error("hddaudio:invalidAudioDriveConfig", ...
    "%s must be scalar or match the audioDriveGains length.", field_name);
end
