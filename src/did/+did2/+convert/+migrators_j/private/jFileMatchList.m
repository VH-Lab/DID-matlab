function patterns = jFileMatchList(raw)
%JFILEMATCHLIST PARSE a did_v1 filenavigator parameter string into a pattern list.
%   PATTERNS = jFileMatchList(RAW) returns a 1xN cellstr of file-match patterns,
%   or {} when RAW declares none. NOTHING IS EVAL'D.
%
%   ---------------------------------------------------------------------
%   THE ACTUAL SHAPE, FROM THE WRITER (not guessed)
%   ---------------------------------------------------------------------
%   v1 stores these as EXECUTABLE MATLAB TEXT and recovers them with `eval`:
%
%     ndi.file.navigator.newdocument (navigator.m:738,746, NDI origin/main):
%         filenavigator_structure.fileparameters = ...
%             cell2str(ndi_filenavigator_obj.fileparameters.filematch);
%         filenavigator_structure.epochprobemap_fileparameters = ...
%             cell2str(ndi_filenavigator_obj.epochprobemap_fileparameters.filematch);
%
%     ndi.file.navigator (navigator.m:45,52):
%         fileparameters_ = eval([...filenavigator.fileparameters]);
%         epochprobemap_fileparameters_ = eval([...epochprobemap_fileparameters]);
%
%   So the stored text is exactly cell2str's output format, and cell2str is a
%   small, closed function (did/+did/+datastructures/cell2str.m):
%
%         if isempty(theCell), str = '{}'; return; end
%         str = '{ ';
%         for i=1:length(theCell)
%             if ischar(theCell{i}),      str = [str '''' theCell{i} ''', '];
%             elseif isnumeric(theCell{i}), str = [str mat2str(theCell{i}) ', '];
%             end
%         end
%         str = [str(1:end-2) ' }'];
%
%   i.e.  {}              for an empty list
%         { 'a', 'b' }    for {'a','b'}
%
%   Real values, from the writers that build navigators on NDI origin/main:
%       {'#\.rhd\>', '#\.tsv\>'}          +ndi/+test/+daq/intan_flat_metadata.m:29
%       {'#.rhd', '#.epochprobemap.ndi'}  +ndi/+test/+daq/build_intan_flat_exp.m:50
%       {'(.*)epochprobemap.ndi'}         same line, the epochprobemap parameter
%       '.*\.rhd\>'                       +ndi/+session/mock.m:54  (a bare char)
%       {'.*\.smr\>','probemap.txt','stims.tsv'}
%                                         +ndi/+example/+tutorial/tutorial_02_01.m:100
%
%   A BARE CHAR is possible on the object side (setfileparameters wraps a char
%   into a cell before storing, navigator.m:403-409), so the stored text is
%   normally braced -- but a document written by another route could hold an
%   unbraced string, and eval would accept that too. Unbraced input is therefore
%   treated as ONE literal pattern rather than discarded.
%
%   ---------------------------------------------------------------------
%   WHY A PARSER AND NOT eval
%   ---------------------------------------------------------------------
%   T14, quoted in V_eta_daq_family_decisions.md: "could a consumer that has
%   never read our migrator code get the value out ... from the schema alone?"
%   Carrying the text forward would answer no, and running eval on archived
%   corpus text during a migration is not something this pipeline should do at
%   all. The migration's job is to PARSE it into declared structure.
%
%   cell2str does not escape a quote inside an element (it would produce text
%   eval could not parse either), but MATLAB's own doubling convention is
%   accepted and unescaped here so a hand-written document round-trips.
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.

patterns = {};
if nargin < 1 || isempty(raw)
    return;
end

% A body that never went through cell2str may already carry a list.
if iscell(raw)
    for k = 1:numel(raw)
        v = raw{k};
        if ischar(v) && ~isempty(v)
            patterns{end+1} = v; %#ok<AGROW>
        elseif isstring(v) && isscalar(v) && strlength(v) > 0
            patterns{end+1} = char(v); %#ok<AGROW>
        end
    end
    return;
end

if ischar(raw)
    s = raw;
elseif isstring(raw) && isscalar(raw)
    s = char(raw);
else
    return;     % numeric / struct / anything else declares no pattern
end

s = strtrim(s);
if isempty(s)
    return;
end

if s(1) ~= '{' || s(end) ~= '}'
    patterns = {s};     % unbraced -> one literal pattern
    return;
end

inner = strtrim(s(2:end-1));
if isempty(inner)
    return;             % '{}' or '{ }' -- an empty list
end

% Quoted elements. The regex is  '((?:[^']|'')*)'  -- a quote, then either a
% non-quote or a DOUBLED quote, then a quote.
tok = regexp(inner, '''((?:[^'']|'''')*)''', 'tokens');
if ~isempty(tok)
    patterns = cell(1, numel(tok));
    for k = 1:numel(tok)
        patterns{k} = strrep(tok{k}{1}, '''''', '''');
    end
    return;
end

% No quoted elements: mat2str-written numeric entries (cell2str's other branch).
% Kept as their text rather than dropped -- a pattern list is char-typed, and a
% numeric filematch entry has no meaning we can assert.
parts = strtrim(strsplit(inner, ','));
patterns = parts(~cellfun(@isempty, parts));
end
