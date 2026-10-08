function bodies = binaryseries_parameters(preBody)
%BINARYSERIES_PARAMETERS Brainstorm-J migrator: did_v1 binaryseries_parameters --
%   a GUARDED PASSTHROUGH that normalises the template's own placeholders.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT RUN. There is no MATLAB in the container this was written in, so
%   nothing here has been executed. The claims below are read off NDI
%   `origin/main` and off +did2/+schema/cache.m, both quoted with line numbers;
%   the gate is tests/+did2/+unittest/testMiscSingletons.m.
%
%   ---------------------------------------------------------------------
%   WHAT THIS CLASS IS, AND WHY IT IS ONLY A PASSTHROUGH
%   ---------------------------------------------------------------------
%   TEAM-SIGN-OFF (did-schema/schemas/V_eta_go_forward_class_audit.md, jess
%   2026-08-09) retires `binaryseries_parameters` INTO THE data_body MODEL:
%
%     time_type                 -> the time axis's `datum_type`
%     data_type                 -> subject_statement.datum_type
%     data_dim                  -> the axis count
%     samples_regular_intervals -> the axis `regular` flag
%     time_size / data_size     -> implied by their datum_type
%
%   THE PARAGRAPH THAT STOOD HERE SAID "NONE OF THOSE SLOTS EXIST YET ... #45,
%   which is BLOCKED ON #32; `axes[]`, `datum_type` and `regular` are unbuilt".
%   THAT IS STALE. #45 IS SIGNED (2026-08-14) AND THREE OF THE FOUR SLOTS ARE
%   NOW BUILT. The passthrough still stands -- see the second blocker below --
%   but NOT for the reason the old text gave, and the correction is written out
%   rather than edited away because it points the direction this project's
%   errors usually do not: it claimed LESS built than exists, and a reader
%   acting on it would report the whole data_body tier as unlanded.
%
%   RE-MEASURED 2026-08-17, same method as the 2026-08-12 sweep it replaces
%   (every field declaration walked, nested ones included):
%
%     DENOMINATOR: 247 json file(s) under did-schema schemas/V_eta/ read
%       leaf field `axes`        : 4  subject_statement.axes  <- NEW MOUNT
%                                     sampled_body.axes
%                                     acquisition_epoch.axes, image.value.axes
%       leaf field `datum_type`  : 1  subject_statement.datum_type
%                                     char, enum of 14 (uint8..bool)
%       leaf field `datum`       : 0  <- collapsed, as the plan decided
%       leaf field `sample_time` : 1  subject_interaction.sample_time
%                                     (sampled_body.sample_time is GONE)
%       axis subfields, IDENTICAL on both mounts (10):
%         variable unit source_unit approximate n regular origin spacing
%         values labels
%
%   So, against the four mappings the signature names:
%
%     data_type                 -> subject_statement.datum_type    EXISTS
%     data_dim                  -> the axis count (numel(axes))    EXISTS
%     samples_regular_intervals -> the axis `regular` flag         EXISTS
%                                  (a BOOLEAN now, not the old char
%                                  `regularity`; the three encodings really
%                                  did collapse into one)
%     time_type                 -> the time axis's `datum_type`    DOES NOT
%                                                                  EXIST
%
%   THE ONE THAT DID NOT LAND IS THE AXIS'S OWN `datum_type`, and it is not an
%   oversight of this migrator's: it is the 2026-08-09 ADDENDUM to
%   V_eta_data_body_model_plan.md ("the axis carries its own `datum_type`"),
%   which THIS CLASS is what surfaced -- the plan says so in its own words,
%   "Found in the misc-singletons sign-off review, from
%   `binaryseries_parameters`, which declares TWO independent byte encodings
%   where this plan had one". The signed axis entry was built with 10
%   subfields and the addendum's eleventh is not among them, on either mount.
%   Until it is, `time_type` has nowhere to go, and the plan's own words for
%   that outcome are that the fold "would have had to drop the timestamp
%   encoding ... a real limit, not a lossless fold".
%
%   Naming which FIELD is blocked rather than which item number is blocked is
%   deliberate; see did-schema V_eta_OPEN_WORK.md row #106.
%
%   ---------------------------------------------------------------------
%   AND A SECOND BLOCKER, WHICH #45 DOES NOT LIFT -- IT IS NOW THE ONLY ONE
%   THAT MATTERS. RECORDED, NOT RESOLVED.
%   ---------------------------------------------------------------------
%   The section above used to read as though `axes[]`/`datum_type` were the
%   only thing in the way -- so that the fold became a straightforward build
%   the day #45 landed. #45 HAS NOW LANDED AND THE FOLD IS STILL UNBUILDABLE,
%   which is exactly what that prediction was for. The signed targets are
%   `subject_statement` +
%   `sampled_body` (did-schema V_eta_coverage_ledger.json, `decided_targets`),
%   and both require something this class has never carried.
%
%   THE SOURCE HAS NO EDGES AT ALL. All three declarations agree, which is
%   rare enough to be worth writing out:
%
%     NDI origin/main database_documents/data/binaryseries_parameters.json
%         no `depends_on` key at all
%     NDI origin/main schema_documents/data/binaryseries_parameters_schema.json
%         "depends_on": []   -- and "file": []
%     did-schema schemas/V_eta/stable/binaryseries_parameters.json
%         "depends_on": []
%
%   And there is no writer anywhere to disagree with them (below), so the
%   ground-truth rule cannot overturn this the way it overturns a template.
%   There is no element_id, no subject_id, and NOTHING TO JOIN ON -- not here,
%   and not in a batch post-pass either, which is the usual escape hatch for
%   exactly this shortfall (jSessionAnchor, ensembleMembership). A pass that
%   sees the whole migrated-id graph still needs a key INTO that graph, and
%   this class carries none.
%
%   WHAT THE TARGETS DEMAND, re-read off the built schemas 2026-08-17 rather
%   than recalled:
%
%     subject_statement.subject_id   mustBeNonEmpty TRUE   -> subject
%     subject_statement.variable     mustBeNonEmpty TRUE   (ontology_term)
%     sampled_body.statement         mustBeNonEmpty TRUE   -> subject_statement
%                                    (inherited: the edge is declared on the
%                                     abstract parent data_body, and sampled_body
%                                     itself now declares only `filter_id`)
%
%   AND A THIRD FACT, WHICH NOTHING HAD RECORDED AND WHICH BITES BEFORE EITHER
%   OF THOSE: `subject_statement` IS ABSTRACT, so it cannot be minted at all.
%
%     did-schema schemas/V_eta/stable/subject_statement.json
%         "document_class": { ..., "abstract": true }
%     +did2/+schema/cache.m:794-796   validateDocument raises
%         did2:validation:abstractInstantiation for any document naming a class
%         whose header carries abstract == true
%
%   So the target the ledger records by name is not instantiable even GIVEN a
%   subject and a `variable`. Something concrete has to be chosen from the 83
%   classes whose chain reaches `subject_statement` -- 5 of them abstract
%   (subject_assertion / _calculation / _interaction / _manipulation /
%   _observation) and 78 concrete, every one of which is a NAMED QUANTITY
%   (`voltage_observation`, `count_observation`, ...). Choosing among 78
%   quantities for a document that measures nothing is the same question as
%   inventing `variable`, arriving through the class name instead of the field.
%   That is the same shape as the `timed_sequence` abstract flag recorded in
%   did-schema CLAUDE.md, and it is a modelling decision, not plumbing.
%
%   So folding today would mint a statement about NOBODY carrying an invented
%   `variable`. That is the image_stack husk exactly (4,563
%   `image_observation.subject_id` empties) -- except it would no longer even
%   be a quiet husk: #37 RequiredDependencies is ARMED BY DEFAULT, so every
%   such document QUARANTINES instead of validating clean. Grep
%   `RequiredDependencies` in +did2/+schema/cache.m: the defaults table says
%   "ARMED -- 7,233 measured cost, ON PURPOSE", and strictMode sets it from
%   `~envFlagIsOff('DID_ENFORCE_REQUIRED_DEPENDENCIES')`, i.e. ON unless
%   explicitly disabled -- the opposite polarity from #32's `envFlag`.
%
%   `variable` IS THE HARDER HALF, AND IT IS NOT PLUMBING. The six fields are
%   BYTE LAYOUT -- element widths, dtypes, dimensionality, sampling regularity.
%   There is no measured quantity here for a statement to be ABOUT. Note that
%   the signature is consistent with that: it routes the fields onto an axis
%   and onto "the statement's" datum_type, i.e. onto A STATEMENT THAT ALREADY
%   EXISTS FOR THE SERIES THIS METADATA DESCRIBES. It does not ask for a
%   statement of this class's own.
%
%   AND THE BODY WOULD HAVE NO BYTES. The NDI schema declares "file": [] and
%   the template carries no file_list, so a `sampled_body` minted from this
%   document would be payload-free -- +did2/+validate/fileList.m would count it
%   as `declared_but_absent` for `sampled_body|body_data`. (That audit is
%   report-only, so it would not gate; it would just be one more instrument
%   quietly recording a husk.)
%
%   THIS IS AN OPEN TEAM QUESTION AND IT IS NOT THIS FILE'S TO SETTLE
%   (Operating Rule 4). WHICH statement do these parameters attach to? Nothing
%   on the document says. That prediction has now been TESTED rather than
%   argued: #45 landed on 2026-08-14 and the fold is no closer, because the
%   question was never about slots. If the answer turns out to be "nothing
%   links them", then the class is a PERMANENT passthrough -- a different
%   disposition from the "deferred" one everybody currently reads off the
%   ledger. DO NOT RESOLVE IT BY MINTING A SUBJECT.
%
%   THE QUESTION HAS A SECOND HALF NOW, and it is smaller and answerable
%   without a corpus: does the axis entry still get the `datum_type` the
%   2026-08-09 addendum gave it? Three of the signature's four mappings landed
%   with #45 and that one did not. Whether it was dropped on purpose or simply
%   missed, `time_type` has no destination until it is settled -- and it is a
%   did-schema question, not a migrator one, so it is recorded here and left.
%
%   THE LEDGER'S RUNG 3 IS THEREFORE CORRECT, AND DELIBERATE. Its row reads
%   stage 2, `blocked_by: 3, state: no`, "the decided target(s)
%   `subject_statement`, `sampled_body` are not all among what the migrator
%   emits today". That is this migrator behaving as designed, not a gap to
%   close. It is recorded here so the next reader of that row does not read a
%   red rung as an instruction to build.
%
%   ---------------------------------------------------------------------
%   THE DEFECT IT REPAIRS: NO EMPTY INTEGER VALIDATES
%   ---------------------------------------------------------------------
%   NDI's template supplies the CHAR placeholder '' for three fields its own
%   schema types `integer`:
%
%     origin/main:src/ndi/ndi_common/database_documents/data/binaryseries_parameters.json
%        "time_size": "",  "data_size": "",  "data_dim": ""
%     origin/main:src/ndi/ndi_common/schema_documents/data/binaryseries_parameters_schema.json
%        time_size / data_size / data_dim  ->  "type": "integer"
%
%   `ndi.document(...)` fills a new document from that template
%   (+ndi/document.m:54-56, readblankdefinition) and then assigns ONLY the
%   name/value pairs the caller passed, so any field the caller does not set
%   keeps the literal ''.
%
%   V_eta takes its types from the NDI SCHEMA, so the tombstone declares those
%   three `integer`, `mustBeScalar: true`, `mustBeNonEmpty: false`. Against the
%   validator that admits NO empty representation at all:
%
%     +did2/+schema/cache.m:1169   validateTypeShape runs UNCONDITIONALLY on any
%                                  field present in the block -- there is no
%                                  is-empty short circuit ahead of it
%     +did2/+schema/cache.m:1318   case 'integer': ~isnumeric(value) -> error
%                                  did2:validation:typeMismatch    ==> '' FAILS
%     +did2/+schema/cache.m:1200   mustBeScalar && ~isScalarValue -> error
%                                  did2:validation:notScalar       ==> [] FAILS
%
%   So a document carrying the template's own defaults quarantines, and there is
%   no value we could substitute that both validates and invents nothing.
%
%   WHAT DOES VALIDATE IS ABSENCE. cache.m:1157-1163: an ABSENT field that is
%   not `mustBeNonEmpty` returns early, before any type check. And
%   v1_to_v2.ensureClassBlocks pads missing BLOCKS only (v1_to_v2.m:473-478), so
%   it will not put the placeholder back as a 0.
%
%   THEREFORE: an empty char in one of the three integer fields is DROPPED. That
%   is not a coercion and not a guess -- "unset" is exactly what '' means here,
%   and absence is how V_eta spells unset. The other three fields are left
%   verbatim: `time_type`/`data_type` are `string`, which accepts '' (cache.m
%   :1290-1310), and `samples_regular_intervals` is a real 0 in the template.
%
%   A NON-EMPTY char in an integer field is NOT dropped and NOT parsed -- it
%   errors. There is no writer anywhere to tell us what encoding was intended
%   (see below), so '32' -> 32 would be a guess, and this repair track exists to
%   remove guesses. Loud quarantine with a legible reason beats a silent one
%   reading `typeMismatch`.
%
%   ---------------------------------------------------------------------
%   THIS IS NOT A binaryseries_parameters SPECIAL CASE
%   ---------------------------------------------------------------------
%   A sweep of all 91 NDI database_documents templates against the V_eta classes
%   they map to found 33 fields whose TEMPLATE LITERAL cannot validate against
%   the type V_eta declares, across 20 classes. Only three of those classes have
%   no migrator to overwrite the placeholder with a real value, and so are
%   exposed on the passthrough path: this one, `stimulus_parameter` (`value`) and
%   `imageStack_parameters` (`timestamp`). The other two belong to other
%   families; they are reported, not touched here.
%
%   ---------------------------------------------------------------------
%   THE GUARD
%   ---------------------------------------------------------------------
%   A body carrying `num_channels` or `sample_rate` is REJECTED BY NAME. Neither
%   exists in any NDI template or schema -- they are what the OLD V_eta tombstone
%   REQUIRED before the Phase-2b sweep compared it against NDI. Their presence
%   means a fixture or a caller was built from the V_alpha/V_zeta snapshot rather
%   than from a real document, which is the failure this whole track exists to
%   remove. Same guard shape as openminds_stimulus's `stimulus_id`.
%
%   ---------------------------------------------------------------------
%   WHAT NO ONE CAN TELL YOU ABOUT THIS CLASS
%   ---------------------------------------------------------------------
%   There is NO WRITER. Re-run 2026-08-17, and the DENOMINATOR has moved while
%   the result has not: 1471 files tracked on NDI origin/main (was 1467), 1005
%   of them .m (was 1002); `git grep -il binaryseries origin/main` matches 3
%   files and NONE is a .m -- the template, its schema, and
%   ndiDocumentAttributes.json. `git grep -il binary_series origin/main`
%   matches 0, so the underscore spelling is not hiding one either (the
%   `demo_ndi` failure was exactly a grep that could not have matched). And no
%   corpus has ever contained one. Per the standing rule that the corpora are a
%   SAMPLE, that is not licence to skip the class; it is the reason this migrator
%   normalises rather than models.
%
%   The id is preserved: the body is passed through, so base.id is untouched.
%
%   See did-schema/schemas/V_eta_go_forward_class_audit.md ("MISC SINGLETONS")
%   and V_eta_data_body_model_plan.md (the addendum that gives the axis its own
%   `datum_type`, which this class is what surfaced).

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

if isfield(preBody, BLOCK) && isstruct(preBody.(BLOCK))
    for f = {'time_size', 'data_size', 'data_dim'}
        name = f{1};
        if ~isfield(preBody.(BLOCK), name); continue; end
        v = preBody.(BLOCK).(name);
        if isnumeric(v) || islogical(v); continue; end
        if ~(ischar(v) || isstring(v))
            error('did2:convert:binaryseriesParametersBadType', ...
                ['binaryseries_parameters.%s is a %s; NDI''s schema types it ' ...
                 '`integer` and its template''s placeholder is the empty char. ' ...
                 'No rule exists for this shape.'], name, class(v));
        end
        if isempty(strtrim(char(v)))
            % The template's own "unset" placeholder. Absence is how V_eta
            % spells unset, and it is the only spelling that validates.
            preBody.(BLOCK) = rmfield(preBody.(BLOCK), name);
        else
            error('did2:convert:binaryseriesParametersCharInteger', ...
                ['binaryseries_parameters.%s carries the non-empty char ''%s'' ' ...
                 'in a field NDI''s schema types `integer`. It is NOT parsed: no ' ...
                 'writer exists anywhere in NDI for this class, so nothing can ' ...
                 'say what encoding was intended, and guessing is what this ' ...
                 'repair track removes.'], name, char(v));
        end
    end
end

bodies = {preBody};
end
