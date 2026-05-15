function command = normalizeCommand(command, cfg)
%NORMALIZECOMMAND Clamp and validate a PLC command table.

if nargin < 2 || isempty(cfg)
    cfg = hddaudio.defaultConfig();
else
    cfg = hddaudio.mergeConfig(hddaudio.defaultConfig(), cfg);
end

if ~isnumeric(command)
    error("hddaudio:invalidCommand", "Command must be numeric.");
end

command = round(double(command(:)));
command = min(max(command, -double(cfg.commandLimit)), double(cfg.commandLimit));
if numel(command) > cfg.tableMaxN
    error("hddaudio:tableTooLong", ...
        "Command length (%d) exceeds tableMaxN (%d).", numel(command), cfg.tableMaxN);
end

command = int16(command);
end
