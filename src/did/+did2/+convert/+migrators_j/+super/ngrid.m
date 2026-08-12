function v2Body = ngrid(preBody)
%NGRID Brainstorm-J SUPERCLASS migrator: carry the did_v1 `ngrid` block VERBATIM.
%
%   STATUS, CORRECTED 2026-08-12. THIS BLOCK READ "NOT RUN ... nothing here has
%   been executed ... [the unit tests] are also unrun". That was true when it was
%   WRITTEN (674f328, 2026-08-10, in a container with no MATLAB) and has been
%   false since the next CI run. It is corrected rather than softened because
%   "not run" is the reassuring direction for a migrator: it invites the next
%   reader to discount a green gate and re-derive work that is already pinned.
%
%   THIS FUNCTION RUNS ON EVERY QUICK GATE. Three links, each with its output:
%
%     1. .github/workflows/test-migrators-quick.yml:273 selects by PACKAGE, not
%        by a hand-maintained list:
%            suite = TestSuite.fromPackage("did2.unittest", "IncludingSubpackages", true);
%            suite = suite(~contains(names, "testCorpus"));
%     2. tests/+did2/+unittest/testNgridCoordinates.m sits in that package, its
%        name contains no "testCorpus", and it calls THIS function by name:
%            :58  out = did2.convert.migrators_j.super.ngrid(v1NgridBody());
%            :71  out = did2.convert.migrators_j.super.ngrid(b);
%            :82  verifyError(testCase, @() did2.convert.migrators_j.super.ngrid(b), ...
%        and at :110/:126/:139 drives did2.convert.v1_to_v2 at TargetVersion
%        'V_eta', so the DISPATCHER is under test too, not just the function.
%     3. run 31624396648, head 9fd6593, job "Migrator transform tests (no
%        corpora)", conclusion success:
%            ================ VERDICT: quick migrator tests ================
%              tests run       1167
%              passed          1167
%              FAILED             0
%
%   WHAT IS STILL UNMEASURED, so this correction does not overshoot: the CORPUS
%   rung. schemas/V_eta_coverage_ledger.json carries ngrid as
%   `disposition: in_progress` with `targets: []`, and did-schema's confirm sheet
%   renders its corpus column `not measured`. Unit-green is not corpus-proven and
%   nothing here claims it is.
%
%   Selected by did2.convert.v1_to_v2 (applySuperclassMigrators) in place of
%   +did2/+convert/+migrators/ngrid.m whenever TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY A V_eta OVERRIDE EXISTS AT ALL
%   ---------------------------------------------------------------------
%   The superclass pass was never bypassed by the migrators_j split, so the
%   V_delta ngrid migrator kept running under V_eta. Its job is the V_delta
%   reshape:
%
%       data_dim  -> dim_sizes
%       (derived) -> ndims = numel(data_dim)
%       rmfield coordinates
%       rmfield data_size
%
%   Under V_delta that is correct -- V_delta's ngrid schema declares ndims and
%   dim_sizes and has nowhere to put the other two. Under V_eta it is a data
%   loss with no upside: it runs BEFORE the concrete J migrator, so
%   `coordinates` was already gone by the time migrators_j.ontology_image saw
%   the body, on every ontologyImage document and on every hartley_calc
%   document (>=210 in the 20211116 corpus, testMigrators.m:457).
%   testMigratorsJ's own vintage-B test says so in a comment: "in the real
%   pipeline the ngrid SUPERCLASS migrator runs first and deletes it. That
%   deletion is a known, separate data loss."
%
%   ---------------------------------------------------------------------
%   THE did_v1 GROUND TRUTH  (NDI origin/main, read 2026-08-10)
%   ---------------------------------------------------------------------
%     database_documents/data/ngrid.json
%         "ngrid": { "data_size": "", "data_type": "",
%                    "data_dim": "",  "coordinates": "" }
%         superclasses [base]; NO depends_on; NO files
%     schema_documents/data/ngrid_schema.json
%         data_size   integer  "The size of each sample in bytes"
%         data_type   string   "The data type (float32, uint16, etc)"
%         data_dim    matrix   "Vector with the dimensions of the data"
%         coordinates matrix   "Not sure"
%     the ONLY writer: +ndi/+fun/+data/mat2ngrid.m -- sets exactly those four,
%         and NOTHING in ndi_common mentions `ndims` or `dim_sizes`.
%
%   So this migrator has nothing to rename. It carries the block through and
%   the V_eta `ngrid` tombstone declares those four names (build_v_eta.py).
%   The schema half and this file are LOCKSTEP: either one alone quarantines
%   every consumer -- the tombstone alone would meet a V_delta-reshaped block,
%   this file alone would hand four undeclared fields to the strict-fields
%   check in +did2/+schema/cache.m:699.
%
%   ---------------------------------------------------------------------
%   WHERE `coordinates` IS GOING, AND WHY IT IS NOT GOING THERE YET
%   ---------------------------------------------------------------------
%   DECIDED (V_eta_image_model_plan.md, signed 2026-08-08):
%
%       ngrid.data_type   -> subject_statement.datum_type
%       ngrid.data_dim    -> one axis entry per dimension (`n` each)
%       ngrid.coordinates -> split by data_dim, one slice per axis,
%                            into axes[k].values
%       ngrid.data_size   -> DROPPED (bytes-per-element is datum_type restated)
%
%   `axes[].values` belongs to the data_body tier (#45), which is BLOCKED ON
%   #32 (binding governance). Until it exists there is nowhere to put the
%   coordinates -- so they RIDE THROUGH on the document rather than being
%   deleted. That is the whole change: a deferral you can see, instead of a
%   deletion you cannot.
%
%   NOTE the coordinates are LOSSLESS-BY-ACCIDENT today, not by design.
%   `mat2ngrid(X, c1, ..., cn)` is a documented signature that stores REAL
%   positions, but the one in-tree caller (imageDocMaker.m:121) passes a single
%   argument, so ontologyImage documents carry the default index vector. That
%   is a fact about today's writers. It is not a licence to delete the field,
%   and the corpora are a sample.
%
%   ---------------------------------------------------------------------
%   THE GUARD
%   ---------------------------------------------------------------------
%   A block presenting `dim_sizes` or `ndims` cannot have come from a did_v1
%   document -- both are the V_delta migrator's OUTPUT and neither appears in
%   any NDI template, schema or writer. Reaching here with one means either the
%   V_delta superclass migrator ran first (a dispatcher regression) or the body
%   was built from a DID-side schema instead of a real document -- the exact
%   mistake that hid the ontology_image and distance_metadata bugs. Erroring
%   quarantines it visibly; carrying it would produce a block the tombstone
%   cannot describe, which fails later and further away.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'ngrid') || ~isstruct(v2Body.ngrid)
    return;
end

block = v2Body.ngrid;

vdeltaOnly = intersect({'dim_sizes', 'ndims'}, fieldnames(block));
if ~isempty(vdeltaOnly)
    error('did2:convert:ngridVDeltaShape', ...
        ['ngrid block presents the V_delta output shape (%s), which no ' ...
         'did_v1 document has: NDI declares exactly {data_size, data_type, ' ...
         'data_dim, coordinates} and mentions neither name anywhere in ' ...
         'ndi_common. A V_eta body must carry the v1 field names -- check ' ...
         'that the fixture was built from the writer and not from a ' ...
         'DID-side schema.'], strjoin(vdeltaOnly, ', '));
end

% Nothing to do. Stated as an explicit no-op rather than an empty function so
% the "carry it verbatim" decision is legible at the call site.
v2Body.ngrid = block;
end
