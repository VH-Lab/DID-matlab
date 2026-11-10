function [v1, spec] = spikewaves(bodies, ctx)
%SPIKEWAVES Rebuild a v1 `spikewaves` from its two calculations.
%
%   [V1, SPEC] = did2.convert.roundtrip.spikewaves(BODIES, CTX). BODIES are
%   what did2.convert.migrators_j.spikewaves emitted for one v1 document (Jess
%   Haley, 2026-11-10 [spike waveforms are two calculations], [spike waveforms
%   built now]): the spike-times calculation (id preserved), its sampled_body,
%   the waveform calculation (input: the spike times), its sampled_body, the
%   time anchor and the software entities. A carried document is its own
%   inverse (passthroughInverse).
%
%   REBUILT, in NDI's v1 shape (spikewaves.json + base + epochid + app at the
%   locked NDI-matlab main):
%     base.id, session_id, datestamp   the spike-times calculation (calcParts)
%     app.*                    the software, operating system and interpreter
%                              entities (calcParts)
%     depends_on               extraction_parameters_id = the calculations'
%                              method_id, element_id = their entity_id, in the
%                              template's order
%     epochid.epochid          the local_identifier of the epoch the anchor
%                              names (CTX: epochMint mints it); '' for a
%                              session anchor
%     spikewaves.extraction_name   the base.name of the method_id document
%                              (CTX): the writer names a spikewaves by its
%                              extraction settings' name (spikeextractor.m
%                              extract: find_appdoc('extraction_parameters',
%                              extraction_name))
%     files                    spikewaves.vsw then spiketimes.bin, the writer's
%                              order. spiketimes.bin's record is the spike-times
%                              body's own (the body IS that file). The
%                              waveform body is a NEW file, so the .vsw record
%                              is that file's: its uid and location are not
%                              the v1 file's, and the comparison reports them.
%   The two files' BYTES are rebuilt by did2.convert.roundtrip.spikewavesFiles.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.spikewaves,
%   did2.convert.roundtrip.spikewavesFiles.

arguments
    bodies cell
    ctx = []
end
names = cellfun(@classNameOf, bodies, 'UniformOutput', false);
calcIdx = find(strcmp(names, 'calculation'));
if isempty(calcIdx)
    [v1, spec] = passthroughInverse(bodies, 'spikewaves');
    return;
end
spec = emptySpec();
if isscalar(calcIdx) && ~isempty(ctx)
    % the whole-batch round trip hands a deferred source its v1 id's document
    % only (the spike-times calculation, which epochMint's re-run made): the
    % rest of what that run emitted is read from the batch
    bodies = withRunFromBatch(bodies, calcIdx, ctx);
    names = cellfun(@classNameOf, bodies, 'UniformOutput', false);
    calcIdx = find(strcmp(names, 'calculation'));
end
[timesK, wavesK] = whichCalc(bodies, calcIdx);
if isempty(timesK) || isempty(wavesK)
    spec.unplaced{end+1} = sprintf('%d calculations, not a spike-times and a waveform calculation', numel(calcIdx));
    v1 = struct('document_class', struct('class_name', 'spikewaves'));
    return;
end
times = bodies{timesK};
waves = bodies{wavesK};
timesId = char(getIn(times, 'base', 'id'));
wavesId = char(getIn(waves, 'base', 'id'));
rest = true(1, numel(bodies));
rest([timesK, wavesK]) = false;
timesBody = [];
wavesBody = [];
for k = find(strcmp(names, 'sampled_body'))
    owner = edgeIds(bodies{k}, 'owner_id');
    if isequal(owner, {timesId}) && isempty(timesBody)
        timesBody = bodies{k};
        rest(k) = false;
    elseif isequal(owner, {wavesId}) && isempty(wavesBody)
        wavesBody = bodies{k};
        rest(k) = false;
    end
end
if isempty(timesBody); spec.unplaced{end+1} = 'no sampled_body holds the spike times'; end
if isempty(wavesBody); spec.unplaced{end+1} = 'no sampled_body holds the waveforms'; end

% identity, app and anchor, from the spike-times calculation
[v1, ~, ~, spec2] = calcParts([{times}, bodies(rest)], 'calculation', 'spikewaves', '');
spec.unplaced = [spec.unplaced, spec2.unplaced];

% the two calculations state one run: the same element, method, anchor, software
for e = {'entity_id', 'method_id', 'time_reference_id', 'software_id', ...
        'operating_system_id', 'interpreter_id'}
    if ~isequal(edgeIds(times, e{1}), edgeIds(waves, e{1}))
        spec.unplaced{end+1} = sprintf('the two calculations differ in %s', e{1}); %#ok<AGROW>
    end
end
methodIds = edgeIds(times, 'method_id');
elementIds = edgeIds(times, 'entity_id');
v1.depends_on = struct('name', {'extraction_parameters_id', 'element_id'}, ...
    'value', {firstOf(methodIds), firstOf(elementIds)});

% the epoch the anchor names
epochString = '';
anchorIds = edgeIds(times, 'time_reference_id');
referent = '';
for k = 1:numel(bodies)
    if strcmp(names{k}, 'relative_time_reference') && any(strcmp(char(getIn(bodies{k}, 'base', 'id')), anchorIds))
        r = edgeIds(bodies{k}, 'referent_id');
        if ~isempty(r); referent = r{1}; end
    end
end
if ~isempty(referent) && ~strcmp(referent, v1.base.session_id)
    e = ctxDoc(ctx, referent);
    [lid, ok] = getIn(e, 'entity', 'local_identifier');
    if ~isempty(e) && ok
        epochString = char(lid);
    else
        spec.unplaced{end+1} = sprintf('the epoch %s the anchor names is not in the batch', referent);
    end
end
v1.epochid = struct('epochid', epochString);

% the extraction name: the settings document's name
extractionName = '';
m = ctxDoc(ctx, firstOf(methodIds));
if ~isempty(m)
    extractionName = char(getIn(m, 'base', 'name'));
end
v1.spikewaves = struct('extraction_name', extractionName);

% the files, in the writer's order
vswInfo = struct('name', 'spikewaves.vsw');
timesInfo = struct('name', 'spiketimes.bin');
if ~isempty(wavesBody)
    vswInfo = renamed(getIn(wavesBody, 'files', 'file_info'), 'spikewaves.vsw');
end
if ~isempty(timesBody)
    timesInfo = renamed(getIn(timesBody, 'files', 'file_info'), 'spiketimes.bin');
end
v1.files = struct('file_list', {{'spikewaves.vsw', 'spiketimes.bin'}});
try
    v1.files.file_info = [vswInfo, timesInfo];
catch
    v1.files.file_info = {vswInfo, timesInfo};
    spec.unplaced{end+1} = 'the two body file records have different fields';
end
end

function bodies = withRunFromBatch(bodies, calcIdx, ctx)
% BODIES plus, from the batch, the waveform calculation (input: this one), the
% two bodies, the anchor and the software entities with their versions
times = bodies{calcIdx};
id = char(getIn(times, 'base', 'id'));
have = cellfun(@(b) char(getIn(b, 'base', 'id')), bodies, 'UniformOutput', false);
add = {};
for p = reshape(ctxReferrers(ctx, id), 1, [])
    d = ctx.docs{p};
    cn = classNameOf(d);
    if strcmp(cn, 'sampled_body') || (strcmp(cn, 'calculation') && any(strcmp(edgeIds(d, 'input_id'), id)))
        add{end+1} = d; %#ok<AGROW>
        if strcmp(cn, 'calculation')
            wid = char(getIn(d, 'base', 'id'));
            for q = reshape(ctxReferrers(ctx, wid), 1, [])
                if strcmp(classNameOf(ctx.docs{q}), 'sampled_body')
                    add{end+1} = ctx.docs{q}; %#ok<AGROW>
                end
            end
        end
    end
end
for e = {'time_reference_id', 'software_id', 'operating_system_id', 'interpreter_id'}
    for i = reshape(edgeIds(times, e{1}), 1, [])
        d = ctxDoc(ctx, i{1});
        if isempty(d); continue; end
        add{end+1} = d; %#ok<AGROW>
        if strcmp(e{1}, 'time_reference_id'); continue; end
        for q = reshape(ctxReferrers(ctx, i{1}), 1, [])
            if strcmp(classNameOf(ctx.docs{q}), 'assertion')
                add{end+1} = ctx.docs{q}; %#ok<AGROW>
            end
        end
    end
end
for k = 1:numel(add)
    aid = char(getIn(add{k}, 'base', 'id'));
    if ~any(strcmp(have, aid))
        bodies{end+1} = add{k}; %#ok<AGROW>
        have{end+1} = aid; %#ok<AGROW>
    end
end
end

function [timesK, wavesK] = whichCalc(bodies, calcIdx)
% the waveform calculation is the one whose input is the other
timesK = [];
wavesK = [];
if numel(calcIdx) ~= 2
    return;
end
a = calcIdx(1);
b = calcIdx(2);
idA = char(getIn(bodies{a}, 'base', 'id'));
idB = char(getIn(bodies{b}, 'base', 'id'));
if any(strcmp(edgeIds(bodies{b}, 'input_id'), idA))
    timesK = a; wavesK = b;
elseif any(strcmp(edgeIds(bodies{a}, 'input_id'), idB))
    timesK = b; wavesK = a;
end
end

function fi = renamed(fi, name)
if iscell(fi); fi = [fi{:}]; end
if isstruct(fi) && isscalar(fi)
    fi.name = name;
else
    fi = struct('name', name);
end
end

function s = firstOf(c)
s = '';
if ~isempty(c); s = char(c{1}); end
end
