function [v1, spec] = oneepoch(bodies)
%ONEEPOCH Rebuild a v1 `oneepoch` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.oneepoch(BODIES). V1 is the document in
%   NDI's v1 shape (oneepoch.json over element_epoch.json + epochid.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as ndi.element addepoch
%   writes it). BODIES is the one `oneepoch` document the migrator keeps (its
%   `element_epoch` block folded onto `oneepoch` as `clocks`, by
%   did2.convert.migrators.element_epoch):
%
%     base.id, session_id, datestamp   the document's
%     depends_on element_id            its element_id edge
%     files                            its files block, as v1 wrote it
%     epochid.epochid                  its epochid block
%     oneepoch.epoch_ids               oneepoch.epoch_ids
%     element_epoch.epoch_clock        the clocks' names, comma-joined
%     element_epoch.t0_t1              the clocks' [t0; t1], one column each
%
%   NO MIGRATOR OUTPUT REACHES THIS INVERSE since [reshaped retire classes
%   carried] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): migrators_j.oneepoch carries every document
%   whole as v1 (carry-126, or with its output element: [global-clock oneepoch
%   carried with its element], Jess Haley, 2026-10-30), and a carry's round
%   trip is the carry itself
%   (did2.convert.roundtrip.check). It is kept until the class's V2 home is
%   built, whose inverse replaces it.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.oneepoch,
%            did2.convert.roundtrip.element_epoch.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if ~(isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'oneepoch'))
    spec.unplaced{end+1} = sprintf('%d emitted document(s); the oneepoch migrator keeps one', ...
        numel(bodies));
    return;
end
d = bodies{1};
base = rebuildBase(d);
clocks = asCell(getIn(d, 'oneepoch', 'clocks'));
names = cell(1, numel(clocks));
t0t1 = zeros(2, numel(clocks));
for k = 1:numel(clocks)
    names{k} = fieldText(clocks{k}, 'name');
    t0t1(:, k) = [timeOf(clocks{k}, 't0'); timeOf(clocks{k}, 't1')];
end
ids = edgeIds(d, 'element_id');
if isempty(ids); ids = {''}; end
v1.document_class = struct('class_name', 'oneepoch');
v1.depends_on = struct('name', 'element_id', 'value', ids{1});
if isfield(d, 'files')
    v1.files = d.files;
end
v1.base = struct('id', base.id, 'session_id', base.session_id, 'datestamp', base.datestamp);
[epochId, ok] = getIn(d, 'epochid', 'epochid');
if ok
    v1.epochid = struct('epochid', epochId);
end
v1.element_epoch = struct('epoch_clock', strjoin(names, ','), 't0_t1', t0t1);
v1.oneepoch = struct('epoch_ids', getIn(d, 'oneepoch', 'epoch_ids'));
fns = setdiff(fieldnames(getIn(d, 'oneepoch')), {'clocks', 'epoch_ids'});
for k = 1:numel(fns)
    spec.unplaced{end+1} = sprintf('oneepoch.%s has no v1 place', fns{k});
end
end

function t = timeOf(clock, name)
t = NaN;
[v, ok] = getIn(clock, name);
if ok && isnumeric(v) && isscalar(v)
    t = double(v);
end
end
