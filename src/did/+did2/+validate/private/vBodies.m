% VBODIES is SHARED by every instrument in +did2/+validate (silentLoss,
% fileList, ...). It used to be a local function inside silentLoss, and #64
% needed the same behaviour: a second copy would have been a second chance to
% re-introduce the exact bug the note below describes.

function [bodies, unreadable] = vBodies(docs)
%VBODIES Accept a cell of did2.document, a cell of structs, or a struct array.
%   Returns the parsed bodies AND the number that could not be parsed.
%
%   THE SECOND RETURN IS THE POINT. This used to end with
%
%       bodies = bodies(~cellfun(@isempty, bodies));
%
%   which DISCARDED every document asStruct could not read, and the caller then
%   set total_docs from the survivors. When asStruct was asking for a property
%   name that does not exist, every document was dropped, total_docs came out 0,
%   and the report read
%
%       total_docs=0  skipped_docs=0  empty_edges=0  vacuous_fields=0
%
%   on all five corpora -- 221,813 documents inspected, none of them actually
%   looked at. An all-zero census is indistinguishable from a clean one, so the
%   counter built to make silent loss visible was itself silently losing
%   everything, and its zeros were cited as evidence for two days.
%
%   Now: unparseable documents are COUNTED, not dropped. A census that cannot
%   read its input says so.
bodies = {};
unreadable = 0;
if isempty(docs); return; end
if iscell(docs)
    items = docs;
elseif isstruct(docs)
    items = num2cell(docs(:)');
else
    items = arrayfun(@(x) {x}, docs(:)');
end
for k = 1:numel(items)
    b = asStruct(items{k});
    if isempty(b)
        unreadable = unreadable + 1;
    else
        bodies{end+1} = b; %#ok<AGROW>
    end
end
end

function s = asStruct(d)
%ASSTRUCT The document body as a plain struct, or [] if it cannot be read.
%
%   THE PROPERTY IS `documentProperties`. This asked for `document_properties`
%   and `body`; did2.document has NEITHER, so both accesses threw, every
%   document became [], and the whole census silently measured nothing. The
%   snake_case spellings are kept as fallbacks for the older did.document
%   shape, but the real one is tried FIRST.
s = [];
if isstruct(d)
    s = d;
    return;
end
for prop = {'documentProperties', 'document_properties', 'body'}
    try
        v = d.(prop{1});
        if isstruct(v) && ~isempty(fieldnames(v))
            s = v;
            return;
        end
    catch
        % wrong shape for this accessor -- try the next
    end
end
end

