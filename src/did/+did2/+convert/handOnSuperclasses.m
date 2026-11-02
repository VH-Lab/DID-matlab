function body = handOnSuperclasses(body, schemaCacheOverride)
%HANDONSUPERCLASSES Write V2's superclass list on a document pass 1 hands on.
%
%   BODY = did2.convert.handOnSuperclasses(BODY, SCHEMACACHE) (SCHEMACACHE []
%   for the shared cache). The one step on pass 1's hand-on path: a v1
%   document whose migrator hands it on unchanged to a later batch pass
%   (did2.convert.v1_to_v2, HAND_ON_CLASSES: syncrule, epochfiles_ingested,
%   stimulus_response_scalar, stimulus_response_scalar_parameters_basic,
%   openminds) keeps every field as v1 wrote it; only its
%   document_class.superclasses is rewritten from v1's form ({definition}
%   paths) into V2's ({class_name, class_version}, did2.build.superclasses),
%   and an EMPTY property block v1 wrote for a parent class that V2 hosts no
%   block for (an abstract parent, e.g. `stimulus_response_scalar_parameters`)
%   is dropped. A NON-empty such block is left for validation to report.
%
%   Decided by Jess Haley, 2026-11-02 [handed-on classes carried at the end]
%   (2) (did-schema docs/plans/did_v2_go_forward_class_audit.md;
%   docs/V2_PLAN.md G98 (a)): "a small named step on the hand-on path writes
%   V2's superclass list for the five classes pass 1 hands on unchanged ...
%   and `ensureClassBlocks` is deleted". This is that step; it replaces what
%   the padding did for these five (DID-matlab #364 measured: the superclass
%   list, and one empty v1 parent block).
%
%   Errors when the schema does not know the class (did2.schema.cache), so a
%   hand-on class that lost its schema is a quarantine, not a silent pass.
%
%   See also did2.build.superclasses, did2.convert.v1_to_v2.

arguments
    body (1,1) struct
    schemaCacheOverride = []
end

cache = schemaCacheOverride;
if isempty(cache)
    cache = did2.schema.cache.shared();
end
className = char(body.document_class.class_name);
body.document_class.superclasses = did2.build.superclasses(className, ...
    'SchemaCache', cache);

hosted = cache.resolvePlacement(className).blocksContributed;
chain = [reshape(cache.superclasses(className), 1, []), {className}];
for cls = setdiff(chain, hosted)
    name = cls{1};
    if isfield(body, name) && isstruct(body.(name)) ...
            && (isempty(body.(name)) || isempty(fieldnames(body.(name))))
        body = rmfield(body, name);
    end
end
end
