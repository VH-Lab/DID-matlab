function v2Body = image_stack_parameters(preBody)
%IMAGE_STACK_PARAMETERS Brainstorm-J SUPERCLASS migrator: normalise the
%   did_v1 `imageStack_parameters` block's own untypeable placeholder.
%
%   STATUS: NOT RUN. There is no MATLAB in the container this was written in, so
%   nothing here has been executed. Every claim below is read off NDI
%   `origin/main` or off +did2/+schema/cache.m and is quoted with line numbers.
%   The gate is tests/+did2/+unittest/testTemplateLiteralTypeTraps.m, also unrun.
%
%   Selected by did2.convert.v1_to_v2 (applySuperclassMigrators) whenever
%   TargetVersion == 'V_eta' and the body's superclass chain names
%   `image_stack_parameters` -- i.e. on every `image_stack` document. There is
%   no V_delta migrator of this name, so nothing is being displaced.
%
%   ---------------------------------------------------------------------
%   WHY A SUPERCLASS MIGRATOR AND NOT A CONCRETE ONE
%   ---------------------------------------------------------------------
%   `imageStack_parameters` is a SUPERCLASS, not a document anyone constructs.
%   Both production converters pass its BLOCK as a name-value pair to
%   ndi.document('imageStack', ...) --
%
%     origin/main:src/ndi/+ndi/+setup/+conv/+babu/import.m:456-475
%     origin/main:src/ndi/+ndi/+setup/+conv/+haley/doImport.m:407-423, 451-497,
%                                                             781-838
%
%   -- so the block always arrives INSIDE an image_stack document, and the place
%   to normalise it is the superclass pass, which runs BEFORE the concrete
%   migrator (v1_to_v2.m:156 then :165). That covers both of
%   migrators_j/image_stack.m's paths at once.
%
%   ---------------------------------------------------------------------
%   THE DEFECT IT REPAIRS: THE TEMPLATE'S OWN `[]` FAILS mustBeScalar
%   ---------------------------------------------------------------------
%     origin/main:src/ndi/ndi_common/database_documents/data/imageStack_parameters.json
%        "timestamp": []
%     origin/main:src/ndi/ndi_common/schema_documents/data/imageStack_parameters_schema.json
%        timestamp -> "type": "double", "default_value": [0]
%
%   V_eta takes its type from the NDI SCHEMA, so the tombstone declares
%   `timestamp` `double`, `mustBeScalar: true` (did-schema/tools/build_v_eta.py,
%   the image_stack_parameters _tombstone). The empty double PASSES the type
%   check -- isnumeric([]) is true -- and then fails the next one:
%
%     +did2/+schema/cache.m:1229   validateTypeShape runs unconditionally
%     +did2/+schema/cache.m:1383   case {'double','matrix'}: isnumeric ==> [] OK
%     +did2/+schema/cache.m:1258   mustBeScalar && ~isScalarValue
%                                  -> did2:validation:notScalar  ==> [] FAILS
%
%   ABSENCE is what validates: cache.m:1212-1225, an absent field that is not
%   `mustBeNonEmpty` returns before any type check. So the placeholder is
%   DROPPED, not coerced -- 0 would be a real datenum (year 0) and NaN would be
%   a value the field is free to reject later. Neither is what `[]` means.
%
%   A non-empty non-scalar timestamp is NOT reshaped and NOT truncated -- it
%   ERRORS, because nothing establishes which element is the acquisition time.
%   A char timestamp likewise errors rather than being parsed.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS REACHABLE, GIVEN BOTH WRITERS SET IT
%   ---------------------------------------------------------------------
%   DENOMINATOR: 2 production converters, 7 ndi.document('imageStack') sites
%   between them, ALL of which build an imageStack_parameters struct carrying
%   `timestamp` (babu/import.m:463 `convertTo(timeStamp,'datenum')`;
%   haley/doImport.m:414 and :788 the same). So the in-tree writers never leave
%   the placeholder, and this is LATENT for those datasets.
%
%   It is repaired anyway, for the reason the standing rule gives: THE CORPORA
%   ARE A SAMPLE. `ndi.document('imageStack')` fills from the template, so any
%   caller that does not pass the parameters block gets `timestamp: []`, and
%   there is no migrator downstream to overwrite it -- migrators_j/image_stack.m
%   now PASSES THE DOCUMENT THROUGH whenever `subject_id` is empty (its
%   subject-less guard), which is exactly the path on which the template literal
%   reaches the validator untouched.
%
%   DO NOT RE-DELETE THE TOMBSTONE. `image_stack` and `image_stack_parameters`
%   were taken BACK OUT of _DELETE_PHASE8 so that passthrough has a schema to
%   validate against; deleting them again strands the same documents this
%   normalisation exists to let through.
%
%   ---------------------------------------------------------------------
%   WHAT IS NOT TOUCHED
%   ---------------------------------------------------------------------
%   The other eight fields are left verbatim. `dimension_order`,
%   `dimension_labels`, `dimension_scale_units`, `data_type` and `clocktype` are
%   char/string and accept their '' placeholders; `dimension_size`,
%   `dimension_scale` and `data_limits` are `matrix`, which is numeric and NOT
%   scalar-constrained, so their `[]` placeholders validate as they stand.
%   `timestamp` is the ONLY row of this class in the 33-row template-literal
%   sweep, and this migrator does exactly that one row.
%
%   A superclass migrator reshapes ONE body and must return a scalar struct
%   (v1_to_v2.m:582-588); splitting is the concrete migrator's job.
%
%   See also: did2.convert.migrators_j.binaryseries_parameters (the precedent),
%   did2.convert.migrators_j.stimulus_parameter (the sibling trap),
%   did2.convert.migrators_j.image_stack (the passthrough this protects).

arguments
    preBody (1,1) struct
end

v2Body = preBody;
BLOCK = 'image_stack_parameters';

if ~isfield(v2Body, BLOCK) || ~isstruct(v2Body.(BLOCK)) ...
        || ~isfield(v2Body.(BLOCK), 'timestamp')
    return;
end

ts = v2Body.(BLOCK).timestamp;
if isnumeric(ts) || islogical(ts)
    if isempty(ts)
        % The template's own "unset" placeholder. Absence is the only
        % spelling of unset that gets past mustBeScalar.
        v2Body.(BLOCK) = rmfield(v2Body.(BLOCK), 'timestamp');
    elseif ~isscalar(ts)
        error('did2:convert:imageStackParametersNonScalarTimestamp', ...
            ['image_stack_parameters.timestamp holds %d values; NDI''s schema ' ...
             'types it a scalar `double` (the acquisition time of the FIRST ' ...
             'image). It is NOT truncated -- nothing says which element is ' ...
             'meant.'], numel(ts));
    end
elseif ischar(ts) || isstring(ts)
    if isempty(strtrim(char(ts)))
        % The same placeholder wearing the other empty. Same disposition.
        v2Body.(BLOCK) = rmfield(v2Body.(BLOCK), 'timestamp');
    else
        error('did2:convert:imageStackParametersCharTimestamp', ...
            ['image_stack_parameters.timestamp carries the non-empty char ' ...
             '''%s'' in a field NDI''s schema types `double` (a datenum, or ' ...
             'seconds on a local clock). It is NOT parsed: the clock is named ' ...
             'separately by `clocktype`, so a date string here has no ' ...
             'established encoding.'], char(ts));
    end
else
    error('did2:convert:imageStackParametersBadTimestampType', ...
        ['image_stack_parameters.timestamp is a %s; NDI''s schema types it ' ...
         '`double` and its template''s placeholder is []. No rule exists for ' ...
         'this shape.'], class(ts));
end
end
