function metadata = writePreviewWav(command, metadata, cfg)
%WRITEPREVIEWWAV Write the latest command table as an 8 kHz preview WAV.

if nargin < 2 || isempty(metadata)
    metadata = struct();
end
if nargin < 3 || isempty(cfg)
    cfg = hddaudio.defaultConfig();
else
    cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
end

command = hddaudio.normalizeCommand(command, cfg);
sample_rate_hz = preview_sample_rate(metadata, cfg);
preview_file = fullfile(char(cfg.soundDir), "hdd_audio_preview.wav");
preview_dir = fileparts(preview_file);
if ~isfolder(preview_dir)
    mkdir(preview_dir);
end

preview_audio = double(command(:)) ./ double(cfg.commandLimit);
preview_audio = min(max(preview_audio, -1), 1);
audiowrite(preview_file, preview_audio, sample_rate_hz);

metadata.previewWavFile = string(preview_file);
metadata.previewSampleRateHz = double(sample_rate_hz);
end

function sample_rate_hz = preview_sample_rate(metadata, cfg)
if isstruct(metadata) && isfield(metadata, "sampleRateHz") && ...
        isnumeric(metadata.sampleRateHz) && isscalar(metadata.sampleRateHz) && ...
        isfinite(metadata.sampleRateHz) && metadata.sampleRateHz > 0
    sample_rate_hz = round(double(metadata.sampleRateHz));
else
    sample_rate_hz = round(double(cfg.taskRateHz));
end
end
