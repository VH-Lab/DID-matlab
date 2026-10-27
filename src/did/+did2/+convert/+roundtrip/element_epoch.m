function [v1, spec] = element_epoch(bodies)
%ELEMENT_EPOCH Rebuild a v1 `element_epoch` from the pass-1 carrier
%   did2.convert.migrators_j.element_epoch emitted: one `acquisition_epoch`.
%
%   [V1, SPEC] = did2.convert.roundtrip.element_epoch(BODIES). V1 is the
%   element_epoch in NDI's v1 shape (element_epoch.json + epochid.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as ndi.element/addepoch
%   writes it):
%
%     base.id, session_id, datestamp   the carrier (rebuildBase)
%     depends_on(1) element_id         the carrier's element_id edge
%     element_epoch.epoch_clock        the clocks' names, joined by ','
%     element_epoch.t0_t1              [t0; t1] per clock, one column each (the
%                                      writer's column vector for one clock)
%     epochid.epochid                  the carrier's epochid.epochid
%     files                            the carrier's files block
%
%   THIS IS THE PASS-1 ROUND TRIP. The batch passes (epochMint,
%   resolveEpochProbemap) then dissolve the carrier into an epoch, its time
%   references and an observation with its data body; that dissolution is not
%   inverted here.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.element_epoch.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
ae = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'acquisition_epoch') && isempty(ae)
        ae = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the one acquisition_epoch', ...
            k, classNameOf(bodies{k}));
    end
end
if isempty(ae)
    spec.unplaced{end+1} = 'no acquisition_epoch was emitted';
    return;
end
[base, ~] = rebuildBase(ae);
clocks = asCell(getIn(ae, 'acquisition_epoch', 'clocks'));
names = cell(1, numel(clocks));
t0t1 = zeros(2, numel(clocks));
for k = 1:numel(clocks)
    names{k} = fieldText(clocks{k}, 'name');
    t0t1(:, k) = [timeOf(clocks{k}, 't0'); timeOf(clocks{k}, 't1')];
end
ids = edgeIds(ae, 'element_id');
if isempty(ids); ids = {''}; end

v1.document_class = struct('class_name', 'element_epoch');
v1.depends_on = struct('name', 'element_id', 'value', ids{1});
if isfield(ae, 'files')
    v1.files = ae.files;
end
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
[epochId, ok] = getIn(ae, 'epochid', 'epochid');
if ok
    v1.epochid = struct('epochid', epochId);
end
v1.element_epoch = struct('epoch_clock', strjoin(names, ','), 't0_t1', t0t1);
end

function t = timeOf(clock, name)
t = NaN;
[v, ok] = getIn(clock, name);
if ok && isnumeric(v) && isscalar(v)
    t = double(v);
end
end
