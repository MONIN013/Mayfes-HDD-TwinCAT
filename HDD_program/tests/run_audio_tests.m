function run_audio_tests()
%RUN_AUDIO_TESTS Offline checks for the packaged audio replay API.

test_dir = fileparts(mfilename("fullpath"));
project_dir = fileparts(test_dir);
addpath(project_dir);

cfg = hddaudio.defaultConfig("resetPulseSeconds", 0);
spec = hddaudio.defaultSpec();
[command, metadata] = hddaudio.buildCommand(spec, cfg);

assert(isa(command, "int16"), "buildCommand must return int16 commands.");
assert(metadata.sampleRateHz == 8000, "Sample rate must match the 8 kHz PLC task.");
assert(numel(command) <= 500000, "Command table exceeds PLC table capacity.");
assert(all(double(command) <= cfg.commandLimit), "Command exceeds positive clamp.");
assert(all(double(command) >= -cfg.commandLimit), "Command exceeds negative clamp.");
assert(numel(metadata.items) == 4, "Default spec must contain four replay items.");
assert(isfield(metadata.items, "sourceSampleRateHz"), "Metadata must include source sample rates.");
assert(isfield(metadata.items, "sourceFormat"), "Metadata must include source formats.");
assert(isfield(metadata.items, "wasResampled"), "Metadata must include resample flags.");
assert(isfield(metadata.items, "resampleMethod"), "Metadata must include resample methods.");
assert(isfield(metadata.items, "motionAmplitude"), "Metadata must include visible motion amplitude.");
assert(isfield(metadata.items, "motionFrequencyHz"), "Metadata must include visible motion frequency.");
assert(metadata.items(2).motionAmplitude == cfg.defaultVisibleMotionAmplitude, "Default WAV item must include visible motion.");
assert(metadata.items(2).motionFrequencyHz == 2.0, "Default WAV item motion frequency must be 2 Hz.");
assert(metadata.items(2).motionHeadroomScale <= 1, "Visible motion must not increase audio headroom.");
assert(metadata.items(2).sourceFormat == "WAV", "Default WAV metadata must include its source format.");

mock = hddaudio.MockAdsTransport();
cfg.transport = mock;
ctrl = hddaudio.AudioReplayController(cfg);

upload_metadata = ctrl.upload(command, metadata);
assert(~upload_metadata.started, "Upload must not start playback.");

symbols = string({mock.Writes.symbol});
net_types = string({mock.Writes.netType});
assert(any(symbols == "Audio_A.commandTable"), "commandTable was not written.");
assert(any(symbols == "Audio_A.tableLen"), "tableLen was not written.");
assert(nnz(symbols == "Audio_A.resetReq") == 2, "resetReq must be pulsed TRUE then FALSE.");
assert(any(net_types == "System.Int16"), "INT table write must use System.Int16.");

mock.clear();
ctrl.start("loop");
assert(numel(mock.Writes) == 2, "Loop start must write repeatCount and runReq.");
assert(mock.Writes(1).symbol == "Audio_A.repeatCount", "Loop start must write repeatCount first.");
assert(isequal(mock.Writes(1).value, uint32(0)), "Loop start must use repeatCount=0.");
assert(mock.Writes(2).symbol == "Audio_A.runReq", "Loop start must write runReq second.");
assert(isequal(mock.Writes(2).value, true), "Loop start must set runReq=true.");

mock.clear();
ctrl.start("finite", "RepeatCount", 3);
assert(mock.Writes(1).symbol == "Audio_A.repeatCount", "Finite start must write repeatCount first.");
assert(isequal(mock.Writes(1).value, uint32(3)), "Finite start must write the requested repeat count.");
assert(mock.Writes(2).symbol == "Audio_A.runReq", "Finite start must write runReq second.");
assert(isequal(mock.Writes(2).value, true), "Finite start must set runReq=true.");

mock.clear();
ctrl.estop();
assert(mock.Writes(1).symbol == "Audio_A.estopReq", "estop must write estopReq first.");
assert(isequal(mock.Writes(1).value, true), "estop must set estopReq=true.");
assert(mock.Writes(2).symbol == "Audio_A.runReq", "estop must write runReq second.");
assert(isequal(mock.Writes(2).value, false), "estop must set runReq=false.");

mock.clear();
ctrl.reset();
reset_symbols = string({mock.Writes.symbol});
reset_values = {mock.Writes.value};
assert(isequal(reset_symbols, ["Audio_A.runReq", "Audio_A.estopReq", "Audio_A.resetReq", "Audio_A.resetReq"]), ...
    "reset must write runReq, estopReq, and a resetReq pulse.");
assert(isequal(reset_values{1}, false), "reset must set runReq=false.");
assert(isequal(reset_values{2}, false), "reset must clear estopReq.");
assert(isequal(reset_values{3}, true), "reset must pulse resetReq=true.");
assert(isequal(reset_values{4}, false), "reset must pulse resetReq=false.");

mock.setRead("Audio_A.state", uint16(1));
mock.setRead("Audio_A.Statusword", uint16(hex2dec('0027')));
mock.setRead("Audio_A.Controlword", uint16(hex2dec('000F')));
mock.setRead("Audio_A.idx", uint32(120));
mock.setRead("Audio_A.tableLen", uint32(1000));
mock.setRead("Audio_A.repeatCount", uint32(0));
mock.setRead("Audio_A.cycleCount", uint32(4));
mock.setRead("Audio_A.playbackDone", false);
mock.setRead("Audio_A.errorCode", uint32(0));
mock.setRead("Audio_A.outputValue", int16(321));
status = ctrl.readStatus();

assert(status.statusword == hex2dec('0027'), "readStatus must read Audio_A Statusword.");
assert(status.controlword == hex2dec('000F'), "readStatus must read Audio_A Controlword.");
assert(status.state == 1, "readStatus must read state.");
assert(status.stateName == "PLAYING", "readStatus must expose a readable state name.");
assert(status.idx == 120, "readStatus must read idx.");
assert(status.tableLen == 1000, "readStatus must read tableLen.");
assert(status.repeatCount == 0, "readStatus must read repeatCount.");
assert(status.cycleCount == 4, "readStatus must read cycleCount.");
assert(~status.playbackDone, "readStatus must read playbackDone.");
assert(status.errorCode == 0, "readStatus must read errorCode.");
assert(status.outputValue == 321, "readStatus must read outputValue.");

offline_cfg = hddaudio.offlineConfig();
offline_ctrl = hddaudio.AudioReplayController(offline_cfg);
offline_ctrl.upload(command, metadata);
offline_ctrl.start("loop");
offline_status = offline_ctrl.readStatus();
assert(offline_status.stateName == "PLAYING", "offline mock must mirror loop start as PLAYING.");
assert(offline_status.tableLen == numel(command), "offline mock must mirror uploaded tableLen.");

offline_ctrl.estop();
offline_status = offline_ctrl.readStatus();
assert(offline_status.stateName == "ESTOP", "offline mock must mirror estop as ESTOP.");
assert(offline_status.outputValue == 0, "offline mock estop must force outputValue=0.");

offline_ctrl.reset();
offline_status = offline_ctrl.readStatus();
assert(offline_status.stateName == "IDLE", "offline mock must mirror reset as IDLE.");

playlist_spec = struct();
playlist_spec.name = "playlist";
playlist_spec.items = {
    struct("type", "wav", "file", "tetris.wav", "clip", 0.1, "scale", 10000, "trimTailSeconds", 0), ...
    struct("type", "wav", "file", "menuetto-3.wav", "clip", 0.1, "scale", 12000, "trimTailSeconds", 0.25)};
[playlist_command, playlist_metadata] = hddaudio.buildCommand(playlist_spec, cfg);
assert(numel(playlist_metadata.items) == 2, "Playlist spec must contain two items.");

spec_file = [tempname, '.mat'];
hddaudio.saveSpec(spec_file, playlist_spec);
loaded_spec = hddaudio.loadSpec(spec_file);
[loaded_command, loaded_metadata] = hddaudio.buildCommand(loaded_spec, cfg);
assert(isequal(playlist_command, loaded_command), "Saved and loaded specs must build identical commands.");
assert(loaded_metadata.numSamples == playlist_metadata.numSamples, ...
    "Saved and loaded specs must preserve metadata sample count.");
delete(spec_file);

tmp_dir = tempname;
mkdir(tmp_dir);
tmp_cleanup = onCleanup(@()safe_rmdir(tmp_dir));
resample_file = fullfile(tmp_dir, "four_k.wav");
source_rate_hz = 4000;
target_rate_hz = 8000;
t = (0:source_rate_hz - 1)' ./ source_rate_hz;
audiowrite(resample_file, 0.05 * sin(2 * pi * 220 * t), source_rate_hz);
resample_cfg = hddaudio.defaultConfig( ...
    "resetPulseSeconds", 0, ...
    "soundDir", tmp_dir, ...
    "taskRateHz", target_rate_hz);
resample_spec = struct();
resample_spec.name = "resample";
resample_spec.items = {struct("type", "wav", "file", "four_k.wav", "clip", 0.1, "scale", 10000, "trimTailSeconds", 0)};
[resampled_command, resampled_metadata] = hddaudio.buildCommand(resample_spec, resample_cfg);
assert(numel(resampled_command) == target_rate_hz, "Resampled command length must match target rate.");
assert(resampled_metadata.items(1).sourceSampleRateHz == source_rate_hz, ...
    "Metadata must keep the original WAV sample rate.");
assert(resampled_metadata.items(1).wasResampled, "Metadata must flag resampled WAV items.");
assert(resampled_metadata.items(1).resampleMethod == "polyphase", "Resampled items must report polyphase resampling.");
assert(resampled_metadata.items(1).motionAmplitude == 0, "WAV items without visible motion must keep motion disabled.");

wav441_file = fullfile(tmp_dir, "forty_four_k.wav");
source_rate_hz = 44100;
t = (0:source_rate_hz - 1)' ./ source_rate_hz;
audiowrite(wav441_file, 0.05 * [sin(2 * pi * 220 * t), sin(2 * pi * 330 * t)], source_rate_hz);
wav441_spec = struct();
wav441_spec.name = "wav441";
wav441_spec.items = {struct("type", "audio", "file", "forty_four_k.wav", "clip", 0.1, "scale", 10000, "trimTailSeconds", 0)};
[wav441_command, wav441_metadata] = hddaudio.buildCommand(wav441_spec, resample_cfg);
assert(numel(wav441_command) == target_rate_hz, "44.1 kHz audio must resample to one second at 8 kHz.");
assert(wav441_metadata.items(1).sourceSampleRateHz == source_rate_hz, ...
    "44.1 kHz metadata must keep the original sample rate.");
assert(wav441_metadata.items(1).sourceFormat == "WAV", "44.1 kHz metadata must keep source format.");

mp3_file = fullfile(tmp_dir, "tone.mp3");
source_rate_hz = 44100;
t = (0:source_rate_hz - 1)' ./ source_rate_hz;
audiowrite(mp3_file, 0.05 * sin(2 * pi * 440 * t), source_rate_hz);
mp3_spec = struct();
mp3_spec.name = "mp3";
mp3_spec.items = {struct("type", "audio", "file", "tone.mp3", "clip", 0.1, "scale", 10000, "trimTailSeconds", 0)};
[mp3_command, mp3_metadata] = hddaudio.buildCommand(mp3_spec, resample_cfg);
assert(isa(mp3_command, "int16"), "MP3 builds must return int16 commands.");
assert(mp3_metadata.sampleRateHz == target_rate_hz, "MP3 builds must target the PLC sample rate.");
assert(mp3_metadata.items(1).sourceSampleRateHz == source_rate_hz, "MP3 metadata must keep the original sample rate.");
assert(mp3_metadata.items(1).sourceFormat == "MP3", "MP3 metadata must keep source format.");
assert(mp3_metadata.items(1).wasResampled, "MP3 items must report resampling when source rate differs.");

flac_file = fullfile(tmp_dir, "forty_eight_k.flac");
source_rate_hz = 48000;
t = (0:source_rate_hz - 1)' ./ source_rate_hz;
audiowrite(flac_file, 0.05 * sin(2 * pi * 330 * t), source_rate_hz);
flac_spec = struct();
flac_spec.name = "flac";
flac_spec.items = {struct("type", "audio", "file", "forty_eight_k.flac", "clip", 0.1, "scale", 10000, "trimTailSeconds", 0)};
[flac_command, flac_metadata] = hddaudio.buildCommand(flac_spec, resample_cfg);
assert(numel(flac_command) == target_rate_hz, "48 kHz FLAC must resample to one second at 8 kHz.");
assert(flac_metadata.items(1).sourceFormat == "FLAC", "FLAC metadata must keep source format.");
assert(flac_metadata.items(1).resampleMethod == "polyphase", "FLAC resampling must report polyphase.");

preview_metadata = hddaudio.writePreviewWav(flac_command, flac_metadata, resample_cfg);
assert(isfield(preview_metadata, "previewWavFile"), "Preview metadata must include the WAV file path.");
assert(isfile(preview_metadata.previewWavFile), "Preview WAV must be written.");
preview_info = audioinfo(preview_metadata.previewWavFile);
assert(preview_info.SampleRate == target_rate_hz, "Preview WAV must use the PLC sample rate.");
assert(preview_info.NumChannels == 1, "Preview WAV must be mono.");
[preview_audio, preview_rate_hz] = audioread(preview_metadata.previewWavFile);
assert(preview_rate_hz == target_rate_hz, "Preview WAV must be readable at the PLC sample rate.");
assert(size(preview_audio, 2) == 1, "Preview samples must be one channel.");
assert(~isempty(preview_audio), "Preview WAV must contain samples.");
assert(all(abs(preview_audio) <= 1), "Preview WAV samples must be in audio range.");

net_array = NET.convertArray(int16(1:5), "System.Int16");
assert(net_array.Length == 5, "NET.convertArray must produce a .NET Int16 array.");

motion_spec = struct();
motion_spec.name = "motion";
motion_spec.items = {struct("type", "wav", "file", "four_k.wav", "clip", 0.1, "scale", 10000, ...
    "trimTailSeconds", 0, "motionAmplitude", 2000, "motionFrequencyHz", 2.0)};
[motion_command, motion_metadata] = hddaudio.buildCommand(motion_spec, resample_cfg);
assert(numel(motion_command) == target_rate_hz, "Visible motion must preserve command length.");
assert(motion_metadata.items(1).motionAmplitude == 2000, "Visible motion metadata must keep amplitude.");
assert(motion_metadata.items(1).motionFrequencyHz == 2.0, "Visible motion metadata must keep frequency.");
assert(max(abs(double(motion_command))) > max(abs(double(resampled_command))), ...
    "Visible motion must add a low-frequency command component.");
assert(all(abs(double(motion_command)) <= resample_cfg.commandLimit), ...
    "Visible motion command must remain inside commandLimit.");

disk_mock = hddaudio.MockAdsTransport();
disk_cfg = hddaudio.defaultConfig("resetPulseSeconds", 0, "diskRestartTimeoutSeconds", 0.1);
disk_cfg.transport = disk_mock;
disk_ctrl = hddaudio.DiskBController(disk_cfg);
disk_settings = struct( ...
    "TorqueTarget", 3100, ...
    "TorqueRampStep", 7, ...
    "AngleIncTarget", 12.5, ...
    "AngleIncRampStep", 0.05);

disk_ctrl.applySettings(disk_settings);
disk_symbols = string({disk_mock.Writes.symbol});
disk_values = {disk_mock.Writes.value};
assert(isequal(disk_symbols, ...
    ["Disk_B.TorqueTarget", "Disk_B.TorqueRampStep", "Disk_B.AngleIncTarget", "Disk_B.AngleIncRampStep"]), ...
    "Disk_B settings must write the expected symbols.");
assert(isequal(disk_values{1}, int16(3100)), "TorqueTarget must be written as INT.");
assert(isequal(disk_values{2}, int16(7)), "TorqueRampStep must be written as INT.");
assert(isequal(disk_values{3}, 12.5), "AngleIncTarget must be written as LREAL/System.Double.");
assert(isequal(disk_values{4}, 0.05), "AngleIncRampStep must be written as LREAL/System.Double.");

disk_mock.clear();
disk_ctrl.start();
assert(disk_mock.Writes(1).symbol == "Disk_B.RunCmd", "Disk start must write RunCmd.");
assert(isequal(disk_mock.Writes(1).value, true), "Disk start must set RunCmd=true.");

disk_mock.clear();
disk_mock.setRead("Disk_B.AngleIncActual", 1.0);
disk_ctrl.stop();
assert(disk_mock.Writes(1).symbol == "Disk_B.RunCmd", "Disk stop must write RunCmd.");
assert(isequal(disk_mock.Writes(1).value, false), "Disk stop must set RunCmd=false.");
types = hddaudio.netTypes();
assert(isequal(disk_mock.readScalar("Disk_B.TorqueDemand", types.i16), int16(0)), ...
    "Disk stop must drop TorqueDemand to zero in the offline mock.");
assert(isequal(disk_mock.readScalar("Disk_B.TargetTorque", types.i16), int16(0)), ...
    "Disk stop must drop TargetTorque to zero in the offline mock.");

disk_mock.clear();
disk_mock.setRead("Disk_B.AngleIncActual", 0.0);
disk_ctrl.safeRestart(disk_settings);
restart_symbols = string({disk_mock.Writes.symbol});
restart_values = {disk_mock.Writes.value};
assert(isequal(restart_symbols, ...
    ["Disk_B.RunCmd", "Disk_B.Angle", "Disk_B.AngleIncActual", "Disk_B.TorqueCmd", ...
     "Disk_B.TorqueTarget", "Disk_B.TorqueRampStep", "Disk_B.AngleIncTarget", ...
     "Disk_B.AngleIncRampStep", "Disk_B.RunCmd"]), ...
    "Disk safe restart must stop, reset motion internals, apply settings, then start.");
assert(isequal(restart_values{1}, false), "Safe restart must stop first.");
assert(isequal(restart_values{end}, true), "Safe restart must start last.");

disk_mock.setRead("Disk_B.Statusword", uint16(hex2dec('0027')));
disk_mock.setRead("Disk_B.Controlword", uint16(hex2dec('000F')));
disk_mock.setRead("Disk_B.swMasked", uint16(hex2dec('0027')));
disk_mock.setRead("Disk_B.RunCmd", true);
disk_mock.setRead("Disk_B.TargetTorque", int16(123));
disk_mock.setRead("Disk_B.TorqueActual", int16(456));
disk_mock.setRead("Disk_B.TorqueCmd", int16(789));
disk_mock.setRead("Disk_B.TorqueTarget", int16(3100));
disk_mock.setRead("Disk_B.TorqueRampStep", int16(7));
disk_mock.setRead("Disk_B.TorqueDemand", int16(3100));
disk_mock.setRead("Disk_B.CommutationAngle", uint16(1000));
disk_mock.setRead("Disk_B.Angle", 10.0);
disk_mock.setRead("Disk_B.AngleIncTarget", 12.5);
disk_mock.setRead("Disk_B.AngleIncActual", 11.5);
disk_mock.setRead("Disk_B.AngleIncRampStep", 0.05);
disk_mock.setRead("Disk_B.AngleIncDemand", 12.5);
disk_status = disk_ctrl.readStatus();
assert(disk_status.statusName == "OPERATION_ENABLED", "Disk status must decode operation enabled.");
assert(disk_status.torqueActual == 456, "Disk status must read TorqueActual.");
assert(disk_status.angleIncActual == 11.5, "Disk status must read AngleIncActual.");

fprintf("audio tests passed: %d samples, %.3f s.\n", ...
    metadata.numSamples, metadata.durationSeconds);
end

function safe_rmdir(pathName)
if isfolder(pathName)
    try
        rmdir(pathName, "s");
    catch
    end
end
end
