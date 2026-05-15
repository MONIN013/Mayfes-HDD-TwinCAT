function cfg = offlineConfig(varargin)
%OFFLINECONFIG Config for dry-run work on a PC without a drive connection.

cfg = hddaudio.defaultConfig("resetPulseSeconds", 0, varargin{:});
cfg.transport = hddaudio.MockAdsTransport();
end
