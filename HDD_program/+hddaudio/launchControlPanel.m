function app = launchControlPanel(cfg)
%LAUNCHCONTROLPANEL Open the HDD Audio and Disk_B control UI.
%
%   hddaudio.launchControlPanel("offline") uses MockAdsTransport and does
%   not attempt ADS communication.

if nargin < 1 || isempty(cfg)
    cfg = hddaudio.defaultConfig();
elseif ischar(cfg) || isstring(cfg)
    mode = lower(strtrim(string(cfg)));
    if mode == "offline"
        cfg = hddaudio.offlineConfig();
    else
        error("hddaudio:invalidControlPanelMode", "Control panel mode must be offline.");
    end
else
    cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
end

audioCtrl = hddaudio.AudioReplayController(cfg);
diskCtrl = hddaudio.DiskBController(cfg);

audioSpec = hddaudio.defaultSpec();
audioItems = specItems(audioSpec, cfg);
[command, metadata] = hddaudio.buildCommand(audioSpec, cfg);
metadata = hddaudio.writePreviewWav(command, metadata, cfg);

durationSeconds = double(metadata.durationSeconds);
sampleRateHz = double(metadata.sampleRateHz);
cursorLine = [];
selectedAudioRow = [];
app = struct();

fig = uifigure("Name", "HDD Control Panel", "Position", [100 100 1240 780]);
fig.Color = [0.96 0.97 0.98];

rootGrid = uigridlayout(fig, [1 1]);
rootGrid.Padding = [0 0 0 0];
rootGrid.RowHeight = {"1x"};
rootGrid.ColumnWidth = {"1x"};

tabGroup = uitabgroup(rootGrid);
tabGroup.Layout.Row = 1;
tabGroup.Layout.Column = 1;

audioTab = uitab(tabGroup, "Title", "Audio");
diskTab = uitab(tabGroup, "Title", "Disk_B");

audioGrid = uigridlayout(audioTab, [6 1]);
audioGrid.RowHeight = {54, 220, "1x", 42, 108, 30};
audioGrid.ColumnWidth = {"1x"};
audioGrid.Padding = [14 14 14 12];
audioGrid.RowSpacing = 10;

controlGrid = uigridlayout(audioGrid, [1 9]);
controlGrid.Layout.Row = 1;
controlGrid.Layout.Column = 1;
controlGrid.ColumnWidth = {92, 112, 58, 88, 120, 82, 82, 104, "1x"};
controlGrid.RowHeight = {"1x"};
controlGrid.Padding = [0 0 0 0];
controlGrid.ColumnSpacing = 8;

uploadButton = uibutton(controlGrid, "Text", "Upload", "ButtonPushedFcn", @onUpload);
uploadButton.Layout.Row = 1;
uploadButton.Layout.Column = 1;

startLoopButton = uibutton(controlGrid, "Text", "Start Loop", "ButtonPushedFcn", @onStartLoop);
startLoopButton.Layout.Row = 1;
startLoopButton.Layout.Column = 2;
startLoopButton.BackgroundColor = [0.20 0.49 0.72];
startLoopButton.FontColor = [1 1 1];

repeatLabel = uilabel(controlGrid, "Text", "Repeat", "HorizontalAlignment", "right");
repeatLabel.Layout.Row = 1;
repeatLabel.Layout.Column = 3;

repeatEdit = uieditfield(controlGrid, "numeric", "Value", 1, "Limits", [1 Inf], ...
    "RoundFractionalValues", "on");
repeatEdit.Layout.Row = 1;
repeatEdit.Layout.Column = 4;

startFiniteButton = uibutton(controlGrid, "Text", "Start Finite", "ButtonPushedFcn", @onStartFinite);
startFiniteButton.Layout.Row = 1;
startFiniteButton.Layout.Column = 5;
startFiniteButton.BackgroundColor = [0.22 0.58 0.42];
startFiniteButton.FontColor = [1 1 1];

stopButton = uibutton(controlGrid, "Text", "Stop", "ButtonPushedFcn", @onStop);
stopButton.Layout.Row = 1;
stopButton.Layout.Column = 6;

resetButton = uibutton(controlGrid, "Text", "Reset", "ButtonPushedFcn", @onReset);
resetButton.Layout.Row = 1;
resetButton.Layout.Column = 7;

estopButton = uibutton(controlGrid, "Text", "E-STOP", "ButtonPushedFcn", @onEstop);
estopButton.Layout.Row = 1;
estopButton.Layout.Column = 8;
estopButton.FontWeight = "bold";
estopButton.BackgroundColor = [0.82 0.12 0.12];
estopButton.FontColor = [1 1 1];

summaryLabel = uilabel(controlGrid, "HorizontalAlignment", "right");
summaryLabel.Layout.Row = 1;
summaryLabel.Layout.Column = 9;

playlistGrid = uigridlayout(audioGrid, [1 2]);
playlistGrid.Layout.Row = 2;
playlistGrid.Layout.Column = 1;
playlistGrid.ColumnWidth = {150, "1x"};
playlistGrid.RowHeight = {"1x"};
playlistGrid.Padding = [0 0 0 0];
playlistGrid.ColumnSpacing = 10;

playlistButtonGrid = uigridlayout(playlistGrid, [7 1]);
playlistButtonGrid.Layout.Row = 1;
playlistButtonGrid.Layout.Column = 1;
playlistButtonGrid.RowHeight = {26, 26, 26, 26, 26, 26, 26};
playlistButtonGrid.ColumnWidth = {"1x"};
playlistButtonGrid.Padding = [0 0 0 0];
playlistButtonGrid.RowSpacing = 4;

addAudioButton = uibutton(playlistButtonGrid, "Text", "Add Audio", "ButtonPushedFcn", @onAddAudio);
addAudioButton.Layout.Row = 1;
removeButton = uibutton(playlistButtonGrid, "Text", "Remove", "ButtonPushedFcn", @onRemoveItem);
removeButton.Layout.Row = 2;
moveUpButton = uibutton(playlistButtonGrid, "Text", "Move Up", "ButtonPushedFcn", @onMoveUp);
moveUpButton.Layout.Row = 3;
moveDownButton = uibutton(playlistButtonGrid, "Text", "Move Down", "ButtonPushedFcn", @onMoveDown);
moveDownButton.Layout.Row = 4;
rebuildButton = uibutton(playlistButtonGrid, "Text", "Rebuild", "ButtonPushedFcn", @onRebuild);
rebuildButton.Layout.Row = 5;
saveSpecButton = uibutton(playlistButtonGrid, "Text", "Save Spec", "ButtonPushedFcn", @onSaveSpec);
saveSpecButton.Layout.Row = 6;
loadSpecButton = uibutton(playlistButtonGrid, "Text", "Load Spec", "ButtonPushedFcn", @onLoadSpec);
loadSpecButton.Layout.Row = 7;

playlistTable = uitable(playlistGrid, ...
    "ColumnName", {"Type", "File / Label", "Clip", "Amp", "Trim Tail (s)", "Motion Amp", "Motion Hz", "Samples"}, ...
    "ColumnEditable", [false true true true true true true false], ...
    "CellEditCallback", @onPlaylistEdited, ...
    "CellSelectionCallback", @onPlaylistSelected);
playlistTable.Layout.Row = 1;
playlistTable.Layout.Column = 2;

waveAxes = uiaxes(audioGrid);
waveAxes.Layout.Row = 3;
waveAxes.Layout.Column = 1;
waveAxes.Color = [1 1 1];
waveAxes.Box = "on";
waveAxes.XGrid = "on";
waveAxes.YGrid = "on";
waveAxes.XLabel.String = "Time (s)";
waveAxes.YLabel.String = "Command";
waveAxes.Title.String = "Command waveform";
try
    waveAxes.Toolbar.Visible = "off";
    disableDefaultInteractivity(waveAxes);
catch
end

progressGrid = uigridlayout(audioGrid, [1 2]);
progressGrid.Layout.Row = 4;
progressGrid.Layout.Column = 1;
progressGrid.ColumnWidth = {265, "1x"};
progressGrid.RowHeight = {"1x"};
progressGrid.Padding = [0 0 0 0];
progressGrid.ColumnSpacing = 10;

progressLabel = uilabel(progressGrid, "Text", "Progress: --", "FontWeight", "bold");
progressLabel.Layout.Row = 1;
progressLabel.Layout.Column = 1;

progressAxes = uiaxes(progressGrid);
progressAxes.Layout.Row = 1;
progressAxes.Layout.Column = 2;
progressAxes.XLim = [0 1];
progressAxes.YLim = [0 1];
progressAxes.XTick = [];
progressAxes.YTick = [];
progressAxes.Box = "on";
progressAxes.Color = [0.90 0.93 0.96];
try
    progressAxes.Toolbar.Visible = "off";
    disableDefaultInteractivity(progressAxes);
catch
end
hold(progressAxes, "on");
progressFill = patch(progressAxes, [0 0 0 0], [0 0 1 1], [0.20 0.49 0.72], ...
    "EdgeColor", "none");
line(progressAxes, [0 1 1 0 0], [0 0 1 1 0], "Color", [0.55 0.60 0.65], "LineWidth", 0.8);
hold(progressAxes, "off");

statusGrid = uigridlayout(audioGrid, [2 9]);
statusGrid.Layout.Row = 5;
statusGrid.Layout.Column = 1;
statusGrid.ColumnWidth = {"1.35x", "1.05x", "1.05x", "1x", "1.45x", "1x", "1x", "1.15x", "1x"};
statusGrid.RowHeight = {25, "1x"};
statusGrid.Padding = [0 0 0 0];
statusGrid.ColumnSpacing = 10;
statusGrid.RowSpacing = 2;

stateValueLabel = addMetric(statusGrid, 1, "State");
audioStatuswordValueLabel = addMetric(statusGrid, 2, "Statusword");
audioControlwordValueLabel = addMetric(statusGrid, 3, "Controlword");
outputValueLabel = addMetric(statusGrid, 4, "Output");
indexValueLabel = addMetric(statusGrid, 5, "Index");
cycleValueLabel = addMetric(statusGrid, 6, "Cycle");
repeatValueLabel = addMetric(statusGrid, 7, "Repeat");
timeValueLabel = addMetric(statusGrid, 8, "Time");
errorValueLabel = addMetric(statusGrid, 9, "Error");

messageLabel = uilabel(audioGrid, "VerticalAlignment", "center");
messageLabel.Layout.Row = 6;
messageLabel.Layout.Column = 1;

diskGrid = uigridlayout(diskTab, [4 1]);
diskGrid.RowHeight = {56, 112, 170, "1x"};
diskGrid.ColumnWidth = {"1x"};
diskGrid.Padding = [14 14 14 12];
diskGrid.RowSpacing = 12;

diskControlGrid = uigridlayout(diskGrid, [1 5]);
diskControlGrid.Layout.Row = 1;
diskControlGrid.Layout.Column = 1;
diskControlGrid.ColumnWidth = {90, 90, 128, 128, "1x"};
diskControlGrid.RowHeight = {"1x"};
diskControlGrid.Padding = [0 0 0 0];
diskControlGrid.ColumnSpacing = 8;

diskStartButton = uibutton(diskControlGrid, "Text", "Run", "ButtonPushedFcn", @onDiskStart);
diskStartButton.Layout.Column = 1;
diskStartButton.BackgroundColor = [0.20 0.49 0.72];
diskStartButton.FontColor = [1 1 1];

diskStopButton = uibutton(diskControlGrid, "Text", "Stop", "ButtonPushedFcn", @onDiskStop);
diskStopButton.Layout.Column = 2;

diskRestartButton = uibutton(diskControlGrid, "Text", "Safe Restart", "ButtonPushedFcn", @onDiskSafeRestart);
diskRestartButton.Layout.Column = 3;
diskRestartButton.BackgroundColor = [0.22 0.58 0.42];
diskRestartButton.FontColor = [1 1 1];

diskApplyButton = uibutton(diskControlGrid, "Text", "Apply Settings", "ButtonPushedFcn", @onDiskApply);
diskApplyButton.Layout.Column = 4;

diskMessageLabel = uilabel(diskControlGrid, "Text", "Disk_B ready.", "HorizontalAlignment", "right");
diskMessageLabel.Layout.Column = 5;

diskSettingsGrid = uigridlayout(diskGrid, [2 4]);
diskSettingsGrid.Layout.Row = 2;
diskSettingsGrid.Layout.Column = 1;
diskSettingsGrid.ColumnWidth = {"1x", "1x", "1x", "1x"};
diskSettingsGrid.RowHeight = {24, 40};
diskSettingsGrid.Padding = [0 0 0 0];
diskSettingsGrid.ColumnSpacing = 12;
diskSettingsGrid.RowSpacing = 4;

torqueTargetEdit = addDiskEdit(diskSettingsGrid, 1, "Torque Target", cfg.diskDefaultTorqueTarget, true);
torqueRampEdit = addDiskEdit(diskSettingsGrid, 2, "Torque Ramp Step", cfg.diskDefaultTorqueRampStep, true);
angleTargetEdit = addDiskEdit(diskSettingsGrid, 3, "Angle Inc Target", cfg.diskDefaultAngleIncTarget, false);
angleRampEdit = addDiskEdit(diskSettingsGrid, 4, "Angle Inc Ramp Step", cfg.diskDefaultAngleIncRampStep, false);

diskStatusGrid = uigridlayout(diskGrid, [4 6]);
diskStatusGrid.Layout.Row = 3;
diskStatusGrid.Layout.Column = 1;
diskStatusGrid.ColumnWidth = {"1x", "1x", "1x", "1x", "1x", "1x"};
diskStatusGrid.RowHeight = {24, 42, 24, 42};
diskStatusGrid.Padding = [0 0 0 0];
diskStatusGrid.ColumnSpacing = 10;
diskStatusGrid.RowSpacing = 2;

diskStateValueLabel = addDiskMetric(diskStatusGrid, 1, 1, "State");
diskRunValueLabel = addDiskMetric(diskStatusGrid, 1, 2, "RunCmd");
diskStatuswordValueLabel = addDiskMetric(diskStatusGrid, 1, 3, "Statusword");
diskControlwordValueLabel = addDiskMetric(diskStatusGrid, 1, 4, "Controlword");
diskTorqueActualValueLabel = addDiskMetric(diskStatusGrid, 1, 5, "TorqueActual");
diskTargetTorqueValueLabel = addDiskMetric(diskStatusGrid, 1, 6, "TargetTorque");
diskTorqueCmdValueLabel = addDiskMetric(diskStatusGrid, 3, 1, "TorqueCmd");
diskTorqueTargetValueLabel = addDiskMetric(diskStatusGrid, 3, 2, "TorqueTarget");
diskAngleValueLabel = addDiskMetric(diskStatusGrid, 3, 3, "Angle");
diskCommutationAngleValueLabel = addDiskMetric(diskStatusGrid, 3, 4, "Commutation");
diskAngleActualValueLabel = addDiskMetric(diskStatusGrid, 3, 5, "AngleIncActual");
diskAngleTargetValueLabel = addDiskMetric(diskStatusGrid, 3, 6, "AngleIncTarget");

statusTimer = timer( ...
    "ExecutionMode", "fixedSpacing", ...
    "Period", 0.25, ...
    "TimerFcn", @(~, ~)refreshAllStatus());

fig.CloseRequestFcn = @onClose;

app = struct( ...
    "AudioController", audioCtrl, ...
    "DiskController", diskCtrl, ...
    "Figure", fig, ...
    "Timer", statusTimer, ...
    "Command", command, ...
    "Metadata", metadata, ...
    "Widgets", struct( ...
        "WaveAxes", waveAxes, ...
        "ProgressAxes", progressAxes, ...
        "RepeatEdit", repeatEdit, ...
        "PlaylistTable", playlistTable, ...
        "TorqueTargetEdit", torqueTargetEdit, ...
        "AngleIncTargetEdit", angleTargetEdit));

refreshAudioUiFromState();
start(statusTimer);
refreshAllStatus();

    function onUpload(~, ~)
        try
            setOperationProgress(0, "Upload: queued");
            metadata = audioCtrl.upload(command, metadata, @setOperationProgress);
            app.Metadata = metadata;
            messageLabel.Text = sprintf("Uploaded %d samples.", metadata.numSamples);
            refreshAudioStatus();
        catch err
            setOperationProgress(0, "Upload failed");
            messageLabel.Text = err.message;
        end
    end

    function onStartLoop(~, ~)
        try
            audioCtrl.start("loop");
            messageLabel.Text = "Loop playback started.";
            refreshAudioStatus();
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onStartFinite(~, ~)
        try
            repeatCount = validatedRepeatCount();
            audioCtrl.start("finite", "RepeatCount", repeatCount);
            messageLabel.Text = sprintf("Finite playback started (%d repeat%s).", ...
                repeatCount, pluralSuffix(repeatCount));
            refreshAudioStatus();
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onStop(~, ~)
        try
            audioCtrl.stop();
            messageLabel.Text = "Stop requested.";
            refreshAudioStatus();
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onEstop(~, ~)
        try
            audioCtrl.estop();
            messageLabel.Text = "E-STOP requested.";
            refreshAudioStatus();
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onReset(~, ~)
        try
            audioCtrl.reset();
            messageLabel.Text = "Reset requested.";
            refreshAudioStatus();
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onPlaylistSelected(~, event)
        if isempty(event.Indices)
            selectedAudioRow = [];
        else
            selectedAudioRow = event.Indices(1, 1);
        end
    end

    function onPlaylistEdited(~, event)
        row = event.Indices(1);
        col = event.Indices(2);
        if row < 1 || row > numel(audioItems)
            return;
        end

        item = audioItems{row};
        itemType = lower(strtrim(string(item.type)));
        if ~isAudioItemType(itemType) && ~(itemType == "square" && col == 4)
            playlistTable.Data = playlistData(audioItems, metadata);
            messageLabel.Text = "Only audio rows and square Amp are editable.";
            return;
        end

        try
            switch col
                case 2
                    if ~isAudioItemType(itemType)
                        error("hddaudio:invalidPlaylistEdit", "Only audio file cells are editable.");
                    end
                    newFile = strtrim(string(event.NewData));
                    if strlength(newFile) == 0
                        error("hddaudio:invalidSpecItem", "Audio file cannot be empty.");
                    end
                    item.file = char(newFile);
                case 3
                    if ~isAudioItemType(itemType)
                        error("hddaudio:invalidPlaylistEdit", "Only audio Clip cells are editable.");
                    end
                    item.clip = numericValue(event.NewData, "Clip", eps, Inf);
                case 4
                    if itemType == "square"
                        item.amplitude = numericValue(event.NewData, "Amp", 0, cfg.commandLimit);
                    else
                        item.amp = numericValue(event.NewData, "Amp", 0, cfg.commandLimit);
                        if isfield(item, "scale")
                            item = rmfield(item, "scale");
                        end
                    end
                case 5
                    if ~isAudioItemType(itemType)
                        error("hddaudio:invalidPlaylistEdit", "Only audio Trim Tail cells are editable.");
                    end
                    item.trimTailSeconds = numericValue(event.NewData, "Trim Tail", 0, Inf);
                case 6
                    if ~isAudioItemType(itemType)
                        error("hddaudio:invalidPlaylistEdit", "Only audio Motion Amp cells are editable.");
                    end
                    item.motionAmplitude = numericValue(event.NewData, "Motion Amp", 0, cfg.commandLimit);
                case 7
                    if ~isAudioItemType(itemType)
                        error("hddaudio:invalidPlaylistEdit", "Only audio Motion Hz cells are editable.");
                    end
                    item.motionFrequencyHz = numericValue(event.NewData, "Motion Hz", 0, Inf);
            end
            audioItems{row} = item;
            playlistTable.Data = playlistData(audioItems, metadata);
        catch err
            playlistTable.Data = playlistData(audioItems, metadata);
            messageLabel.Text = err.message;
        end
    end

    function onAddAudio(~, ~)
        [files, pathName] = uigetfile({ ...
            "*.wav;*.mp3;*.flac;*.m4a;*.mp4;*.ogg", "Audio files (*.wav, *.mp3, *.flac, *.m4a, *.mp4, *.ogg)"; ...
            "*.*", "All files (*.*)"}, ...
            "Add Audio", char(cfg.soundDir), "MultiSelect", "on");
        if isequal(files, 0)
            return;
        end

        if ischar(files) || isstring(files)
            files = {char(files)};
        end

        for idx = 1:numel(files)
            fullPath = fullfile(pathName, files{idx});
            audioItems{end + 1} = struct( ...
                "type", "audio", ...
                "file", char(audioFileRef(fullPath, cfg.soundDir)), ...
                "clip", cfg.defaultAudioClip, ...
                "amp", cfg.defaultAudioAmplitude, ...
                "trimTailSeconds", 0, ...
                "motionAmplitude", cfg.defaultVisibleMotionAmplitude, ...
                "motionFrequencyHz", cfg.defaultVisibleMotionFrequencyHz);
        end

        selectedAudioRow = numel(audioItems);
        rebuildAudio("Added audio file.");
    end

    function onRemoveItem(~, ~)
        row = requireSelectedAudioRow();
        if isempty(row)
            return;
        end
        audioItems(row) = [];
        selectedAudioRow = min(row, numel(audioItems));
        rebuildAudio("Removed item.");
    end

    function onMoveUp(~, ~)
        row = requireSelectedAudioRow();
        if isempty(row) || row <= 1
            return;
        end
        audioItems([row - 1, row]) = audioItems([row, row - 1]);
        selectedAudioRow = row - 1;
        rebuildAudio("Moved item up.");
    end

    function onMoveDown(~, ~)
        row = requireSelectedAudioRow();
        if isempty(row) || row >= numel(audioItems)
            return;
        end
        audioItems([row, row + 1]) = audioItems([row + 1, row]);
        selectedAudioRow = row + 1;
        rebuildAudio("Moved item down.");
    end

    function onRebuild(~, ~)
        rebuildAudio("Rebuilt command table.");
    end

    function onSaveSpec(~, ~)
        [fileName, pathName] = uiputfile("*.mat", "Save audio spec", ...
            fullfile(char(cfg.soundDir), "hdd_audio_spec.mat"));
        if isequal(fileName, 0)
            return;
        end

        try
            hddaudio.saveSpec(fullfile(pathName, fileName), currentSpec());
            messageLabel.Text = sprintf("Saved spec: %s", fileName);
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onLoadSpec(~, ~)
        [fileName, pathName] = uigetfile("*.mat", "Load audio spec", char(cfg.soundDir));
        if isequal(fileName, 0)
            return;
        end

        try
            audioSpec = hddaudio.loadSpec(fullfile(pathName, fileName));
            audioItems = specItems(audioSpec, cfg);
            selectedAudioRow = [];
            rebuildAudio(sprintf("Loaded spec: %s", fileName));
        catch err
            messageLabel.Text = err.message;
        end
    end

    function rebuildAudio(successMessage)
        try
            audioSpec = currentSpec();
            setOperationProgress(0, "Rebuild: queued");
            [newCommand, newMetadata] = hddaudio.buildCommand(audioSpec, cfg, @setOperationProgress);
            newMetadata = hddaudio.writePreviewWav(newCommand, newMetadata, cfg);
            command = newCommand;
            metadata = newMetadata;
            durationSeconds = double(metadata.durationSeconds);
            sampleRateHz = double(metadata.sampleRateHz);
            app.Command = command;
            app.Metadata = metadata;
            refreshAudioUiFromState();
            messageLabel.Text = sprintf("%s Preview WAV: %s", ...
                char(successMessage), char(metadata.previewWavFile));
        catch err
            playlistTable.Data = playlistData(audioItems, metadata);
            setOperationProgress(0, "Rebuild failed");
            messageLabel.Text = err.message;
        end
    end

    function refreshAllStatus()
        refreshAudioStatus();
        refreshDiskStatus();
    end

    function refreshAudioStatus()
        if ~isvalid(fig)
            return;
        end

        try
            status = audioCtrl.readStatus();
            cursorInfo = playbackCursorInfo(status);

            stateValueLabel.Text = sprintf("%s (%d)", char(status.stateName), status.state);
            stateValueLabel.FontColor = stateColor(status);
            audioStatuswordValueLabel.Text = sprintf("0x%04X", status.statusword);
            audioControlwordValueLabel.Text = sprintf("0x%04X", status.controlword);
            outputValueLabel.Text = sprintf("%d", status.outputValue);
            indexValueLabel.Text = sprintf("%d / %d", status.idx, status.tableLen);
            cycleValueLabel.Text = sprintf("%d", status.cycleCount);
            repeatValueLabel.Text = repeatText(status.repeatCount);
            timeValueLabel.Text = sprintf("%.2f / %.2f s", cursorInfo.cursorTime, durationSeconds);
            errorValueLabel.Text = sprintf("%d", status.errorCode);
            errorValueLabel.FontColor = errorColor(status.errorCode);

            setCursorTime(cursorInfo.cursorTime);
            drawnow limitrate;
        catch err
            messageLabel.Text = err.message;
        end
    end

    function onDiskApply(~, ~)
        try
            diskCtrl.applySettings(diskSettingsFromUi());
            diskMessageLabel.Text = "Disk_B settings applied.";
            refreshDiskStatus();
        catch err
            diskMessageLabel.Text = err.message;
        end
    end

    function onDiskStart(~, ~)
        try
            diskCtrl.applySettings(diskSettingsFromUi());
            diskCtrl.start();
            diskMessageLabel.Text = "Disk_B RunCmd set.";
            refreshDiskStatus();
        catch err
            diskMessageLabel.Text = err.message;
        end
    end

    function onDiskStop(~, ~)
        try
            diskCtrl.stop();
            diskMessageLabel.Text = "Disk_B stop requested.";
            refreshDiskStatus();
        catch err
            diskMessageLabel.Text = err.message;
        end
    end

    function onDiskSafeRestart(~, ~)
        try
            diskCtrl.safeRestart(diskSettingsFromUi());
            diskMessageLabel.Text = "Disk_B safe restart complete.";
            refreshDiskStatus();
        catch err
            diskMessageLabel.Text = err.message;
        end
    end

    function refreshDiskStatus()
        if ~isvalid(fig)
            return;
        end

        try
            status = diskCtrl.readStatus();
            diskStateValueLabel.Text = char(status.statusName);
            diskStateValueLabel.FontColor = diskStateColor(status.statusName);
            diskRunValueLabel.Text = logicalText(status.runCmd);
            diskStatuswordValueLabel.Text = sprintf("0x%04X", status.statusword);
            diskControlwordValueLabel.Text = sprintf("0x%04X", status.controlword);
            diskTorqueActualValueLabel.Text = sprintf("%d", status.torqueActual);
            diskTargetTorqueValueLabel.Text = sprintf("%d", status.targetTorque);
            diskTorqueCmdValueLabel.Text = sprintf("%d", status.torqueCmd);
            diskTorqueTargetValueLabel.Text = sprintf("%d", status.torqueTarget);
            diskAngleValueLabel.Text = sprintf("%.1f", status.angle);
            diskCommutationAngleValueLabel.Text = sprintf("%d", status.commutationAngle);
            diskAngleActualValueLabel.Text = sprintf("%.3f", status.angleIncActual);
            diskAngleTargetValueLabel.Text = sprintf("%.3f", status.angleIncTarget);
        catch err
            diskMessageLabel.Text = err.message;
        end
    end

    function refreshAudioUiFromState()
        summaryLabel.Text = sprintf("%s | %d samples | %.3f s | %.0f Hz", ...
            char(metadata.specName), metadata.numSamples, durationSeconds, sampleRateHz);
        playlistTable.Data = playlistData(audioItems, metadata);
        refreshWaveform();
    end

    function refreshWaveform()
        commandValues = double(command(:));
        numSamples = numel(commandValues);
        timeSeconds = (0:max(numSamples - 1, 0))' ./ sampleRateHz;
        plotStep = max(1, ceil(max(numSamples, 1) / 12000));
        yLimit = max([1, double(metadata.commandLimit), abs(double(metadata.minCommand)), abs(double(metadata.maxCommand))]);
        yLimits = 1.08 * [-yLimit, yLimit];

        cla(waveAxes);
        waveAxes.XLim = [0, max(durationSeconds, 1 / sampleRateHz)];
        waveAxes.YLim = yLimits;
        hold(waveAxes, "on");
        if numSamples > 0
            plot(waveAxes, timeSeconds(1:plotStep:end), commandValues(1:plotStep:end), ...
                "Color", [0.06 0.28 0.44], "LineWidth", 0.85);
        else
            plot(waveAxes, 0, 0, "Color", [0.06 0.28 0.44], "LineWidth", 0.85);
        end
        yline(waveAxes, 0, ":", "Color", [0.55 0.55 0.55]);
        yline(waveAxes, double(metadata.commandLimit), "--", "Color", [0.80 0.25 0.25]);
        yline(waveAxes, -double(metadata.commandLimit), "--", "Color", [0.80 0.25 0.25]);
        addSegmentMarkers(yLimits);
        cursorLine = line(waveAxes, [0 0], yLimits, ...
            "Color", [0.88 0.18 0.10], "LineWidth", 2.0);
        hold(waveAxes, "off");
    end

    function label = addMetric(parent, column, titleText)
        titleLabel = uilabel(parent, "Text", titleText, "FontWeight", "bold", ...
            "FontColor", [0.30 0.34 0.38]);
        titleLabel.Layout.Row = 1;
        titleLabel.Layout.Column = column;

        label = uilabel(parent, "Text", "--", "FontSize", 16, ...
            "VerticalAlignment", "top");
        label.Layout.Row = 2;
        label.Layout.Column = column;
    end

    function edit = addDiskEdit(parent, column, titleText, value, roundValues)
        label = uilabel(parent, "Text", titleText, "FontWeight", "bold", ...
            "FontColor", [0.30 0.34 0.38]);
        label.Layout.Row = 1;
        label.Layout.Column = column;
        edit = uieditfield(parent, "numeric", "Value", double(value));
        edit.Layout.Row = 2;
        edit.Layout.Column = column;
        edit.RoundFractionalValues = logical(roundValues);
    end

    function label = addDiskMetric(parent, titleRow, column, titleText)
        titleLabel = uilabel(parent, "Text", titleText, "FontWeight", "bold", ...
            "FontColor", [0.30 0.34 0.38]);
        titleLabel.Layout.Row = titleRow;
        titleLabel.Layout.Column = column;

        label = uilabel(parent, "Text", "--", "FontSize", 15, ...
            "VerticalAlignment", "top");
        label.Layout.Row = titleRow + 1;
        label.Layout.Column = column;
    end

    function addSegmentMarkers(yLimits)
        if ~isfield(metadata, "items") || isempty(metadata.items)
            return;
        end

        sampleOffset = 0;
        labelY = yLimits(2) - 0.06 * diff(yLimits);
        for itemIdx = 1:numel(metadata.items)
            item = metadata.items(itemIdx);
            itemSamples = double(item.numSamples);
            startTime = sampleOffset / sampleRateHz;
            endTime = (sampleOffset + itemSamples) / sampleRateHz;

            if itemIdx > 1
                line(waveAxes, [startTime startTime], yLimits, ...
                    "Color", [0.78 0.52 0.16], "LineStyle", "--", "LineWidth", 0.9);
            end

            labelText = truncateLabel(string(item.label), 28);
            if isfield(item, "wasResampled") && item.wasResampled
                labelText = truncateLabel(sprintf("%s -> %.0f Hz", labelText, sampleRateHz), 28);
            end

            text(waveAxes, startTime + max(endTime - startTime, 0) / 2, labelY, labelText, ...
                "HorizontalAlignment", "center", ...
                "VerticalAlignment", "top", ...
                "FontSize", 9, ...
                "Color", [0.32 0.32 0.32], ...
                "Interpreter", "none", ...
                "Clipping", "on");

            sampleOffset = sampleOffset + itemSamples;
        end
    end

    function info = playbackCursorInfo(status)
        info = struct("cursorTime", 0);
        if status.tableLen <= 0
            return;
        end

        tableLen = max(double(status.tableLen), 1);
        idx = min(max(double(status.idx), 0), tableLen);
        info.cursorTime = min(idx / sampleRateHz, durationSeconds);
    end

    function setProgressFraction(fraction)
        fraction = min(max(double(fraction), 0), 1);
        progressFill.XData = [0 fraction fraction 0];
        progressFill.YData = [0 0 1 1];

        if fraction >= 0.999
            progressFill.FaceColor = [0.22 0.58 0.42];
        else
            progressFill.FaceColor = [0.20 0.49 0.72];
        end
    end

    function setOperationProgress(fraction, messageText)
        progressLabel.Text = char(messageText);
        setProgressFraction(fraction);
        drawnow limitrate;
    end

    function setCursorTime(cursorTime)
        if isempty(cursorLine) || ~isvalid(cursorLine)
            return;
        end
        cursorTime = min(max(double(cursorTime), 0), max(durationSeconds, 0));
        cursorLine.XData = [cursorTime cursorTime];
        cursorLine.YData = waveAxes.YLim;
    end

    function repeatCount = validatedRepeatCount()
        repeatCount = round(double(repeatEdit.Value));
        if ~isfinite(repeatCount) || repeatCount < 1
            error("hddaudio:invalidRepeatCount", "Repeat count must be a positive integer.");
        end
        repeatEdit.Value = repeatCount;
    end

    function settings = diskSettingsFromUi()
        settings = struct( ...
            "TorqueTarget", torqueTargetEdit.Value, ...
            "TorqueRampStep", torqueRampEdit.Value, ...
            "AngleIncTarget", angleTargetEdit.Value, ...
            "AngleIncRampStep", angleRampEdit.Value);
    end

    function row = requireSelectedAudioRow()
        row = selectedAudioRow;
        if isempty(row) || row < 1 || row > numel(audioItems)
            messageLabel.Text = "Select an audio row first.";
            row = [];
        end
    end

    function spec = currentSpec()
        spec = struct();
        spec.name = audioSpecName(audioSpec);
        spec.items = audioItems;
    end

    function onClose(~, ~)
        try
            stop(statusTimer);
            delete(statusTimer);
        catch
        end
        try
            delete(audioCtrl);
        catch
        end
        try
            delete(diskCtrl);
        catch
        end
        delete(fig);
    end
end

function items = specItems(spec, cfg)
items = spec.items;
if isstruct(items)
    items = num2cell(items);
end
for idx = 1:numel(items)
    item = items{idx};
    itemType = lower(strtrim(string(item.type)));
    if isAudioItemType(itemType) && ~isfield(item, "amp")
        item.amp = cfg.defaultAudioAmplitude;
        if isfield(item, "scale")
            item = rmfield(item, "scale");
        end
        items{idx} = item;
    end
end
end

function name = audioSpecName(spec)
if isfield(spec, "name")
    name = string(spec.name);
else
    name = "ui";
end
end

function data = playlistData(items, metadata)
rowCount = numel(items);
data = cell(rowCount, 8);
for idx = 1:rowCount
    item = items{idx};
    itemType = lower(strtrim(string(item.type)));
    data{idx, 1} = char(itemType);
    if isAudioItemType(itemType)
        data{idx, 2} = char(itemValue(item, "file", ""));
        data{idx, 3} = itemValue(item, "clip", NaN);
        data{idx, 4} = itemValue(item, "amp", NaN);
        data{idx, 5} = itemValue(item, "trimTailSeconds", 0);
        data{idx, 6} = itemValue(item, "motionAmplitude", 0);
        data{idx, 7} = itemValue(item, "motionFrequencyHz", 0);
    else
        data{idx, 2} = char(itemLabel(item));
        data{idx, 3} = NaN;
        data{idx, 4} = itemValue(item, "amplitude", NaN);
        data{idx, 5} = NaN;
        data{idx, 6} = NaN;
        data{idx, 7} = NaN;
    end

    if nargin >= 2 && isfield(metadata, "items") && numel(metadata.items) >= idx
        data{idx, 8} = double(metadata.items(idx).numSamples);
    else
        data{idx, 8} = NaN;
    end
end
end

function label = itemLabel(item)
itemType = lower(strtrim(string(item.type)));
switch itemType
    case "square"
        label = sprintf("square %.3fs", itemValue(item, "durationSeconds", 1.0));
    case {"wav", "audio"}
        label = string(itemValue(item, "file", ""));
    otherwise
        label = itemType;
end
end

function tf = isAudioItemType(itemType)
itemType = lower(strtrim(string(itemType)));
tf = itemType == "wav" || itemType == "audio";
end

function value = itemValue(item, fieldName, defaultValue)
if isfield(item, fieldName)
    value = item.(fieldName);
else
    value = defaultValue;
end
end

function value = numericValue(value, label, minValue, maxValue)
if ischar(value) || isstring(value)
    value = str2double(value);
end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value < minValue || value > maxValue
    error("hddaudio:invalidPlaylistValue", "%s must be a finite numeric value.", label);
end
value = double(value);
end

function ref = audioFileRef(fullPath, soundDir)
fullPath = char(fullPath);
root = char(soundDir);
if ~endsWith(root, filesep)
    root = [root filesep];
end

if startsWith(lower(fullPath), lower(root))
    ref = string(fullPath(numel(root) + 1:end));
else
    ref = string(fullPath);
end
end

function text = repeatText(repeatCount)
if repeatCount == 0
    text = "Loop";
else
    text = sprintf("%d", repeatCount);
end
end

function color = stateColor(status)
switch string(status.stateName)
    case "PLAYING"
        color = [0.12 0.40 0.74];
    case "COMPLETE"
        color = [0.18 0.50 0.28];
    case {"FAULT", "ESTOP"}
        color = [0.78 0.10 0.10];
    otherwise
        color = [0.16 0.18 0.20];
end
end

function color = diskStateColor(stateName)
switch string(stateName)
    case "OPERATION_ENABLED"
        color = [0.12 0.40 0.74];
    case {"READY_TO_SWITCH_ON", "SWITCHED_ON"}
        color = [0.18 0.50 0.28];
    case "FAULT"
        color = [0.78 0.10 0.10];
    otherwise
        color = [0.16 0.18 0.20];
end
end

function color = errorColor(errorCode)
if errorCode == 0
    color = [0.16 0.18 0.20];
else
    color = [0.78 0.10 0.10];
end
end

function text = logicalText(value)
if value
    text = "TRUE";
else
    text = "FALSE";
end
end

function suffix = pluralSuffix(count)
if count == 1
    suffix = "";
else
    suffix = "s";
end
end

function text = truncateLabel(text, maxLength)
text = char(text);
if strlength(string(text)) > maxLength
    text = char(extractBefore(string(text), maxLength - 2) + "...");
end
end
