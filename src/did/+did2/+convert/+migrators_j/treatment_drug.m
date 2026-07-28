function v2Body = treatment_drug(preBody)
%TREATMENT_DRUG Brainstorm-J migrator: did_v1 treatment_drug -> dose_manipulation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8): a drug administration is a
%   dose_manipulation -- the administered substance(s) become the
%   `dose.value.formulation.chemicals`, the primary drug is the spine
%   `subject_statement.variable`, and the delivery route (when the source names
%   one) would ride on `subject_interaction.method`. The site is Path S -- a
%   merely-located site becomes a `term_observation` here (D3), an attributed
%   site is promoted by the NDI second pass. 1 -> 2 (dose_manipulation + anchor),
%   or 1 -> 3 when the row carries a location.
%
%   Mixture parsing is a HEURISTIC seed (the legacy mixture_table format
%   varies); the authoritative mapping is finalised in discovery mode.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment_drug') || ~isstruct(preBody.treatment_drug)
    error('did2:convert:missingBlock', ...
        'treatment_drug body is missing the treatment_drug property block.');
end
block = preBody.treatment_drug;

chemicals = parseMixtureTable(block);
variable  = chemicals(1).substance;   % the primary drug is the spine identity

dose = jStartInteraction(preBody, 'dose_manipulation', ...
    'subject_manipulation', {'dose'}, variable);
dose.dose = struct('value', jDoseValue(chemicals));

anchor = jSessionAnchor(preBody, 'during');
dose.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

bodies = {dose};
% universalRenames snake_cases block fields (location_ontologyNode ->
% location_ontology_node); read the snake form first, camelCase as a fallback.
siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'location_ontology_node', 'location_ontologyNode'}), ...
    jGetCharAny(block, {'location_name'}));
if ~isempty(siteTerm.node) || ~isempty(siteTerm.name)
    obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
        {}, jOntologyTerm('', 'anatomical location'), {'subject_id'}, true);
    obs.term = struct('value', siteTerm);
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end

% ===================== local helpers ===================================

function chemicals = parseMixtureTable(block)
%PARSEMIXTURETABLE Best-effort parse of the legacy CSV mixture_table into the
%   {substance, amount} records `dose.value.formulation.chemicals` wants. Always
%   returns >= 1 record (a blank one if nothing parses) so the document
%   validates; the blank is the curator's signal.
chemicals = struct('substance', {}, 'amount', {});
raw = jGetChar(block, 'mixture_table');
if ~isempty(raw)
    lines = strsplit(raw, newline);
    for i = 1:numel(lines)
        cols = strsplit(strtrim(lines{i}), ',', 'CollapseDelimiters', false);
        if numel(cols) < 2 || isempty(strtrim(cols{1}))
            continue;
        end
        substance = jOntologyTerm(strtrim(cols{1}), strtrim(cols{2}));
        amount = jConcentration();
        if numel(cols) >= 3 && ~isempty(strtrim(cols{3}))
            amount.source_value = str2double(strtrim(cols{3}));
        end
        chemicals(end+1) = struct('substance', substance, 'amount', amount); %#ok<AGROW>
    end
end
if isempty(chemicals)
    chemicals(end+1) = struct('substance', jOntologyTerm('', ''), ...
        'amount', jConcentration());
end
end
