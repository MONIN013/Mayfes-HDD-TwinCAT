function cfg = defaultConfig(varargin)
%DEFAULTCONFIG Default settings for HDD audio replay and Disk_B control.

project_dir = fileparts(fileparts(mfilename("fullpath")));

p = inputParser;
p.addParameter("amsNetId", "192.168.10.3.1.1", @(x)ischar(x) || isstring(x));
p.addParameter("plcPort", 851, @is_positive_integer);
p.addParameter("taskRateHz", 8000, @is_positive_integer);
p.addParameter("tableMaxN", 500000, @is_positive_integer);
p.addParameter("commandLimit", 16000, @is_positive_integer);
p.addParameter("resetPulseSeconds", 0.02, @(x)isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
p.addParameter("soundDir", fullfile(project_dir, "Sound"), @(x)ischar(x) || isstring(x));
p.addParameter("adsAssembly", "", @(x)ischar(x) || isstring(x));
p.addParameter("namespace", "Audio_A", @(x)ischar(x) || isstring(x));
p.addParameter("audioDriveGains", [1.00 0.90 0.80], @is_numeric_vector);
p.addParameter("audioDriveDelaySamples", [0 8 16], @is_numeric_vector);
p.addParameter("audioDrivePolarities", [1 1 1], @is_numeric_vector);
p.addParameter("defaultAudioClip", 1.0, @is_positive_scalar);
p.addParameter("defaultAudioAmplitude", 3500, @is_nonnegative_scalar);
p.addParameter("defaultTorqueScale", 3 * 40000, @is_positive_scalar);
p.addParameter("defaultVisibleMotionAmplitude", 1000, @is_nonnegative_scalar);
p.addParameter("defaultVisibleMotionFrequencyHz", 2.0, @is_positive_scalar);
p.addParameter("diskNamespace", "Disk_B", @(x)ischar(x) || isstring(x));
p.addParameter("diskRestartTimeoutSeconds", 2.0, @is_positive_scalar);
p.addParameter("diskRestartPollSeconds", 0.02, @is_positive_scalar);
p.addParameter("diskRestartZeroThreshold", 0.05, @(x)isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
p.addParameter("diskDefaultTorqueTarget", 3000, @is_finite_scalar);
p.addParameter("diskDefaultTorqueRampStep", 5, @is_positive_scalar);
p.addParameter("diskDefaultAngleIncTarget", 10.0, @is_finite_scalar);
p.addParameter("diskDefaultAngleIncRampStep", 0.02, @is_positive_scalar);
p.addParameter("transport", [], @(x)true);
p.parse(varargin{:});

cfg = p.Results;
cfg.amsNetId = string(cfg.amsNetId);
cfg.plcPort = double(cfg.plcPort);
cfg.taskRateHz = double(cfg.taskRateHz);
cfg.tableMaxN = double(cfg.tableMaxN);
cfg.commandLimit = double(cfg.commandLimit);
cfg.resetPulseSeconds = double(cfg.resetPulseSeconds);
cfg.soundDir = string(cfg.soundDir);
cfg.adsAssembly = string(cfg.adsAssembly);
cfg.namespace = string(cfg.namespace);
cfg.audioDriveGains = double(cfg.audioDriveGains(:)).';
cfg.audioDriveDelaySamples = double(cfg.audioDriveDelaySamples(:)).';
cfg.audioDrivePolarities = double(cfg.audioDrivePolarities(:)).';
cfg.defaultAudioClip = double(cfg.defaultAudioClip);
cfg.defaultAudioAmplitude = double(cfg.defaultAudioAmplitude);
cfg.defaultTorqueScale = double(cfg.defaultTorqueScale);
cfg.defaultVisibleMotionAmplitude = double(cfg.defaultVisibleMotionAmplitude);
cfg.defaultVisibleMotionFrequencyHz = double(cfg.defaultVisibleMotionFrequencyHz);
cfg.diskNamespace = string(cfg.diskNamespace);
cfg.diskRestartTimeoutSeconds = double(cfg.diskRestartTimeoutSeconds);
cfg.diskRestartPollSeconds = double(cfg.diskRestartPollSeconds);
cfg.diskRestartZeroThreshold = double(cfg.diskRestartZeroThreshold);
cfg.diskDefaultTorqueTarget = double(cfg.diskDefaultTorqueTarget);
cfg.diskDefaultTorqueRampStep = double(cfg.diskDefaultTorqueRampStep);
cfg.diskDefaultAngleIncTarget = double(cfg.diskDefaultAngleIncTarget);
cfg.diskDefaultAngleIncRampStep = double(cfg.diskDefaultAngleIncRampStep);
end

function tf = is_positive_integer(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0 && floor(value) == value;
end

function tf = is_positive_scalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end

function tf = is_nonnegative_scalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value >= 0;
end

function tf = is_finite_scalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value);
end

function tf = is_numeric_vector(value)
tf = isnumeric(value) && isvector(value) && ~isempty(value) && all(isfinite(value(:)));
end
