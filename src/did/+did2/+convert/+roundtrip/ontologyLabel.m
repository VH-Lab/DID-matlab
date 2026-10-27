function [v1, spec] = ontologyLabel(bodies)
%ONTOLOGYLABEL Rebuild a v1 `ontologyLabel` from what pass 1 made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.ontologyLabel(BODIES). V1 is the label
%   in NDI's v1 shape (ontologyLabel.json + base.json at the locked NDI-matlab
%   `main`, 3cb19a8: one field, `ontologyNode`, one edge, `document_id`, as
%   +setup/+conv/+haley/doImport.m and +babu/import.m write it).
%
%   Pass 1 hands every label to NDI's second pass unchanged
%   (did2.convert.migrators_j.ontology_label), so BODIES is one `ontologyLabel`
%   document: the raw v1 source as v1_to_v2 padded and stamped it, its session
%   edge read back into base.session_id and its creation_timestamp into
%   base.datestamp. (A label pass 1 carries, carry-064, is stamped did_v1 and
%   is its own round trip in did2.convert.roundtrip.check.) The label is read
%   raw only when a caller passes it in v1_to_v2's 'RawV1Classes' option: it is
%   not in did2.convert.rawV1Classes (see there for why). What NDI's second
%   pass makes of a label is NDI's round trip, not this one.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.ontology_label.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if ~isscalar(bodies) || ~strcmp(classNameOf(bodies{1}), 'ontologyLabel')
    spec.unplaced{end+1} = sprintf(['pass 1 hands an ontologyLabel back unchanged; ' ...
        'got %d document(s)'], numel(bodies));
    return;
end
v1 = bodies{1};
sid = char(did2.schema.cache.sessionIdOf(v1));
if isfield(v1, 'depends_on') && isstruct(v1.depends_on) && ~isempty(v1.depends_on)
    keep = true(1, numel(v1.depends_on));
    for k = 1:numel(v1.depends_on)
        keep(k) = ~strcmp(char(v1.depends_on(k).name), 'session_id');
    end
    v1.depends_on = v1.depends_on(keep);
end
if isfield(v1, 'base') && isstruct(v1.base) && ~isfield(v1.base, 'session_id') && ~isempty(sid)
    v1.base.session_id = sid;
end
if isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'creation_timestamp') ...
        && ~isfield(v1.base, 'datestamp')
    v1.base.datestamp = v1.base.creation_timestamp;
    v1.base = rmfield(v1.base, 'creation_timestamp');
end
end
