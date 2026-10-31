function v2Body = virus_injection(preBody)
%VIRUS_INJECTION Brainstorm-J migrator: did_v1 virus_injection -> a dose or an
%   immersion, decided by the recorded location.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8). "virus_injection follows the same
%   location rule as the other treatments: a bath location makes it an
%   immersion (a manipulation of the subject valued by the virus formulation
%   through value_id, no location observation); a body site makes it a dose.
%   A dilution of 0 is treated as not recorded (NaN), not as a measured 0."
%   (Jess Haley, 2026-10-21 [virus-location]; supersedes "virus_injection is
%   always a dose" in [treatment-location].) Birren writes virus at the bath
%   (NCIm:C0179246) for cell cultures, with dilution 0, the template blank.
%
%   The virus identity is the spine `subject_statement.variable` AND the
%   formulation's first ingredient (a `chemical`); a non-zero dilution is that
%   ingredient's concentration `source_value`, a number with no unit, its
%   canonical named in needs_info ([virus dilution needs info], Decided by
%   Jess Haley, 2026-10-31, did-schema did_v2_go_forward_class_audit.md;
%   docs/V2_PLAN.md G71); 0 is not recorded, so the ingredient has no amount
%   and needs_info names it ([canonical absent only as needs info]; when no
%   ingredient states an amount, [formulation amount needs info], 2026-10-31,
%   G67); a named diluent is a second ingredient. Routing is jTreatmentRoute /
%   jTreatmentBodies: bath -> immersion; a body site -> a dose whose amount is
%   NaN in `volume.liters` (the template has no volume field) plus the site
%   `term_observation` (Path S, D3); no location -> that dose, listed in the
%   migration report as `route_unknown`.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it, with no universalRenames (identity through jRawBody /
%   did2.convert.v1read.readBase; a carry is the untouched v1 source). Block
%   fields are read in the v1 spelling first and the universalRenames spelling
%   second, so 'RawV1Classes', {} still works. Every v1 field (NDI treatment/virus_injection.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +NDIMaker/treatmentMaker writes it) and where it goes;
%   did2.convert.roundtrip.virus_injection rebuilds the v1 document and
%   testRawV1RoundTripTreatment compares the two:
%
%     base.*, depends_on subject_id  -> as treatment.m
%     virus_OntologyName, virus_name -> the variable and the first chemical
%     dilution                 -> its concentration source_value, no unit,
%                                 the canonical named in needs_info (0: no
%                                 amount, named in needs_info, [virus-location])
%     diluent_OntologyName, diluent_name -> the second chemical
%     virusLocation_OntologyName, virusLocation_name -> the route and the
%                                 site observation of a dose
%     virus_AdministrationDate -> the anchor (jTreatmentAnchor)
%     virus_AdministrationPND  -> an `observation` of the subject, value kind
%                                 time (the age, in days), variable NCIT:C25150
%                                 "Age", on the injection's time reference
%                                 ([age at injection is an observation], Jess
%                                 Haley, 2026-10-27; [age is NCIT Age],
%                                 2026-10-30). A non-numeric value is not
%                                 read (the round trip reports it lost).
%     files.file_list          -> empty in the template and the writer

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'virus_injection');
v2Body = convertVirusInjection(body);
if isscalar(v2Body) && isequaln(v2Body{1}, body)
    v2Body = {preBody};   % a carry is the untouched v1 source
end
end

function v2Body = convertVirusInjection(preBody)
if ~isfield(preBody, 'virus_injection') || ~isstruct(preBody.virus_injection)
    error('did2:convert:missingBlock', ...
        'virus_injection body is missing the virus_injection property block.');
end
block = preBody.virus_injection;

% universalRenames snake_cases block fields (virus_OntologyName ->
% virus_ontology_name); read the snake form first, camelCase as a fallback.
virusTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_ontology_name', 'virus_OntologyName'}), ...
    jGetCharAny(block, {'virus_name'}));
dilution = [];
dilutionUnit = '';
if isfield(block, 'dilution') && isnumeric(block.dilution) && ~isempty(block.dilution) ...
        && double(block.dilution(1)) ~= 0
    % 0 is the template blank, not a measured dilution: left unrecorded, so
    % jDoseBodies writes the ingredient with no amount and names it in
    % needs_info. Any other number is a ratio with NO unit: jDoseBodies keeps
    % it as the concentration's source_value and names its canonical in
    % needs_info ([virus dilution needs info], Jess Haley, 2026-10-31). No
    % unit label is made up for it (it was 'dilution' before).
    dilution = double(block.dilution(1));
end
chemicals = struct('substance', virusTerm, 'source_value', dilution, ...
    'source_unit', dilutionUnit);
diluentNode = jGetCharAny(block, {'diluent_ontology_name', 'diluent_OntologyName'});
diluentName = jGetCharAny(block, {'diluent_name'});
if ~isempty(diluentNode) || ~isempty(diluentName)
    chemicals(end+1) = struct('substance', jOntologyTerm(diluentNode, diluentName), ...
        'source_value', [], 'source_unit', '');
end

siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_location_ontology_name', 'virusLocation_OntologyName'}), ...
    jGetCharAny(block, {'virus_location_name', 'virusLocation_name'}));
anchor = jTreatmentAnchor(preBody, block);  % the recorded onset, else the session
[bodies, route, unplaced] = jTreatmentBodies(preBody, virusTerm, chemicals, siteTerm, anchor.base.id);
if ~isempty(unplaced)
    % [generic stage is lossless] / [partly placed is carried as v1] (Jess
    % Haley, 2026-10-25): an amount the dose cannot place carries the document
    % carry-register: carry-029 carry-030 carry-072 carry-073 via
    % private/jTreatmentBodies.m
    did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
        char(preBody.base.id), jCarryWhy(unplaced));
    v2Body = {preBody};
    return;
end
if strcmp(route, 'dose')
    obs = jStatement(preBody, 'observation', jSubjectOf(preBody), ...
        did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id}, 'ValueKind', 'term');
    bodies{end+1} = obs;
end
age = ageObservation(preBody, block, anchor.base.id);
if ~isempty(age)
    bodies{end+1} = age;
end
bodies{end+1} = anchor;
v2Body = bodies;
end

function obs = ageObservation(preBody, block, anchorId)
%AGEOBSERVATION The subject's age at the injection, or [] when v1 states none.
%   [age at injection is an observation] (Decided by Jess Haley, 2026-10-27,
%   did-schema V_eta_go_forward_class_audit.md): v1 `virus_AdministrationPND`
%   becomes an `observation` with value kind `time` (the age, in days) of the
%   injected subject (`entity_id`), its `time_reference_id` the same time
%   reference as the injection's manipulation. [age is NCIT Age] (Jess Haley,
%   2026-10-30): its variable is NCIT:C25150 "Age"; "at injection" is said by
%   the time reference. The value: `seconds` the days times 86400,
%   `source_value` the number of days as v1 wrote it, `source_unit` day.
%   A finite number is read as written, 0 included (the template's default
%   is 0, and no decision makes 0 "not recorded" for this field, unlike
%   `dilution`); an empty, NaN or non-numeric value states no age.
obs = [];
pnd = [];
for f = {'virus_administration_pnd', 'virus_AdministrationPND'}
    if isfield(block, f{1})
        pnd = block.(f{1});
        break;
    end
end
if ~(isnumeric(pnd) && isscalar(pnd) && isfinite(double(pnd)))
    return;
end
days = double(pnd);
value = did2.build.composite('time', 'value', {struct('seconds', days * 86400, ...
    'source_value', days, 'source_unit', struct('node', 'om:day', 'name', 'day'))});
obs = jStatement(preBody, 'observation', jSubjectOf(preBody), ...
    did2.convert.registeredTerm('NCIT:C25150', 'Age'), value, ...
    'TimeReferenceIds', {anchorId}, 'ValueKind', 'time');
end
