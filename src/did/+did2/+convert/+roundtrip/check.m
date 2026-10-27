function report = check(v1Body, v2Docs)
%CHECK Rebuild a v1 document from what the migration emitted; compare.
%
%   REPORT = did2.convert.roundtrip.check(V1BODY, V2DOCS) takes the RAW v1
%   document V1BODY and every document the migration emitted for it, V2DOCS
%   (a cell of did2.document or structs, a struct array, or one struct: e.g.
%   `result.migrated` of did2.convert.v1_to_v2 on that one document), rebuilds
%   the v1 document from V2DOCS, and compares the rebuilt document with
%   V1BODY field by field.
%
%   WHY. Decided by Jess Haley, 2026-10-26 [migration reliability practices]
%   (a): a round-trip check per class -- each converted document is migrated
%   back to v1 and compared with its source -- built with each class's switch
%   to raw v1 ([migrators read raw v1]). The test it serves is [lossless means
%   round trip] (2026-10-26): a v1 value may be left unwritten only when it is
%   100% recoverable from what V2 keeps.
%
%   HOW THE v1 DOCUMENT IS REBUILT.
%     - CARRIED (V2DOCS is one document stamped 'did_v1'): the carried body
%       IS the v1 document; its stamp is removed when V1BODY had none.
%     - CONVERTED: the class's inverse, did2.convert.roundtrip.<class_name>
%       (class_name as v1 spells it, did2.convert.v1read.readStamp), returns
%       the rebuilt body and a SPEC of what it cannot rebuild exactly:
%         spec.equivalents  struct array {path, values, why}: a v1 field V2
%                           does not keep but that can only have been one of
%                           VALUES (a writer default, or a restatement of a
%                           kept value), each with the decision that allows it
%         spec.same         struct array {path, fn, why} (optional): a v1
%                           field V2 keeps in another notation, compared by
%                           FN(v1Value, rebuiltValue) -> true when both state
%                           the same thing (a CSV table's rows, a CURIE's
%                           prefix case: [spelling is notation], Jess Haley,
%                           2026-10-26), each with the decision that allows it
%         spec.twins        struct array {paths, why} (optional): two or more
%                           v1 spellings of ONE field (e.g. the template's
%                           `location_ontologyNode` and the writer's
%                           `location_ontologyName`, [treatment location name
%                           is the node], Jess Haley, 2026-10-27). The inverse
%                           writes the value under every spelling; a spelling
%                           the v1 document does not hold is not INVENTED
%                           when it holds another of them
%         spec.unplaced     cellstr: emitted content the inverse could not
%                           place (an unexpected document, a wrong type)
%       A class with no inverse is an error (did2:convert:roundtrip:noInverse).
%
%   HOW IT COMPARES. V1BODY is flattened to its leaf fields (a struct array
%   such as `depends_on` by element). For each leaf:
%     matched     the rebuilt document holds the same value at the same path
%     not_set     the v1 value is EMPTY and the rebuilt has nothing there (an
%                 empty template default; [writer default is not set])
%     restated    the v1 value is one of spec.equivalents' values for the path
%     equivalent  spec.same's FN for the path says the rebuilt value states the
%                 same thing in another notation
%     exempt      `document_class.*` except `class_name`, on a CONVERTED
%                 document only: the v1 stamp (template paths, class_version,
%                 superclasses), which V2 replaces with its own and
%                 did2.convert.v1read.readStamp reads; the class name is
%                 compared
%     lost        anything else: V2 does not keep it
%   and every leaf of the rebuilt document V1BODY does not have, with a
%   non-empty value, is INVENTED.
%
%   REPORT fields, the denominator first (Operating Rule 5):
%     fields_inspected  the number of leaf fields of V1BODY
%     class_name, source_id, carried
%     matched, not_set, restated, equivalent, exempt   cellstr of paths
%     lost       struct array {path, v1, rebuilt}
%     invented   cellstr of paths
%     unplaced   cellstr (from the inverse)
%     ok         true when lost, invented and unplaced are all empty
%
%   See also did2.convert.rawV1Classes, did2.convert.roundtrip.subject,
%            did2.convert.roundtrip.subject_group.

arguments
    v1Body (1,1) struct
    v2Docs
end

bodies = asBodies(v2Docs);
stamp = did2.convert.v1read.readStamp(v1Body);
base = did2.convert.v1read.readBase(v1Body);
report = struct('fields_inspected', 0, 'class_name', stamp.class_name, ...
    'source_id', base.id, 'carried', false, 'matched', {{}}, ...
    'not_set', {{}}, 'restated', {{}}, 'equivalent', {{}}, 'exempt', {{}}, ...
    'lost', struct('path', {}, 'v1', {}, 'rebuilt', {}), ...
    'invented', {{}}, 'unplaced', {{}}, 'ok', false);

spec = struct('equivalents', struct('path', {}, 'values', {}, 'why', {}), ...
    'unplaced', {{}});
if isscalar(bodies) && did2.schema.isV1Stamp(bodies{1}, 'Explicit', true)
    report.carried = true;
    rebuilt = bodies{1};
    % the 'did_v1' stamp is the carry's own ([passthrough stays v1: how]):
    % put back the source's stamp, or none when it had none
    hadStamp = isfield(v1Body, 'document_class') && isstruct(v1Body.document_class) ...
        && isfield(v1Body.document_class, 'schema_version');
    if isfield(rebuilt, 'document_class') && isstruct(rebuilt.document_class) ...
            && isfield(rebuilt.document_class, 'schema_version')
        if hadStamp
            rebuilt.document_class.schema_version = v1Body.document_class.schema_version;
        else
            rebuilt.document_class = rmfield(rebuilt.document_class, 'schema_version');
        end
    end
else
    fqn = ['did2.convert.roundtrip.', stamp.class_name];
    if isempty(stamp.class_name) || isempty(which(fqn))
        error('did2:convert:roundtrip:noInverse', ...
            'No round-trip inverse %s for v1 class "%s".', fqn, stamp.class_name);
    end
    [rebuilt, spec] = feval(str2func(fqn), bodies);
end
same = struct('path', {}, 'fn', {}, 'why', {});
if isfield(spec, 'same')
    same = spec.same;
end
report.unplaced = spec.unplaced;

origLeaves = flattenLeaves(v1Body);
report.fields_inspected = numel(origLeaves);
for k = 1:numel(origLeaves)
    lf = origLeaves(k);
    if ~report.carried && startsWith(lf.path, 'document_class') ...
            && ~strcmp(lf.path, 'document_class.class_name')
        report.exempt{end+1} = lf.path;
        continue;
    end
    [rv, found] = resolveSteps(rebuilt, lf.steps);
    if found && sameValue(lf.value, rv)
        report.matched{end+1} = lf.path;
    elseif isEmptyValue(lf.value) && (~found || isEmptyValue(rv))
        report.not_set{end+1} = lf.path;
    elseif isRestated(spec.equivalents, lf.path, lf.value)
        report.restated{end+1} = lf.path;
    elseif found && isSame(same, lf.path, lf.value, rv)
        report.equivalent{end+1} = lf.path;
    else
        if ~found
            rv = '<absent>';
        end
        report.lost(end+1) = struct('path', lf.path, 'v1', {lf.value}, ...
            'rebuilt', {rv});
    end
end

origPaths = {origLeaves.path};
twins = struct('paths', {}, 'why', {});
if isfield(spec, 'twins')
    twins = spec.twins;
end
newLeaves = flattenLeaves(rebuilt);
for k = 1:numel(newLeaves)
    lf = newLeaves(k);
    if any(strcmp(lf.path, origPaths)) || isEmptyValue(lf.value)
        continue;
    end
    if isTwinOfAnOriginal(twins, lf.path, origPaths)
        continue;
    end
    if ~report.carried && startsWith(lf.path, 'document_class')
        continue;
    end
    report.invented{end+1} = lf.path;
end

report.ok = isempty(report.lost) && isempty(report.invented) ...
    && isempty(report.unplaced);
end

% ===================== helpers =========================================

function bodies = asBodies(v2Docs)
if isa(v2Docs, 'did2.document')
    docs = cell(1, numel(v2Docs));
    for k = 1:numel(v2Docs)
        docs{k} = v2Docs(k);
    end
    v2Docs = docs;
elseif isstruct(v2Docs)
    v2Docs = num2cell(reshape(v2Docs, 1, []));
end
if ~iscell(v2Docs)
    error('did2:convert:roundtrip:badInput', ...
        'V2DOCS must be did2.document(s), struct(s) or a cell of them.');
end
bodies = cell(1, numel(v2Docs));
for k = 1:numel(v2Docs)
    d = v2Docs{k};
    if isa(d, 'did2.document')
        d = d.toStruct();
    end
    bodies{k} = d;
end
end

function tf = isTwinOfAnOriginal(twins, path, origPaths)
%ISTWINOFANORIGINAL PATH is one spelling of a field (spec.twins) whose other
%   spelling the v1 document holds.
tf = false;
for k = 1:numel(twins)
    p = twins(k).paths;
    if any(strcmp(p, path)) && any(ismember(setdiff(p, {path}), origPaths))
        tf = true;
        return;
    end
end
end

function tf = isSame(same, path, value, rebuilt)
tf = false;
for k = 1:numel(same)
    if ~strcmp(same(k).path, path)
        continue;
    end
    fn = same(k).fn;
    if fn(value, rebuilt)
        tf = true;
        return;
    end
end
end

function tf = isRestated(equivalents, path, value)
tf = false;
for k = 1:numel(equivalents)
    if ~strcmp(equivalents(k).path, path)
        continue;
    end
    vals = equivalents(k).values;
    for j = 1:numel(vals)
        if sameValue(value, vals{j})
            tf = true;
            return;
        end
    end
end
end
