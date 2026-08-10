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
