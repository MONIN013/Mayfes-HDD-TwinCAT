function spec = loadSpec(filePath)
%LOADSPEC Load an audio replay spec from a MAT file.

if nargin < 1
    error("hddaudio:invalidSpecLoad", "loadSpec requires a file path.");
end
filePath = string(filePath);
if numel(filePath) ~= 1 || strlength(strtrim(filePath)) == 0
    error("hddaudio:invalidSpecLoad", "loadSpec requires one non-empty file path.");
end
if ~isfile(filePath)
    error("hddaudio:fileNotFound", "Spec file not found: %s", filePath);
end

data = load(char(filePath), 'spec');
if ~isfield(data, "spec") || ~isstruct(data.spec) || ~isfield(data.spec, "items")
    error("hddaudio:invalidSpec", "MAT file must contain a spec struct with an items field.");
end

spec = data.spec;
end
