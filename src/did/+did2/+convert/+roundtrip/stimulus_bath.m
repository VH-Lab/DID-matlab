function [v1, spec] = stimulus_bath(bodies)
%STIMULUS_BATH Rebuild a v1 `stimulus_bath` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_bath(BODIES). V1 is the bath
%   in NDI's v1 shape (stimulus/stimulus_bath.json + base.json + epochid.json
%   at the locked NDI-matlab `main`, 3cb19a8, as +setup/+NDIMaker/
%   stimulusDocMaker.m createBathDocs writes it). Pass 1 defers every whole
%   bath (did2.convert.migrators_j.stimulus_bath); BODIES are the documents
%   did2.convert.resolveDeferredBaths assembles for it (makeBathVEta): the
%   `manipulation` (value kind formulation, the v1 id), its session anchor, the
%   `formulation` its value_id names, one `chemical` per ingredient, and, for an
%   anatomical location, the site observation (variable NCIT:C13717 "Anatomic
%   Site"). Roles are read by private/treatmentParts.
%
%     base.id, session_id, datestamp   the manipulation's (rebuildBase)
%     depends_on(1) stimulus_element_id
%                                      the manipulation's `instrument_id`
%                                      (both assemblers write it: [one bath
%                                      shape], Jess Haley, 2026-10-27)
%     epochid.epochid                  the local_identifier of the epoch entity
%                                      the anchor names, once did2.convert.
%                                      epochMint has re-pointed it ([one bath
%                                      shape]); BODIES then include that epoch
%                                      entity. Before that (the bath pass's own
%                                      output) the anchor is on the session and
%                                      the epoch is not rebuilt (reported lost)
%     stimulus_bath.location           the site observation's term; with none,
%                                      the generic bath (SPEC: the node
%                                      NCIm:C0179246 and the label the writer's
%                                      ndi.ontology.lookup gives it)
%     stimulus_bath.mixture_table      one row per chemical in ingredient order
%                                      (private/treatmentRows), then the
%                                      formulation's pH and osmolarity as rows
%                                      named 'pH' and 'osm' with no node,
%                                      compared row by row (sameMixture). The
%                                      v1 node of a pH / osm row and where the
%                                      row stood are not kept, so a table with
%                                      either row is reported lost.
%
%   The time reference must be the session anchor the pass makes (a
%   relative_time_reference `intervalDuring` the manipulation's session, with no
%   time of its own), or that anchor re-pointed at an epoch entity given in
%   BODIES, and the manipulation's value kind `formulation`; anything else, or
%   a document no role claims, is unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.resolveDeferredBaths,
%            did2.convert.migrators_j.stimulus_bath.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
% the epoch entities an epoch-anchored bath is given with: set aside here, and
% claimed below only by the anchor that names one
isEpoch = cellfun(@(b) isEntityOfType(b, 'epoch'), bodies);
epochs = bodies(isEpoch);
p = treatmentParts(bodies(~isEpoch));
spec.unplaced = strrep(p.unplaced, 'in a treatment', 'in a bath');
if isempty(p.manip)
    return;
end
if ~strcmp(p.kind, 'formulation')
    spec.unplaced{end+1} = sprintf('the manipulation''s value kind is "%s", not formulation', p.kind);
end
for k = 1:numel(p.relations)
    spec.unplaced{end+1} = 'a directed_relation has no role in a bath';
end
[base, ~] = rebuildBase(p.manip);
epochString = '';
if isempty(p.anchor)
    spec.unplaced{end+1} = 'the bath names no time reference (the session anchor is one)';
else
    [rnode, rname] = termParts(getIn(p.anchor, 'relative_time_reference', 'value', 'relation'));
    during = endsWith(rnode, 'intervalDuring') || strcmp(rname, 'intervalDuring');
    ref = edgeIds(p.anchor, 'referent_id');
    epochHit = 0;
    for k = 1:numel(epochs)
        if isscalar(ref) && strcmp(char(getIn(epochs{k}, 'base', 'id')), ref{1})
            epochHit = k;
        end
    end
    if ~strcmp(classNameOf(p.anchor), 'relative_time_reference') ...
            || ~(isequal(ref, {base.session_id}) || epochHit > 0) || ~during ...
            || ~allEmpty(getIn(p.anchor, 'relative_time_reference', 'value', 'start'))
        spec.unplaced{end+1} = ['the time reference is not the session anchor ' ...
            '(intervalDuring the session) or that anchor on an epoch'];
    end
    if epochHit > 0
        epochString = fieldText(getIn(epochs{epochHit}, 'entity'), 'local_identifier');
        epochs(epochHit) = [];
    end
end
for k = 1:numel(epochs)
    spec.unplaced{end+1} = 'an epoch entity no anchor names has no role in a bath';
end

rows = treatmentRows(p);
props = getIn(p.formulation, 'formulation', 'value');
rows = propertyRow(rows, getIn(props, 'ph'), 'pH');
rows = propertyRow(rows, getIn(props, 'osmolarity'), 'osm');
block = struct();
if ~isempty(p.site)
    [node, name] = termParts(getIn(p.site, 'term', 'value'));
    block.location = struct('ontologyNode', node, 'name', name);
else
    why = ['a bath with no site observation is at the generic bath, NCIm:C0179246 ' ...
        '(resolveDeferredBaths isGenericBath; Jess Haley, 2026-10-21: a whole-prep ' ...
        'or whole-slice bath "targets the subject"), named by stimulusDocMaker''s ' ...
        'ndi.ontology.lookup of that node'];
    spec.equivalents(end+1) = struct('path', 'stimulus_bath.location.ontologyNode', ...
        'values', {{'NCIm:C0179246'}}, 'why', why);
    spec.equivalents(end+1) = struct('path', 'stimulus_bath.location.name', ...
        'values', {{'Baths, Water, Laboratory'}}, 'why', why);
end
block.mixture_table = mixtureText(rows);

stimulator = edgeIds(p.manip, 'instrument_id');
if isempty(stimulator); stimulator = {''}; end
v1.document_class = struct('class_name', 'stimulus_bath');
v1.depends_on = struct('name', 'stimulus_element_id', 'value', stimulator{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
if ~isempty(epochString)
    v1.epochid = struct('epochid', epochString);
end
v1.stimulus_bath = block;

spec.same(end+1) = struct('path', 'stimulus_bath.mixture_table', ...
    'fn', @(a, b) sameMixture(a, b), 'why', ['the same rows in another ' ...
    'layout ([spelling is notation])']);
spec.same(end+1) = struct('path', 'stimulus_bath.location.ontologyNode', ...
    'fn', @(a, b) sameCurie(a, b), 'why', ['the site node in the registry''s ' ...
    'spelling ([spelling is notation]; V_eta_prefix_spelling_plan.md)']);
end

function rows = propertyRow(rows, q, name)
% A whole-mixture property the pass put on the formulation (`ph`,
% `osmolarity`) as the row it was read from, with no node (V2 keeps none)
if ~isstruct(q) || ~isscalar(q) || ~isfield(q, 'source_value')
    return;
end
[unode, uname] = termParts(getIn(q, 'source_unit'));
rows(end+1) = struct('node', '', 'name', name, 'value', numberOf(q.source_value), ...
    'unode', unode, 'uname', uname);
end
