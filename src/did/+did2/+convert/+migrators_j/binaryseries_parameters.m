function bodies = binaryseries_parameters(preBody)
%BINARYSERIES_PARAMETERS Brainstorm-J migrator: did_v1 binaryseries_parameters --
%   CARRIED whole as v1, needs_mapping (the document is returned UNCHANGED).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   [binaryseries parameters carried] (Decided by Jess Haley, 2026-10-29,
%   did-schema V_eta_go_forward_class_audit.md): "a v1 `binaryseries_parameters`
%   (no edges; at NDI-matlab main 441530d0 only a template, a schema and an
%   attributes entry name it, no `.m` writer) is carried whole as v1
%   `needs_mapping`: each dataset says which data body it describes". It answers
%   docs/V2_PLAN.md G27 for [binaryseries parameters fold as decided] (Jess
%   Haley, 2026-10-27: the class folds into the data body model as
%   TEAM-SIGN-OFF [misc singletons] decided, once the data body it describes can
%   be found). Nothing on the document names that body: NDI's template has no
%   `depends_on`, its schema declares "depends_on": [] and "file": [], and no NDI
%   writer exists to say otherwise. So the generic stage converts none.
%
%   THE REGISTER ROW. The decision asks for a did-schema register row, which
%   does not exist yet: the carry note cites none and its marker says `none`
%   (tools/check_carry_citations.py lists it), until the row is added and the
%   note names it.
%
%   WHAT CHANGED, 2026-10-29. Until this decision the migrator was a guarded
%   PASSTHROUGH that dropped the template's empty-char placeholders for the
%   three integer fields (time_size, data_size, data_dim) and refused a
%   non-empty char in one of them. A carry is the untouched v1 source, checked
%   against NDI's v1 templates ([carried v1 validates against NDI templates],
%   Jess Haley, 2026-10-27), so it needs neither: both are gone. The header that
%   explained them (the fold's blockers, the placeholder analysis) is in this
%   file's history (DID-matlab V2 d121479b).
%
%   KEPT, AND CHECKED FIRST:
%     - THE GUARD. A body carrying `num_channels` or `sample_rate` is refused by
%       name (did2:convert:binaryseriesParametersInventedField). Neither exists
%       in any NDI template or schema; they are what the pre-Phase-2b V_eta
%       tombstone required, so their presence means a fixture or caller built
%       from the V_alpha/V_zeta snapshot, not a v1 document.
%     - READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley,
%       2026-10-26 [migrators read raw v1]). What universalRenames would have
%       discarded carries, carry-049; a field, block or edge outside the
%       template carries, carry-100 (private/jRawAccount, jRawCarry). Those
%       notes come before the needs_mapping one, so a malformed document is
%       read as malformed.
%
%   did2.convert.roundtrip.check reads a carry as the v1 document itself;
%   testRawV1RoundTripDemo compares the two.

arguments
    preBody (1,1) struct
end

BLOCK = 'binaryseries_parameters';

for invented = {'num_channels', 'sample_rate'}
    if isfield(preBody, BLOCK) && isstruct(preBody.(BLOCK)) ...
            && isfield(preBody.(BLOCK), invented{1})
        error('did2:convert:binaryseriesParametersInventedField', ...
            ['binaryseries_parameters body carries a `%s` field, which no NDI ' ...
             'template or schema declares -- it is what the pre-Phase-2b V_eta ' ...
             'tombstone required. This shape can only come from the V_alpha/' ...
             'V_zeta snapshot or a fixture built against it.'], invented{1});
    end
end

% THE RAW READ (see READS RAW v1 above)
[~, collision, unplaced] = jRawAccount(preBody, struct(BLOCK, {{'time_size', 'time_type', ...
    'data_size', 'data_type', 'data_dim', 'samples_regular_intervals'}}), {});
if jRawCarry('binaryseries_parameters', preBody, collision, unplaced, 'carry-100')
    bodies = {preBody};
    return;
end

% [binaryseries parameters carried] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): carried whole as v1, needs_mapping
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: none (a binaryseries_parameters: which data body it describes;
%   [binaryseries parameters carried] asks for a row, not yet in the register)
did2.convert.reportNote('carried_as_v1', 'binaryseries_parameters', id, ...
    ['needs_mapping: which data body these parameters describe is decided by ' ...
    'each dataset (no edge names it) ([binaryseries parameters carried])']);
bodies = {preBody};
end
