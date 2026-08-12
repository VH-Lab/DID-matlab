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
%   NONE OF THOSE SLOTS EXIST YET. That fold is the data_body tier (#45), which
%   is BLOCKED ON #32; `axes[]`, `datum_type` and `regular` are unbuilt, so
%   folding today would mean inventing them. Until #45 lands the document must
%   therefore reach validation in its did_v1 shape, against the V_eta source
%   tombstone -- and that is what this migrator exists to make survivable.
%
%   RE-MEASURED 2026-08-12, since the sentence above names three field slots
%   and prose about a built tree is the thing this project re-derives rather
%   than repeats. It holds, and it is sharper than it was written:
%
%     DENOMINATOR: 247 json file(s) under did-schema schemas/V_eta/ read,
%                  every field declaration walked including nested ones
%       leaf field `datum_type`  : 0 declarations   <- BOTH datum_type targets
%       leaf field `datum`       : 1  sampled_body.datum
%       leaf field `regular`     : 1  sampled_body.sample_time.regular
%       leaf field `regularity`  : 2  sampled_body.axes.regularity,
%                                     acquisition_epoch.axes.regularity
%
%   So `datum_type` -- the destination the signature names TWICE, for
%   `time_type` and for `data_type` -- exists nowhere, and `time_size`/
%   `data_size` are "implied by their datum_type", which makes FOUR of the six
%   fields dependent on a slot that has not been built. The remaining two are
%   no better off: the signature says `samples_regular_intervals` becomes "the
%   axis `regular` flag", and there is no such flag -- there is a boolean
%   `sample_time.regular` and a char enum `axes.regularity`, which are two of
%   the three encodings #45 exists to COLLAPSE into one. Naming which field is
%   blocked rather than which item number is blocked is deliberate; see
%   did-schema V_eta_OPEN_WORK.md row #106.
%
%   ---------------------------------------------------------------------
%   AND A SECOND BLOCKER, WHICH #45 DOES NOT LIFT. RECORDED, NOT RESOLVED.
%   ---------------------------------------------------------------------
%   Everything above reads as though `axes[]`/`datum_type` are the only thing
%   in the way -- so that the fold becomes a straightforward build the day #45
%   lands. IT IS NOT. The signed targets are `subject_statement` +
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
%   WHAT THE TARGETS DEMAND, read off the built schemas rather than recalled:
%
%     subject_statement.subject_id   mustBeNonEmpty TRUE   -> subject
%     subject_statement.variable     mustBeNonEmpty TRUE   (ontology_term)
%     sampled_body.statement         mustBeNonEmpty TRUE   -> subject_statement
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
%   on the document says. Until that is answered, #45 landing does NOT unblock
%   the fold, and if the answer turns out to be "nothing links them", then the
%   class is a PERMANENT passthrough -- a different disposition from the
%   "deferred" one everybody currently reads off the ledger. DO NOT RESOLVE IT
%   BY MINTING A SUBJECT.
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
%   There is NO WRITER. Denominator: 1467 files tracked on NDI origin/main, 1002
%   of them .m; `git grep -i binaryseries origin/main` matches 3 files and NONE
%   is a .m -- the template, its schema, and ndiDocumentAttributes.json. And no
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
