function saveSpec(filePath, spec)
%SAVESPEC Save an audio replay spec to a MAT file.

if nargin < 2
    error("hddaudio:invalidSpecSave", "saveSpec requires a file path and spec.");
end
filePath = string(filePath);
if numel(filePath) ~= 1 || strlength(strtrim(filePath)) == 0
    error("hddaudio:invalidSpecSave", "saveSpec requires one non-empty file path.");
end
if ~isstruct(spec) || ~isfield(spec, "items")
    error("hddaudio:invalidSpec", "Spec must be a struct with an items field.");
end

formatVersion = 1; %#ok<NASGU>
savedAt = datestr(now); %#ok<NASGU>
save(char(filePath), 'spec', 'formatVersion', 'savedAt');
end
