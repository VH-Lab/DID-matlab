function files = bodyFiles(files, chunks)
%BODYFILES The body's file-series members: FILES when given, else
%   body_data_0 .. body_data_<CHUNKS-1> (item 17; an unchunked body is the one
%   member body_data_0).
if ~isempty(files)
    if chunks ~= 1
        error('did2:build:ambiguousField', 'Give ''Chunks'' or ''Files'', not both.');
    end
    return;
end
files = arrayfun(@(k) sprintf('body_data_%d', k), 0:chunks-1, 'UniformOutput', false);
end
