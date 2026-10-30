function [localId, problem] = elementHandle(name, reference)
%ELEMENTHANDLE A migrated element's local_identifier, written beside its name.
%
%   [LOCALID, PROBLEM] = did2.convert.elementHandle(NAME, REFERENCE)
%
%   Decided by Jess Haley, 2026-10-29 [element name and reference stored
%   apart] (did-schema V_eta_go_forward_class_audit.md): a migrated `element`
%   writes its v1 name, exactly, to the entity's `name`, and keeps the
%   name-and-reference handle in `local_identifier` as the dataset-unique
%   handle; the reference is read back as what follows the KNOWN name
%   (did2.convert.elementNameReferenceApart), so every name and reference
%   rebuild, including a name that itself reads as a pair. It replaces
%   the carry of a pair that could not be packed reversibly.
%
%   The handle keeps today's form ([element local identifier is name and
%   reference], 2026-10-26, NDI's display form):
%
%       NAME                        no reference
%       NAME ' | ' <reference>      an integer reference: int2str, exactly
%                                   what did2.convert.elementLocalIdentifier
%                                   (the mirror of NDI's) writes, so the
%                                   common element's identifier is unchanged
%                                   and the epoch probe-map joins
%                                   (epochMint, resolveEpochProbemap) still
%                                   meet it
%       NAME ' | ' <reference>      any other number: num2str(R, 17), which
%                                   str2double reads back to the same double
%       NAME ' | ' <text>           a text reference, verbatim (read back as
%                                   a number when it is one, as today)
%
%   NAME is written as it is (no trimming). An empty NAME writes ' | <ref>'
%   (the entity then has no `name`; the reader reads the empty name from the
%   handle's leading ' | ').
%
%   PROBLEM is '' when LOCALID was written, else (LOCALID ''):
%     'empty'      NAME and REFERENCE are both empty: the identifier would be
%                  invented (the caller carries; carry-048)
%     'reference'  REFERENCE is neither one number nor one text (an array, a
%                  struct, ...): no NDI writer produces it (the caller
%                  carries; carry-120)
%     'name'       NAME is not text
%
%   See also did2.convert.elementNameReferenceApart,
%            did2.convert.elementLocalIdentifier, did2.convert.migrators_j.element.

arguments
    name
    reference = []
end

localId = '';
problem = '';
if isstring(name) && isscalar(name)
    name = char(name);
end
if isempty(name) && ~ischar(name)
    name = '';
end
if ~ischar(name) || (~isempty(name) && ~isrow(name))
    problem = 'name';
    return;
end
[refText, ok] = referenceText(reference);
if ~ok
    problem = 'reference';
    return;
end
if isempty(refText)
    if isempty(name)
        problem = 'empty';
        return;
    end
    localId = name;
    return;
end
localId = [name ' | ' refText];
end

function [s, ok] = referenceText(r)
% the reference as the handle writes it; '' for no reference
s = '';
ok = true;
if isempty(r) && ~isstruct(r) && ~iscell(r)
    return;   % [] or '' or ""
end
if isstring(r) && isscalar(r)
    r = char(r);
    if isempty(r)
        return;   % ""
    end
end
if ischar(r) && isrow(r)
    s = r;
    return;
end
if (isnumeric(r) || islogical(r)) && isscalar(r) && isreal(r)
    x = double(r);
    if isfinite(x) && x == round(x)
        s = int2str(x);
    else
        s = num2str(x, 17);
    end
    return;
end
ok = false;
end
