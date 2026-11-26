function c = epochInstrumentCensus(docs)
%EPOCHINSTRUMENTCENSUS Interactions that name an instrument, on an epoch or
%   not, and the device entities they would make elements.
%
%   C = did2.convert.roundtrip.epochInstrumentCensus(DOCS). DOCS is a final
%   migrated batch (a cell of did2.document or of their toStruct structs).
%   Measures what Decided by Jess Haley, 2026-11-26 [instrument of an epoch
%   interaction is a link] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md) asks to be counted before it
%   is built: the interactions that name an `instrument_id` and whose time is
%   NOT on an epoch.
%
%   ON AN EPOCH: one of the interaction's `time_reference_id` documents is a
%   `relative_time_reference` whose `referent_id` is an entity of type
%   epoch (EMPTY:0000383 "recording epoch", by node) of the interaction's
%   own session (deviceLinks, onAnEpoch).
%
%   C, denominators first:
%     documents_inspected          numel(DOCS)
%     interactions                 documents whose class is an interaction
%     with_instrument              of those, the ones naming an instrument_id
%     on_epoch, not_on_epoch       of those
%     by_class                     struct array: class_name, with_instrument,
%                                  on_epoch, not_on_epoch
%     not_on_epoch_why             struct array: why, count
%     not_on_epoch_examples        up to 10: id, class_name, instrument_id, why
%     devices                      device entities
%     devices_linked_before        by a recording observation or wiring
%     devices_linked_after         ... or by an interaction on an epoch
%     devices_gained               struct array: id, local_identifier, by (the
%                                  classes of the interactions that link it)
%     devices_element_class_asserted  device entities an "ndi element class"
%                                  assertion is about (it wins while written)
%     devices_unlinked_after       device entities linked by neither, with no
%                                  such assertion
%
%   See also did2.convert.roundtrip.wholeBatch.

if ~iscell(docs)
    docs = {docs};
end
bodies = cell(1, numel(docs));
for k = 1:numel(docs)
    d = docs{k};
    if isa(d, 'did2.document')
        d = d.toStruct();
    end
    bodies{k} = d;
end
ctx = batchContext(bodies);

c = struct('documents_inspected', numel(bodies), 'interactions', 0, ...
    'with_instrument', 0, 'on_epoch', 0, 'not_on_epoch', 0, ...
    'by_class', struct('class_name', {}, 'with_instrument', {}, 'on_epoch', {}, 'not_on_epoch', {}), ...
    'not_on_epoch_why', struct('why', {}, 'count', {}), ...
    'not_on_epoch_examples', struct('id', {}, 'class_name', {}, 'instrument_id', {}, 'why', {}), ...
    'devices', 0, 'devices_linked_before', 0, 'devices_linked_after', 0, ...
    'devices_gained', struct('id', {}, 'local_identifier', {}, 'by', {}), ...
    'devices_element_class_asserted', 0, 'devices_unlinked_after', 0);

isInteraction = containers.Map('KeyType', 'char', 'ValueType', 'logical');
classRow = containers.Map('KeyType', 'char', 'ValueType', 'double');
whyRow = containers.Map('KeyType', 'char', 'ValueType', 'double');
epochLinks = containers.Map('KeyType', 'char', 'ValueType', 'any');   % device id -> classes
asserted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
devices = {};
for k = 1:numel(bodies)
    b = bodies{k};
    cn = classNameOf(b);
    if isempty(cn)
        continue;
    end
    if isEntityOfType(b, 'device')
        devices{end+1} = idOf(b); %#ok<AGROW>
        continue;
    end
    if strcmp(cn, 'assertion')
        [vnode, variable] = termParts(getIn(b, 'statement', 'variable'));
        if strcmpi(strtrim(char(vnode)), 'EMPTY:0000401') || ...
                (isempty(strtrim(char(vnode))) && strcmpi(variable, 'ndi element class'))
            for e = edgeIds(b, 'entity_id')
                asserted(e{1}) = true;
            end
        end
        continue;
    end
    if ~isKey(isInteraction, cn)
        isInteraction(cn) = interactionClass(cn);
    end
    if ~isInteraction(cn)
        continue;
    end
    c.interactions = c.interactions + 1;
    inst = edgeIds(b, 'instrument_id');
    if isempty(inst)
        continue;
    end
    c.with_instrument = c.with_instrument + 1;
    if ~isKey(classRow, cn)
        c.by_class(end+1) = struct('class_name', cn, 'with_instrument', 0, 'on_epoch', 0, 'not_on_epoch', 0);
        classRow(cn) = numel(c.by_class);
    end
    r = classRow(cn);
    c.by_class(r).with_instrument = c.by_class(r).with_instrument + 1;
    [on, why] = onAnEpoch(ctx, b);
    if on
        c.on_epoch = c.on_epoch + 1;
        c.by_class(r).on_epoch = c.by_class(r).on_epoch + 1;
        for i = 1:numel(inst)
            if isKey(epochLinks, inst{i})
                epochLinks(inst{i}) = unique([epochLinks(inst{i}), {cn}], 'stable');
            else
                epochLinks(inst{i}) = {cn};
            end
        end
    else
        c.not_on_epoch = c.not_on_epoch + 1;
        c.by_class(r).not_on_epoch = c.by_class(r).not_on_epoch + 1;
        if ~isKey(whyRow, why)
            c.not_on_epoch_why(end+1) = struct('why', why, 'count', 0);
            whyRow(why) = numel(c.not_on_epoch_why);
        end
        w = whyRow(why);
        c.not_on_epoch_why(w).count = c.not_on_epoch_why(w).count + 1;
        if numel(c.not_on_epoch_examples) < 10
            c.not_on_epoch_examples(end+1) = struct('id', idOf(b), 'class_name', cn, ...
                'instrument_id', strjoin(inst, ','), 'why', why);
        end
    end
end

c.devices = numel(devices);
for k = 1:numel(devices)
    id = devices{k};
    before = ~isempty(deviceLinks(ctx, id));
    after = before || isKey(epochLinks, id);
    isAsserted = isKey(asserted, id);
    c.devices_linked_before = c.devices_linked_before + before;
    c.devices_linked_after = c.devices_linked_after + after;
    c.devices_element_class_asserted = c.devices_element_class_asserted + isAsserted;
    if after && ~before
        e = ctxDoc(ctx, id);
        c.devices_gained(end+1) = struct('id', id, ...
            'local_identifier', fieldText(getIn(e, 'entity'), 'local_identifier'), ...
            'by', strjoin(epochLinks(id), ','));
    end
    if ~after && ~isAsserted
        c.devices_unlinked_after = c.devices_unlinked_after + 1;
    end
end
end

function [on, why] = onAnEpoch(ctx, b)
% B names a relative_time_reference onto an epoch entity of its own session
on = false;
refs = edgeIds(b, 'time_reference_id');
if isempty(refs)
    why = 'no time_reference_id';
    return;
end
sid = did2.schema.cache.sessionIdOf(b);
whys = {};
for k = 1:numel(refs)
    t = ctxDoc(ctx, refs{k});
    if isempty(t)
        whys{end+1} = 'time reference not in the batch'; %#ok<AGROW>
        continue;
    end
    tc = classNameOf(t);
    if ~strcmp(tc, 'relative_time_reference')
        whys{end+1} = tc; %#ok<AGROW>
        continue;
    end
    for r = edgeIds(t, 'referent_id')
        e = ctxDoc(ctx, r{1});
        if isempty(e)
            whys{end+1} = 'relative to a document not in the batch'; %#ok<AGROW>
        elseif isEntityOfType(e, 'epoch')
            if strcmp(did2.schema.cache.sessionIdOf(e), sid)
                on = true;
                why = '';
                return;
            end
            whys{end+1} = 'relative to an epoch of another session'; %#ok<AGROW>
        elseif strcmp(classNameOf(e), 'entity')
            try
                h = char(did2.build.vocabularyHandle('entity_type', getIn(e, 'entity', 'type')));
            catch
                h = '?';
            end
            whys{end+1} = ['relative to an entity of type ' h]; %#ok<AGROW>
        else
            whys{end+1} = ['relative to a ' classNameOf(e)]; %#ok<AGROW>
        end
    end
end
why = strjoin(unique(whys, 'stable'), ' + ');
if isempty(why)
    why = 'relative_time_reference with no referent';
end
end

function tf = interactionClass(cn)
tf = any(strcmp(cn, {'observation', 'manipulation', 'calculation', 'interaction'}));
if tf
    return;
end
try
    tf = any(strcmp(did2.schema.cache.shared().superclasses(cn), 'interaction'));
catch
    tf = false;
end
end

function id = idOf(b)
id = '';
if isstruct(b) && isscalar(b) && isfield(b, 'base') && isstruct(b.base) ...
        && isfield(b.base, 'id')
    id = char(b.base.id);
end
end
