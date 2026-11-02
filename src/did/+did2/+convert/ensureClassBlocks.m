function body = ensureClassBlocks(body, schemaCacheOverride)
% SCRATCH PROBE (branch claude/W-padding-probe, not for merge): print every
% body the padding changes, with its class and callers, so deleting the
% padding can be measured on every path (pass 1 and the batch passes).
persistent n
before = body;
body = ensureClassBlocksImpl(body, schemaCacheOverride);
if ~isequaln(before, body)
    if isempty(n); n = containers.Map('KeyType', 'char', 'ValueType', 'double'); end
    cls = '<none>';
    try cls = char(body.document_class.class_name); catch, end
    st = dbstack(1);
    callers = strjoin({st(1:min(3, numel(st))).name}, '<');
    what = {};
    if ~isequal(fieldnames(before), fieldnames(body)); what{end+1} = 'blocks'; end
    try
        if ~isequaln(before.document_class.superclasses, body.document_class.superclasses)
            what{end+1} = 'superclasses';
        end
    catch
        what{end+1} = 'superclasses?';
    end
    key = [cls '|' callers '|' strjoin(what, '+')];
    if isKey(n, key); n(key) = n(key) + 1; else; n(key) = 1; end
    c = n(key);
    if c <= 3 || any(c == [10 100 1000 10000 100000])
        fprintf('PADPROBE %d %s\n', c, key);
    end
end
end

function body = ensureClassBlocksImpl(body, schemaCacheOverride)
%ENSURECLASSBLOCKS Give a body exactly the class blocks its schema chain hosts.
%
%   BODY = did2.convert.ensureClassBlocks(BODY, SCHEMACACHE) (SCHEMACACHE
%   [] for the shared cache). The padding step every did2.convert.v1_to_v2
%   output goes through, public so a READ path can apply it to a body that
%   is already at its target without running the whole conversion (NDI's
%   applyReadNormalization). Moved out of v1_to_v2 unchanged, 2026-10-06.
%
% Make sure every class in the V2 schema chain for the body's
% concrete class has a property block in the document, manufacturing
% empty `struct()` blocks for any chain entry that the v1 source did
% not provide. Also rebuilds document_class.superclasses from the
% schema chain plus the value kind the document names, if any; the
% V2 schema chain so the snapshot matches the spec (same set,
% same order, class-name-by-class-name) even when V2 has
% reordered or extended the chain relative to v1. V2's
% validator rejects documents whose chain blocks are missing or
% whose superclasses snapshot drifts from the schema, so this
% padding lets the per-class migrators stay focused on real field
% moves rather than placeholder bookkeeping.
%
% Silent no-op if the schema cache cannot resolve the class chain
% (e.g., the class is unknown to the cache, or the cache itself is
% not configured). In that case validation will catch the underlying
% issue downstream; this function does not raise.
arguments
    body struct
    schemaCacheOverride % a did2.schema.cache, or [] for the shared one
end

if ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isfield(body.document_class, 'class_name')
    return;
end
className = char(body.document_class.class_name);
cache = schemaCacheOverride;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        return;
    end
end
if isempty(cache)
    return;
end
% A statement whose value kind is a mixin (did-schema
% V_eta_entity_composition_plan.md sec. 1, 2026-10-08) lists the kind after
% its class's own chain; that is part of what the document IS, so it is kept,
% with the kind's blocks. A kind that is missing or not a value is left for
% the validator to report.
kind = '';
if ismethod(cache, 'documentValueKind') && isfield(body.document_class, 'superclasses')
    declared = body.document_class.superclasses;
    if isstruct(declared), declared = num2cell(declared); end
    names = cell(1, numel(declared));
    for k = 1:numel(declared)
        if isstruct(declared{k}) && isfield(declared{k}, 'class_name')
            names{k} = char(declared{k}.class_name);
        elseif isstruct(declared{k}) && isfield(declared{k}, 'definition')
            % a RAW v1 superclass entry names its class by its definition
            % path only (did2.convert.rawV1Classes: a switched class's
            % passthrough is not renamed); its name is the path's basename,
            % as universalRenames and did2.convert.v1read.readStamp read it
            [~, names{k}] = fileparts(strrep(char(declared{k}.definition), '\/', '/'));
        else
            names{k} = char(declared{k});
        end
    end
    try
        kind = cache.documentValueKind(className, names);
    catch
        kind = '';
    end
end
try
    if isempty(kind)
        placementInfo = cache.resolvePlacement(className);
        ancestors = cache.superclasses(className);
    else
        placementInfo = cache.resolvePlacementFor(className, kind);
        ancestors = cache.documentAncestors(className, kind);
    end
catch
    return;
end
% Placement-aware: only classes that contribute a body block (per
% V_gamma_SPEC.md "Field placement") get an empty struct manufactured
% for them. An abstract class whose declared fields are all
% `placement: "concrete_class"` (e.g., `calculator`) does NOT
% materialize on the instance body.
for k = 1:numel(placementInfo.blocksContributed)
    cls = placementInfo.blocksContributed{k};
    if ~isfield(body, cls)
        body.(cls) = struct();
    end
end
% Drop stray EMPTY blocks left by v1 for chain classes that the target
% schema does NOT host on the instance. v1 documents carried a property
% block for every class in their hierarchy, including parents that became
% abstract / fieldless in V2 (abstract classes are new
% here). Those arrive as empty structs and would trip the strict
% undeclared-top-level-block check. Only EMPTY such blocks are removed --
% a non-empty one signals real data a migrator must place, so it is left
% to fail loudly rather than be silently dropped.
chainClasses = [reshape(ancestors, 1, []), {className}];
nonContributing = setdiff(chainClasses, placementInfo.blocksContributed);
for k = 1:numel(nonContributing)
    cls = nonContributing{k};
    if isfield(body, cls) && isstruct(body.(cls)) ...
            && (numel(body.(cls)) == 0 || isempty(fieldnames(body.(cls))))
        body = rmfield(body, cls);
    end
end
sc = struct('class_name', {}, 'class_version', {});
for k = 1:numel(ancestors)
    ancDC = cache.getClass(ancestors{k}).document_class;
    sc(end+1) = struct( ...
        'class_name',    char(ancDC.class_name), ...
        'class_version', char(ancDC.class_version)); %#ok<AGROW>
end
body.document_class.superclasses = sc;
end
