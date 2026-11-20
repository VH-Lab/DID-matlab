function ids = regionPartIds(parentId, areaTerm, sideTerm)
%REGIONPARTIDS The computed ids of one region part, from what it is.
%
%   IDS = did2.convert.regionPartIds(PARENTID, AREATERM, SIDETERM) for the
%   part of PARENTID (the subject, or a slice) at the region AREATERM, on the
%   side SIDETERM ([] or an empty term for none). IDS is a struct:
%
%     key               '<parent id>|<region node, lowercased>' and, with a
%                       side, '|side:<side node, lowercased>' (a term with no
%                       node is keyed 'name:<its name, lowercased>')
%     part              the part entity's id
%     kind              its anatomical-structure (kind) assertion's id
%     laterality        its Laterality assertion's id ('' with no side)
%     relation          its `part_of` relation's id
%     local_identifier  '<first 8 of the parent id>_<region>[_<side>]', the
%                       entity's required local identifier
%
%   WHY. Decided by Jess Haley, 2026-11-19 [region part ids computed] (3)
%   (did-schema did_v2_go_forward_class_audit.md): "the part, its kind
%   assertion, its laterality assertion and its `part_of` relation each take a
%   computed document id from `did2.convert.mintId` in a context keyed on
%   `<subject id>|<region node, lowercased>|side:<side node>`, the key NDI's
%   `pathSPromotion` already uses." So every document naming one region of one
%   subject on one side yields the same part ([site scaffolding not a loss]
%   (2)), whichever source, pass or repository mints it: NDI-matlab's
%   ndi.migrate.internal.pathSPromotion takes its part ids from this function
%   too. The key is NDI's partKey exactly: with no side the '|side:' part is
%   left out, as there.
%
%   Each id is mintId's for one ROLE ('tissue part', 'part kind', 'part
%   laterality', 'part_of'), the first of its role in a context opened on KEY
%   alone, so it depends on nothing but the part's identity: not on the source
%   that asked for it, the order documents are read in, or the pass.
%
%   See also did2.convert.regionPart, did2.convert.mintId,
%            did2.convert.lateralityOf.

arguments
    parentId
    areaTerm
    sideTerm = []
end

parentId = char(parentId);
areaKey = termKey(areaTerm);
sideKey = termKey(sideTerm);
if isempty(parentId) || isempty(areaKey)
    error('did2:convert:regionPartIds:noIdentity', ...
        'A region part needs its parent id and a region term (parent "%s", region "%s").', ...
        parentId, areaKey);
end
key = [parentId '|' areaKey];
if ~isempty(sideKey)
    key = [key '|side:' sideKey];
end

depth = did2.convert.mintId('-depth');
did2.convert.mintId('-push', key);
restore = onCleanup(@() did2.convert.mintId('-popto', depth)); %#ok<NASGU>
ids = struct('key', key, ...
    'part', did2.convert.mintId('tissue part'), ...
    'kind', did2.convert.mintId('part kind'), ...
    'laterality', '', ...
    'relation', did2.convert.mintId('part_of'), ...
    'local_identifier', '');
if ~isempty(sideKey)
    ids.laterality = did2.convert.mintId('part laterality');
end

name = safeName(areaTerm);
if ~isempty(sideKey)
    name = [name '_' safeName(sideTerm)];
end
short = parentId;
if numel(short) > 8; short = short(1:8); end
lid = regexprep([short '_' name], '^_+|_+$', '');
if isempty(lid); lid = ids.part; end
ids.local_identifier = lid;
end

function k = termKey(t)
%TERMKEY NDI pathSPromotion's regionKey: the node, case-folded; else the name.
k = '';
if ~isstruct(t) || isempty(t)
    return;
end
node = ''; name = '';
if isfield(t, 'node') && ~isempty(t(1).node); node = strtrim(char(t(1).node)); end
if isfield(t, 'name') && ~isempty(t(1).name); name = strtrim(char(t(1).name)); end
if ~isempty(node)
    k = lower(node);
elseif ~isempty(name)
    k = ['name:' lower(name)];
end
end

function nm = safeName(t)
%SAFENAME NDI pathSPromotion's safeName: the label (else the node) as a name.
raw = '';
if isstruct(t) && ~isempty(t)
    if isfield(t, 'name') && ~isempty(t(1).name); raw = char(t(1).name);
    elseif isfield(t, 'node') && ~isempty(t(1).node); raw = char(t(1).node); end
end
if isempty(raw); raw = 'part'; end
nm = lower(regexprep(raw, '[^A-Za-z0-9]+', '_'));
nm = regexprep(nm, '^_+|_+$', '');
if isempty(nm); nm = 'part'; end
end
