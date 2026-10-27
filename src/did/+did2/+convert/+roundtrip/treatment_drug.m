function [v1, spec] = treatment_drug(bodies)
%TREATMENT_DRUG Rebuild a v1 `treatment_drug` from what
%   did2.convert.migrators_j.treatment_drug emitted when it CONVERTED it: an
%   immersion (bath) or a dose (an UBERON site), with its chemicals,
%   formulation, anchor and, for a dose, the site observation.
%
%   [V1, SPEC] = did2.convert.roundtrip.treatment_drug(BODIES). V1 is the
%   treatment_drug in NDI's v1 shape (treatment/treatment_drug.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8):
%
%     base.id, session_id, datestamp   the manipulation (rebuildBase)
%     depends_on(1) subject_id         the manipulation's `entity_id`
%     treatment_drug.mixture_table     one row per chemical (treatmentRows),
%                                      compared row by row (sameMixture)
%     treatment_drug.location_ontologyNode, location_name
%                                      a dose: the site observation's term;
%                                      an immersion: the bath (SPEC)
%     treatment_drug.administration_onset_time
%                                      the absolute anchor's source text
%
%   NOT REBUILT, because V2 does not keep them (the round trip reports them):
%   `administration_offset_time` and `administration_duration` (no migrator
%   reads them), and the WRITER's spelling of the location node,
%   `location_ontologyName` (+NDIMaker/treatmentMaker writes that name; the
%   template's is `location_ontologyNode`, the only one the migrator reads).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.treatment_drug.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
p = treatmentParts(bodies);
spec.unplaced = p.unplaced;
if isempty(p.manip)
    return;
end
[base, ~] = rebuildBase(p.manip);

block = struct('mixture_table', mixtureText(treatmentRows(p)));
if ~isempty(p.site)
    [block.location_ontologyNode, block.location_name] = ...
        termParts(getIn(p.site, 'term', 'value'));
elseif strcmp(p.kind, 'formulation')
    spec = bathEquivalents(spec, 'treatment_drug.location_ontologyNode', ...
        'treatment_drug.location_name');
end
onset = anchorOnset(p.anchor);
if ~isempty(onset)
    block.administration_onset_time = onset;
end

v1.document_class = struct('class_name', 'treatment_drug');
ids = edgeIds(p.manip, 'entity_id');
if isempty(ids); ids = {''}; end
v1.depends_on = struct('name', 'subject_id', 'value', ids{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
v1.treatment_drug = block;

spec.same(end+1) = struct('path', 'treatment_drug.mixture_table', ...
    'fn', @(a, b) sameMixture(a, b), 'why', ['the same rows in another ' ...
    'layout ([spelling is notation])']);
spec.same(end+1) = struct('path', 'treatment_drug.location_ontologyNode', ...
    'fn', @(a, b) sameCurie(a, b), 'why', ['the site node in the registry''s ' ...
    'spelling ([spelling is notation]; V_eta_prefix_spelling_plan.md)']);
end
