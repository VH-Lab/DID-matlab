function [v1, spec] = openminds(bodies, ctx)
%OPENMINDS The v1 `openminds` document pass 1 passed through unchanged, or the
%   openMINDS `Copyright` did2.convert.resolveOpenmindsCitations emitted.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds(BODIES). Pass 1 passes a bare
%   `openminds` document through unchanged (did2.convert.migrators_j.openminds,
%   a guarded passthrough) for did2.convert.resolveOpenmindsCitations and
%   NDI-matlab's strainAssembly, so BODIES is the one passthrough and V1 is it
%   with v1_to_v2's outbound renames undone (passthroughInverse). A document
%   carried whole as v1 (a field outside the template, carry-100) never reaches
%   this inverse (did2.convert.roundtrip.check compares the carry itself). A
%   document a batch pass assembled into entities is not compared here
%   (did2.convert.roundtrip.wholeBatch counts it changed by a batch pass).
%
%   THE COPYRIGHT. [V1, SPEC] = did2.convert.roundtrip.openminds(BODIES, CTX),
%   in the whole-batch round trip. Decided by Jess Haley, 2026-11-12
%   [copyright from another tool is emitted] (did-schema
%   did_v2_go_forward_class_audit.md): resolveOpenmindsCitations emits a v1
%   openMINDS `Copyright` as the dataset's schema:copyrightYear date
%   assertion, under the Copyright's own id, and each holder as a
%   `copyright_holder` (schema:copyrightHolder) relation from the dataset.
%   When BODIES is that one assertion, V1 is the Copyright in the shape
%   ndi.database.fun.openMINDSobj2ndi_document writes:
%
%     base.id, session_id, datestamp   the assertion's (rebuildBase)
%     base.name                        '' (the writer sets none)
%     openminds.fields.year            the date's year, a number
%     openminds.fields.holder          {'ndi://<id>', ...}, the parents of the
%                                      dataset's copyright_holder relations in
%                                      CTX, in batch order (the relation is
%                                      not ordered, so the order of several
%                                      holders is the batch's)
%     depends_on openminds_1..n        those holder ids, in the same order
%     openminds.openminds_type         https://openminds.om-i.org/types/Copyright
%     openminds.matlab_type            openminds.core.data.Copyright
%
%   NOT REBUILT, and so reported by the round trip when v1 states them:
%   `openminds_id` (no v2 document keeps an openMINDS instance id of the
%   citation graph), another IRI vintage of `openminds_type`, another
%   `matlab_type` namespace.
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.openminds,
%            did2.convert.resolveOpenmindsCitations.

arguments
    bodies cell
    ctx = []
end

if isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'assertion')
    [node, ~] = termParts(getIn(bodies{1}, 'statement', 'variable'));
    if sameCurie(node, 'schema:copyrightYear')
        [v1, spec] = copyrightInverse(bodies{1}, ctx);
        return;
    end
end
[v1, spec] = passthroughInverse(bodies, 'openminds');
end

function [v1, spec] = copyrightInverse(st, ctx)
% the v1 openMINDS Copyright the year assertion ST and CTX's holder relations rebuild
spec = emptySpec();
base = rebuildBase(st);
[kind, value] = statementValue(st);
year = [];
if ~strcmp(kind, 'date')
    spec.unplaced{end+1} = sprintf('the assertion''s value kind is "%s", not date', kind);
else
    instant = getIn(value, 'instant');
    year = str2double(char(string(firstOf(instant))));
    if isnan(year); year = []; end
end
dataset = edgeIds(st, 'entity_id');
holders = {};
if ~isempty(dataset)
    for k = ctxReferrers(ctx, dataset{1})
        b = ctx.docs{k};
        if ~strcmp(classNameOf(b), 'directed_relation') ...
                || ~isequal(edgeIds(b, 'child_id'), dataset(1))
            continue;
        end
        if strcmp(did2.build.vocabularyHandle('relation', ...
                getIn(b, 'directed_relation', 'relation')), 'copyright_holder')
            holders = [holders, edgeIds(b, 'parent_id')]; %#ok<AGROW>
        end
    end
end
if isempty(ctx)
    spec.unplaced{end+1} = 'no batch index: the copyright holders cannot be read';
end
names = arrayfun(@(k) sprintf('openminds_%d', k), 1:numel(holders), 'UniformOutput', false);
if isempty(holders)
    v1.depends_on = struct('name', {'openminds'}, 'value', {''});
else
    v1.depends_on = struct('name', names, 'value', holders);
end
v1.document_class = struct('class_name', 'openminds');
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
flds = struct();
% a column, as jsondecode reads a JSON list of strings
flds.holder = reshape(cellfun(@(h) ['ndi://' h], holders, 'UniformOutput', false), [], 1);
flds.year = year;
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Copyright', ...
    'matlab_type', 'openminds.core.data.Copyright', 'openminds_id', '');
v1.openminds.fields = flds;
end
