function out = virus_injection(preBody)
%VIRUS_INJECTION Migrate a did_v1 virus_injection to a V_epsilon injection.
%
%   The legacy virus_injection class maps to the V_epsilon `injection`
%   family with kind = "virus", per Injection_Proposal.md (virus
%   injection is NOT a biological_transfer subclass). The viral
%   construct becomes a mixture entry; the injection location becomes
%   target_structure; the administration date becomes a (date-only,
%   approximate) utc_reference. This migration fans out into the
%   injection plus the companion utc_reference when a date is present.
%
%   Legacy block fields (post-universalRenames snake_case):
%     virus_ontology_name / virus_name                  - the construct
%     virus_location_ontology_name / virus_location_name- the site
%     virus_administration_date (YYYY-MM-DD)            - -> utc start
%     virus_administration_pnd                          - postnatal day
%                                                         (not timing-
%                                                         convertible
%                                                         without DOB;
%                                                         backfill)
%     dilution                                          - preserved as a
%                                                         source-only
%                                                         amount on the
%                                                         construct entry
%     diluent_ontology_name / diluent_name              - 2nd mixture
%                                                         entry when set
%
%   Backfill points: blank route, empty volume (legacy carries neither),
%   blank ontology nodes. Nothing legacy is dropped.
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/virus_injection.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

block = struct();
if isfield(preBody, 'virus_injection') && isstruct(preBody.virus_injection)
    block = preBody.virus_injection;
end

% --- mixture: construct (+ diluent) ---
virusNode = getField(block, 'virus_ontology_name', '');
virusName = getField(block, 'virus_name', '');
dilution  = getField(block, 'dilution', []);
mixture = struct( ...
    'chemical', ic.ontologyTerm(virusNode, virusName), ...
    'amount',   ic.concentration('dilution_factor', dilution));
diluentNode = getField(block, 'diluent_ontology_name', '');
diluentName = getField(block, 'diluent_name', '');
if ~isempty(diluentNode) || ~isempty(diluentName)
    mixture(end+1) = struct( ...
        'chemical', ic.ontologyTerm(diluentNode, diluentName), ...
        'amount',   ic.concentration('', 0));
end

% --- target_structure from the injection location ---
locNode = getField(block, 'virus_location_ontology_name', '');
locName = getField(block, 'virus_location_name', '');
if isempty(locNode) && isempty(locName)
    targetStructure = ic.ontologyTermArray({});
else
    targetStructure = ic.ontologyTermArray({{locNode, locName}});
end

injBody = struct();
injBody.document_class = struct('class_name', 'injection');
injBody.base = ic.carryBase(preBody);
injBody.pharmacological_manipulation = struct('mixture', mixture);
injBody.injection = struct( ...
    'kind', 'virus', ...
    'volume', ic.volume('', 0), ...
    'route', ic.ontologyTerm('', ''), ...
    'target_structure', targetStructure);

% --- timing: date-only -> approximate utc_reference ---
adminDate = getField(block, 'virus_administration_date', '');
companions = {};
timeRefId = '';
if ~isempty(adminDate)
    [trBody, timeRefId] = ic.utcReferenceBody(char(adminDate), ...
        ic.sessionIdOf(preBody), '', true);
    companions{end+1} = trBody;
end

injBody.depends_on = ic.dependsOn({ ...
    'subject_id',       ic.depDocId(preBody, 'subject_id'); ...
    'time_reference_1', timeRefId});

out = [{injBody}, companions];
end

function v = getField(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
