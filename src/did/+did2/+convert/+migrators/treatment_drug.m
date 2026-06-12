function out = treatment_drug(preBody)
%TREATMENT_DRUG Migrate a did_v1 treatment_drug to a V_epsilon injection.
%
%   The legacy treatment_drug class (a pharmacological administration
%   recorded as a chemical mixture at a location) maps to the V_epsilon
%   `injection` family with kind = "drug", per Injection_Proposal.md.
%   This migration fans out: it returns the injection document and,
%   when the legacy administration time is recoverable, a companion
%   utc_reference document wired as the injection's time_reference.
%
%   Legacy block fields (post-universalRenames snake_case):
%     location_ontology_name / location_name - application location
%     mixture_table                          - CSV of chemical contents
%     administration_onset_time              - ISO onset (-> utc start)
%     administration_offset_time             - ISO offset (-> utc end)
%     administration_duration                - days (not retained; the
%                                              onset/offset interval is
%                                              the canonical timing)
%
%   Target injection (chain base <- subject_interaction <- manipulation
%   <- pharmacological_manipulation <- injection):
%     pharmacological_manipulation.mixture - from mixture_table
%     injection.kind   = "drug"
%     injection.volume - source-empty (legacy carries no volume)
%     injection.route  - blank ontology_term (legacy has no route;
%                        curator backfill)
%     injection.target_structure - the application location as a
%                        single-entry array when present
%
%   Backfill points (blank ontology nodes / empty volume) follow the
%   draft-tier soak strategy; nothing legacy is dropped.
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/treatment_drug.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

block = struct();
if isfield(preBody, 'treatment_drug') && isstruct(preBody.treatment_drug)
    block = preBody.treatment_drug;
end

% --- mixture (required, non-empty) ---
mixture = ic.mixtureFromTable(getField(block, 'mixture_table', ''));
if isempty(mixture)
    % Keep the field non-empty with one backfill placeholder so the
    % document validates; curator supplies the chemical identity.
    mixture = struct('chemical', ic.ontologyTerm('', ''), ...
        'amount', ic.concentration('', 0));
end

% --- target_structure from the application location ---
locNode = getField(block, 'location_ontology_name', '');
locName = getField(block, 'location_name', '');
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
    'kind', 'drug', ...
    'volume', ic.volume('', 0), ...
    'route', ic.ontologyTerm('', ''), ...
    'target_structure', targetStructure);

% --- timing: mint a utc_reference when an onset time exists ---
onset = getField(block, 'administration_onset_time', '');
offset = getField(block, 'administration_offset_time', '');
companions = {};
timeRefId = '';
if ~isempty(onset)
    [trBody, timeRefId] = ic.utcReferenceBody(char(onset), ...
        ic.sessionIdOf(preBody), char(offset), false);
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
