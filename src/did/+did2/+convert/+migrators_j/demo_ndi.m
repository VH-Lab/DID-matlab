function v2Body = demo_ndi(preBody)
%DEMO_NDI Brainstorm-J migrator: did_v1 `demoNDI` -> the V_eta `demo` class,
%   1 -> 1 with base.id PRESERVED, `value` carried and `is_mock` FALSE. Part of
%   the 3 -> 1 demo collapse signed by the team on 2026-08-06 (recorded then in
%   did-schema `tools/build_v_eta.py`, deleted 2026-10-21; the class is now
%   `schemas/V_eta/stable/demo.json`); the fold itself is in private/jDemoFold.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS EXISTS: THE SCHEMA HALF LANDED AND THE MIGRATOR HALF DID NOT
%   ---------------------------------------------------------------------
%   did-schema built `schemas/V_eta/stable/demo.json` and DELETED `demo_ndi`,
%   `demo_ndi_mock` and `mock` from the built set. Nothing consumed the three and
%   nothing emitted `demo`:
%
%     DENOMINATOR: 189 .m file(s) under src/did/+did2/+convert
%       quoted literal 'demo'            0 file(s)
%       quoted literal 'demo_ndi'        0 file(s)
%       quoted literal 'demo_ndi_mock'   0 file(s)
%       quoted literal 'mock'            0 file(s)
%
%   So a real document was renamed by universalRenames to `demo_ndi`, matched no
%   migrator, passed through, and found NO SCHEMA of that name -- the image_stack
%   pattern verbatim, which did-schema/CLAUDE.md prices at 4,563 quarantines.
%
%   ---------------------------------------------------------------------
%   THE CLASS IS REAL, AND THE TEAM HAS RULED THAT IT COUNTS
%   ---------------------------------------------------------------------
%   "An example calculator counts as production" (team, 2026-08-12). `demoNDI` is
%   also written outside the calculator, in a SHIPPED package rather than a test
%   directory -- `src/ndi/+ndi/+test/+database/test_ndi_document.m:33`:
%
%       doc = E.newdocument('demoNDI', ... 'demoNDI.value', 5);
%
%   Two construction IDIOMS are in use (`ndi.document(...)` and
%   `session.newdocument(...)`), which is why the sweep behind this migrator
%   greps the BARE CLASS NAME rather than one call shape.
%
%     DENOMINATOR: 1002 .m file(s) on NDI origin/main
%       case-insensitive `demoNDI`   12 file(s)
%       case-insensitive `demo_ndi`   0 file(s)   <- V_eta spelling; NDI is camelCase
%
%   The second line is recorded because this repository has twice reported an
%   absence that was a property of the query, and `demo_ndi` was one of the two:
%   the class was dispositioned DELETE on 2026-08-06 on the evidence "absent from
%   NDI origin/main; referenced by NOTHING", from a grep for a string NDI has
%   never contained.
%
%   ---------------------------------------------------------------------
%   THE COST THE SIGNED DECISION ALREADY RECORDED
%   ---------------------------------------------------------------------
%   `ndi.calc.example.simple.m:99` runs ndi.query('','isa','demoNDIMock','') and
%   `:100,120,157` query `demoNDI.value`. Those are v1-runtime queries against v1
%   documents, in the same category as every other rename in this migration, and
%   the decision names them as a real break rather than glossing them. Nothing in
%   this migrator changes that; it is recorded here so the next reader does not
%   rediscover it as a defect.
%
%   UNVERIFIED: there is no MATLAB in the authoring environment. CI is the first
%   execution of every line here.

%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`demoNDI`, NDI-matlab locked `main` 3cb19a8;
%   no NDI writer at that `main` makes one alone (ndi.calc.example.simple makes
%   demoNDIMock); no corpus holds one, and the template fixes its shape). jDemoFold reads the blocks in v1's spelling (demoNDI, demoNDIMock)
%   or the renamed one. What the renamed path would have discarded is carried,
%   carry-049; a field, block or edge outside the template carries the
%   document, carry-100 (private/jRawAccount, jRawCarry), where the fold
%   refused it before (an error, so a quarantine). did2.convert.roundtrip.demoNDI
%   rebuilds the v1 document; testRawV1RoundTripDemo compares the two.
arguments
    preBody (1,1) struct
end

% is_mock FALSE: a `demoNDI` document does not carry the did_v1 `mock` superclass,
% and false is the value did-schema declares as `demo.is_mock`'s default_value.
% THE RAW READ (see READS RAW v1 above)
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'demoNDI', {{'value'}}, 'files', {{'file_list', 'file_info'}}), {});
if jRawCarry('demo_ndi', preBody, collision, unplaced, 'carry-100')
    v2Body = {preBody};
    return;
end
v2Body = jDemoFold(preBody, false, 'demo_ndi');
end
