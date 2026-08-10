function bodies = stimulus_parameter(preBody)
%STIMULUS_PARAMETER Brainstorm-J migrator: did_v1 stimulus_parameter -- a
%   PASSTHROUGH that normalises the template's own untypeable placeholder.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT RUN. There is no MATLAB in the container this was written in, so
%   nothing here has been executed. Every claim below is read off NDI
%   `origin/main` or off +did2/+schema/cache.m and is quoted with line numbers.
%   The gate is tests/+did2/+unittest/testTemplateLiteralTypeTraps.m, also unrun.
%
%   ---------------------------------------------------------------------
%   WHY THIS CLASS IS ONLY A PASSTHROUGH
%   ---------------------------------------------------------------------
%   `stimulus_parameter` is held for the stimulus model (#31): it is one of the
%   classes the Phase-2b tombstone sweep deliberately left alone until that
%   family lands. Nothing here folds or reshapes it -- the document reaches
%   validation in its did_v1 shape, against the V_eta source tombstone. This
%   migrator exists ONLY to make that survivable.
%
%   ---------------------------------------------------------------------
%   THE DEFECT IT REPAIRS: NO EMPTY `double` VALIDATES
%   ---------------------------------------------------------------------
%   NDI's template supplies the CHAR placeholder '' for a field its own schema
%   types `double`:
%
%     origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_parameter.json
%        "stimulus_parameter": { "ontology_name": "", "name": "", "value": "" }
%     origin/main:src/ndi/ndi_common/schema_documents/stimulus/stimulus_parameter_schema.json
%        value -> "type": "double", "default_value": []
%
%   `ndi.document(...)` fills a new document from the template
%   (+ndi/document.m readblankdefinition) and then assigns ONLY the name/value
%   pairs the caller passed, so a field the caller does not set keeps the
%   literal ''.
%
%   V_eta takes its type from the NDI SCHEMA, so the tombstone declares `value`
%   `double`, `mustBeScalar: false`, `mustBeNonEmpty: false` (built by
%   did-schema/tools/build_v_eta.py). Against the validator that admits no empty
%   representation at all:
%
%     +did2/+schema/cache.m:1229   validateTypeShape runs UNCONDITIONALLY on any
%                                  field present in the block -- no is-empty
%                                  short circuit ahead of it
%     +did2/+schema/cache.m:1383   case {'double','matrix'}: ~isnumeric(value)
%                                  -> did2:validation:typeMismatch  ==> '' FAILS
%
%   (LINE NUMBERS RE-READ 2026-08-10 rather than copied. The precedent file
%   migrators_j/binaryseries_parameters.m cites :1169 / :1318 / :1200 for these
%   same three anchors; cache.m has moved since, and the live numbers are
%   :1229 / :1383+:1378 / :1258. Reported, not patched -- that file belongs to
%   another item.)
%
%   WHAT DOES VALIDATE IS ABSENCE. cache.m:1212-1225 (validateField): an ABSENT
%   field that is not `mustBeNonEmpty` returns early, before any type check. And
%   v1_to_v2.ensureClassBlocks pads missing BLOCKS only (v1_to_v2.m:473-478), so
%   it will not put the placeholder back as a 0.
%
%   THEREFORE the empty char is DROPPED, not coerced. "Unset" is exactly what ''
%   means here, and absence is how V_eta spells unset. `ontology_name` and
%   `name` are left verbatim: both are typed `string`, which accepts ''.
%
%   A NON-EMPTY char in `value` is NOT parsed and NOT dropped -- it ERRORS.
%   '32' -> 32 would be a guess, and this repair track exists to remove guesses;
%   a loud quarantine with a legible reason beats a silent `typeMismatch`.
%   That branch is not hypothetical: the writer assigns `last_match.temp{1}`
%   out of a table cell (see below), and a text column would put a char there.
%
%   ---------------------------------------------------------------------
%   THE WRITER, AND WHY THE PLACEHOLDER IS STILL REACHABLE
%   ---------------------------------------------------------------------
%   DENOMINATOR: 5 files on NDI origin/main mention `stimulus_parameter` in any
%   .m file; exactly ONE constructs the class, at three sites --
%
%     origin/main:src/ndi/+ndi/+setup/+conv/+marder/temptable2stimulusparameters.m
%        :44-46  d_struct.value  = last_match.temp{1};      ndi.document(...)
%        :56-58  d_struct1.value = last_match.temp{1}(1);   ndi.document(...)
%        :63-65  d_struct2.value = last_match.temp{1}(2);   ndi.document(...)
%
%   All three SET `value`, so the in-tree production writer never leaves the
%   placeholder. That is NOT licence to skip the repair: the corpora are a
%   SAMPLE, `ndi.document('stimulus_parameter')` yields the placeholder for any
%   caller who does not set the field, and this class has no migrator to
%   overwrite it -- which is precisely why the 33-row template-literal sweep
%   flagged it as one of only three classes LIVE-EXPOSED on a passthrough path.
%
%   ---------------------------------------------------------------------
%   ONE SIDE EFFECT, STATED SO IT IS NOT DISCOVERED IN A CENSUS
%   ---------------------------------------------------------------------
%   v1_to_v2 counts a document as "unconverted" when the migrator hands its
%   input straight back (v1_to_v2.m:188). A document that HAD the placeholder no
%   longer compares equal, so it stops being counted; a document without one is
%   still counted. `unconverted_by_class.stimulus_parameter` therefore drops by
%   however many placeholders the corpus holds. Same property as
%   migrators_j/binaryseries_parameters.m, which is this file's precedent.
%
%   The id is preserved: the body is passed through, so base.id is untouched.
%
%   See also: did2.convert.migrators_j.binaryseries_parameters (the precedent),
%   did2.convert.migrators_j.super.image_stack_parameters (the sibling trap).

arguments
    preBody (1,1) struct
end

BLOCK = 'stimulus_parameter';

if isfield(preBody, BLOCK) && isstruct(preBody.(BLOCK)) ...
        && isfield(preBody.(BLOCK), 'value')
    v = preBody.(BLOCK).value;
    if isnumeric(v) || islogical(v)
        % A real value (including the schema's own [] default, which is an
        % empty DOUBLE and validates: `value` is not scalar-constrained).
    elseif ischar(v) || isstring(v)
        if isempty(strtrim(char(v)))
            % The template's own "unset" placeholder. Absence is the only
            % spelling of unset that validates.
            preBody.(BLOCK) = rmfield(preBody.(BLOCK), 'value');
        else
            error('did2:convert:stimulusParameterCharValue', ...
                ['stimulus_parameter.value carries the non-empty char ''%s'' ' ...
                 'in a field NDI''s own schema types `double`. It is NOT ' ...
                 'parsed: nothing establishes what encoding was intended, and ' ...
                 'guessing is what this repair track removes.'], char(v));
        end
    else
        error('did2:convert:stimulusParameterBadType', ...
            ['stimulus_parameter.value is a %s; NDI''s schema types it ' ...
             '`double` and its template''s placeholder is the empty char. ' ...
             'No rule exists for this shape.'], class(v));
    end
end

bodies = {preBody};
end
