function [v1, spec] = daqreader_mfdaq_epochdata_ingested(bodies)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Rebuild a v1
%   `daqreader_mfdaq_epochdata_ingested` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested(BODIES).
%   V1 is the ingested epoch cache in NDI's v1 shape
%   (daqreader_mfdaq_epochdata_ingested.json + daqreader_epochdata_ingested.json
%   + epochid.json + base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+daq/+reader/mfdaq.m ingest_epochfiles writes it). BODIES holds:
%
%   the de-encoded cache, one `daqreader_epochdata_ingested` document as
%   v1_to_v2 padded and stamped it:
%     base.*                          the document's (the session edge read
%                                     back into base.session_id, its
%                                     creation_timestamp into base.datestamp)
%     depends_on                      its edges, each {name, value} as v1
%                                     writes them (the session edge removed)
%     files, epochid, epochtable      the document's
%     daqreader_mfdaq_epochdata_ingested.parameters
%                                     daqreader_epochdata_ingested.parameters
%   and, when the cache had an `epoch_id` edge (never on a v1 document; the
%   parent migrator's lift), the relative_time_references it lifted: each must
%   restate one clock of the epochtable, or it is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested.

arguments
    bodies cell
end

CLASS = 'daqreader_mfdaq_epochdata_ingested';
PARENT = 'daqreader_epochdata_ingested';
spec = emptySpec();
v1 = struct();
cache = [];
refs = {};
for k = 1:numel(bodies)
    cn = classNameOf(bodies{k});
    if strcmp(cn, PARENT) && isempty(cache)
        cache = bodies{k};
    elseif strcmp(cn, 'relative_time_reference')
        refs{end+1} = bodies{k}; %#ok<AGROW>
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the de-encoded cache', ...
            k, cn);
    end
end
if isempty(cache)
    spec.unplaced{end+1} = 'no daqreader_epochdata_ingested was emitted';
    return;
end

v1 = undoOutbound(cache);
v1.document_class.class_name = CLASS;
if isfield(v1, 'depends_on') && isstruct(v1.depends_on)
    d = struct('name', {}, 'value', {});
    for k = 1:numel(v1.depends_on)
        ids = edgeIds(struct('depends_on', v1.depends_on(k)), char(v1.depends_on(k).name));
        if isempty(ids); ids = {''}; end
        d(end+1) = struct('name', char(v1.depends_on(k).name), 'value', ids{1}); %#ok<AGROW>
    end
    v1.depends_on = d;
end
if isfield(v1, PARENT) && isstruct(v1.(PARENT)) && isfield(v1.(PARENT), 'parameters')
    v1.(CLASS) = struct('parameters', v1.(PARENT).parameters);
    v1.(PARENT) = rmfield(v1.(PARENT), 'parameters');
end

% the lifted references restate the epochtable; each must name one of its clocks
clocks = asCell(getIn(v1, PARENT, 'epochtable', 'epochclock'));
for k = 1:numel(refs)
    clk = clockText(getIn(refs{k}, 'relative_time_reference', 'value', 'clock'));   % by node first [clock terms get nodes]
    if ~any(strcmp(clk, cellfun(@char, clocks, 'UniformOutput', false)))
        spec.unplaced{end+1} = sprintf('a relative_time_reference on clock "%s" restates no clock of the epochtable', clk);
    end
end
end
