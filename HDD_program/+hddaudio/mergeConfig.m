function cfg = mergeConfig(defaults, overrides)
%MERGECONFIG Merge a user config struct into defaults.

cfg = defaults;
if nargin < 2 || isempty(overrides)
    return;
end
if ~isstruct(overrides)
    error("hddaudio:invalidConfig", "Config must be a struct.");
end

names = fieldnames(overrides);
for idx = 1:numel(names)
    cfg.(names{idx}) = overrides.(names{idx});
end

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
