function [v1, spec] = element(bodies, ctx)
%ELEMENT Rebuild a v1 `element` from what did2.convert.migrators_j.element
%   emitted when it CONVERTED it: one `entity` (device, cell or group), its
%   term assertions, and its relations.
%
%   [V1, SPEC] = did2.convert.roundtrip.element(BODIES). V1 is the element in
%   NDI's v1 shape (element.json + base.json at the locked NDI-matlab `main`,
%   3cb19a8, as ndi.element/newdocument writes it):
%
%     base.id, session_id, datestamp   the entity (rebuildBase)
%     element.name                     entity.name, exactly (Decided by Jess
%                                      Haley, 2026-10-29 [element name and
%                                      reference stored apart])
%     element.reference                what follows that name in
%                                      entity.local_identifier
%                                      ('<name> | <reference>', or the name
%                                      alone for no reference; a number when
%                                      it reads as one), by
%                                      did2.convert.elementNameReferenceApart
%     base.name                        '' (ndi.element/newdocument writes '';
%                                      the migrator carries an element whose
%                                      base.name is not empty)
%     A DOCUMENT MIGRATED BEFORE 2026-10-29 (its entity.name, if any, is the
%     v1 base.name, [v1 name is the entity name], 2026-10-27, and does not
%     lead its local_identifier): element.name and element.reference are
%     read from local_identifier alone, did2.convert.elementNameReference
%     (the split at the last ' | ', or the old ' (ref X)' form), and
%     base.name is entity.name ('' when the entity has none).
%     element.type                     the 'element type' assertion's value;
%                                      with none, the device kind (the
%                                      Equipment Type assertion) read back by
%                                      did2.convert.elementTypeOfKind, where
%                                      one v1 type has that kind ([element
%                                      type is a device kind term]: "the round
%                                      trip rebuilds the v1 word from kind
%                                      plus mode"); a kind several types
%                                      share, with no 'element type'
%                                      assertion, the kind plus the mode
%                                      terms of the recording observations
%                                      in CTX whose instrument it is
%                                      (did2.convert.elementTypeOfKindAndMode;
%                                      resolveEpochProbemap drops the
%                                      assertion of a recorded probe whose
%                                      modes rebuild it, [recording mode
%                                      terms]); with no mode of that kind (a
%                                      probe that never recorded, [clamp
%                                      mode of unrecorded probe dropped], or
%                                      a bare patch or sharp) its general
%                                      type, 'patch' or 'sharp', by
%                                      did2.convert.elementGeneralTypeOfKind
%                                      (Decided by Jess Haley, 2026-11-06,
%                                      "Read back patch"; a microscope has
%                                      none and rebuilds ''); with neither, a sorted
%                                      unit's entity type (`cell` or
%                                      `group`, by node) rebuilds 'spikes'
%                                      ([cell spellings are one meaning],
%                                      [cell spellings amended], Jess Haley,
%                                      2026-10-27). The three v1 spellings
%                                      `spikes`, `neuron` and `cell` are one
%                                      meaning: a v1 type that is one of them
%                                      and a rebuilt type that is another are
%                                      the same (spec.same, `equivalent`)
%     element.ndi_element_class        the 'ndi element class' assertion's
%                                      value while one is written ([assertion
%                                      wins while written] (1)); with none,
%                                      rebuilt from what the element is
%                                      (rebuildClass, did2.convert.
%                                      elementClassOfKind; [ndi element class
%                                      not kept], [element recognised by its
%                                      links], [ensemble has members]): a
%                                      device the probetype2object.json
%                                      class of its type, a cell
%                                      'ndi.neuron', a Group with `member_of`
%                                      relations in CTX 'ndi.element.ensemble'
%                                      (and type 'ensemble'), a Group with
%                                      none 'ndi.neuron' (and type 'spikes').
%                                      In the whole batch (CTX), a device
%                                      with no recording observation and no
%                                      `connected to` wiring is not an
%                                      element and rebuilds '' ([unlinked
%                                      device is not an element], Jess Haley,
%                                      2026-11-11; wholeBatch reports it).
%                                      An ensemble reads as the latter before
%                                      NDI-matlab's second pass and is
%                                      checked after it (rebuildClass)
%     (a device's Equipment Type assertion states its device kind,
%     did2.convert.elementDeviceKind; it is placed when its node is the kind
%     decided for the rebuilt type, and reported unplaced otherwise)
%     (an n-trode's "number of electrodes" assertion, EMPTY:0000408, is read
%     from its epochprobemap channel list, not from the element ([n-trode
%     count from the channel list], Jess Haley, 2026-10-29): it rebuilds no
%     element field, and is placed for one assertion on an n-trode and
%     reported unplaced otherwise)
%     element.direct, depends_on       the lineage relation, in the order the
%                                      template lists the edges
%                                      (underlying_element_id, subject_id) and
%                                      any other edge after them:
%         observes X          direct true, subject_id X (a direct element)
%         derived_from X      underlying_element_id X (the migrator's first
%                             branch). An element with no underlying element
%                             that derives from its subject writes the same
%                             relation; the round trip reports that case.
%         wasDerivedFrom R    jrclust_clusters_id R (the sorting run)
%
%   A SORTED UNIT ON ITS PROBE (type spikes, neuron or cell, with an
%   underlying element): Decided by Jess Haley, 2026-10-27 [unit direct and
%   subject rebuild from the probe] -- `direct` is rebuilt as 0 and
%   `subject_id` as the underlying element's subject, read from the batch's
%   v1 elements (did2.convert.elementSubjects, loaded by v1_to_v2; the
%   migrator carries a unit whose values differ). When the underlying element
%   is not in that index, `subject_id` is left empty and the check reports it.
%
%   NOT REBUILT, because v2 does not keep it (the round trip reports it): for
%   any OTHER element with an underlying element, its `direct` and its
%   `subject_id`. A 'modality unresolved' assertion is a worklist label made
%   from `type` and states nothing more; it is placed.
%
%   THE `observes` RELATION A BATCH PASS RETIRED. [V1, SPEC] =
%   did2.convert.roundtrip.element(BODIES, CTX), in the whole-batch round trip
%   (did2.convert.roundtrip.wholeBatch; [whole-batch round trip], Jess Haley,
%   2026-10-27): did2.convert.resolveEpochProbemap retires a probe's loose
%   `observes` relation once a recording observation carries the same
%   (instrument, specimen) pair as its `instrument_id` / `entity_id` edges
%   (`observes_retired`; [epoch files as data bodies], Jess Haley,
%   2026-10-21), and a stimulator's once a manipulation carries the same
%   (instrument, subject) pair ([observes retires on a matching
%   manipulation], Jess Haley, 2026-11-12). When BODIES holds no lineage
%   relation, the observations and manipulations in CTX (the index of the
%   final batch) whose `instrument_id` is this entity are read: one specimen
%   among them is `subject_id`, with `direct` true, as the retired relation
%   stated. Several specimens are reported, not chosen. They are read, never
%   placed.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.element.

arguments
    bodies cell
    ctx = []
end

spec = emptySpec();
v1 = struct();
ent = [];
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'entity')
        ent = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(ent)
    spec.unplaced{end+1} = 'no entity was emitted';
    return;
end
[base, entity] = rebuildBase(ent);
[name, reference, apart] = did2.convert.elementNameReferenceApart( ...
    fieldText(entity, 'name'), fieldText(entity, 'local_identifier'));
baseName = '';
if ~apart
    baseName = fieldText(entity, 'name');   % migrated before 2026-10-29
end

type = '';
hasType = false;
ndiClass = '';
underlying = '';
subject = '';
direct = [];
sortingRun = '';
kindNodes = {};
nElectrodeCounts = 0;
for k = 1:numel(bodies)
    if used(k); continue; end
    b = bodies{k};
    switch classNameOf(b)
        case 'assertion'
            if ~isequal(edgeIds(b, 'entity_id'), {base.id})
                continue;
            end
            [~, variable] = termParts(getIn(b, 'statement', 'variable'));
            [~, value] = termParts(getIn(b, 'term', 'value'));
            switch lower(variable)
                case 'element type'
                    type = value;
                    hasType = true;
                    used(k) = true;
                case 'ndi element class'
                    ndiClass = value;
                    used(k) = true;
                case 'modality unresolved'
                    used(k) = true;
                case 'number of electrodes'
                    nElectrodeCounts = nElectrodeCounts + 1;
                    used(k) = true;
                case 'equipment type'
                    [kindNode, ~] = termParts(getIn(b, 'term', 'value'));
                    kindNodes{end+1} = kindNode; %#ok<AGROW>
                    used(k) = true;
            end
        case 'directed_relation'
            child = edgeIds(b, 'child_id');
            parent = edgeIds(b, 'parent_id');
            if ~isequal(child, {base.id}) || ~isscalar(parent)
                continue;
            end
            rel = getIn(b, 'directed_relation', 'relation');
            [node, ~] = termParts(rel);
            handle = did2.build.vocabularyHandle('relation', rel);
            if strcmp(handle, 'observes') && isempty(subject) && isempty(direct)
                subject = parent{1};
                direct = true;
                used(k) = true;
            elseif strcmp(handle, 'derived_from') && isempty(underlying) && isempty(direct)
                underlying = parent{1};
                used(k) = true;
            elseif sameCurie(node, 'prov:wasDerivedFrom') && isempty(sortingRun)
                sortingRun = parent{1};
                used(k) = true;
            end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in an element', ...
        k, classNameOf(bodies{k}));
end
% the `observes` relation resolveEpochProbemap retired: read from the
% observations and manipulations that carry its pair (see THE `observes`
% RELATION above)
if isempty(subject) && isempty(underlying) && isempty(direct) && ~isempty(ctx)
    specimens = {};
    for k = ctxReferrers(ctx, base.id)
        b = ctx.docs{k};
        if any(strcmp(classNameOf(b), {'observation', 'manipulation'})) ...
                && isequal(edgeIds(b, 'instrument_id'), {base.id})
            specimens = [specimens, edgeIds(b, 'entity_id')]; %#ok<AGROW>
        end
    end
    specimens = unique(specimens);
    if isscalar(specimens)
        subject = specimens{1};
        direct = true;
    elseif numel(specimens) > 1
        spec.unplaced{end+1} = sprintf(['the observations and manipulations this ' ...
            'element is the instrument of name %d specimens (a v1 element has one ' ...
            'subject)'], numel(specimens));
    end
end
% no 'element type' assertion: the type is the one its device kind names
if ~hasType && isscalar(kindNodes)
    type = did2.convert.elementTypeOfKind(kindNodes{1});
    % a kind several types share: the kind plus the mode of its recording
    % observations in CTX ([recording mode terms]: resolveEpochProbemap drops
    % the statement of a recorded probe whose modes rebuild it)
    if isempty(type)
        type = did2.convert.elementTypeOfKindAndMode(kindNodes{1}, ...
            recordingModes(ctx, base.id));
    end
    % with no mode of that kind (a probe that never recorded, or a bare
    % patch or sharp): its general type, 'patch' or 'sharp' (Jess Haley,
    % 2026-11-06, "Read back patch"); '' for a microscope
    if isempty(type)
        type = did2.convert.elementGeneralTypeOfKind(kindNodes{1});
    end
end
% neither: a sorted unit, whose entity type (cell or group) is all that is
% kept of its v1 type ([cell spellings are one meaning], [cell spellings
% amended]); 'spikes' is the spelling NDI's writers use
if ~hasType && isempty(kindNodes) && isUnitEntity(entity)
    type = 'spikes';
end
% THE NDI ELEMENT CLASS, where no 'ndi element class' assertion states it
% (while one is written it wins: [assertion wins while written] (1))
if isempty(ndiClass)
    [ndiClass, type, spec] = rebuildClass(entity, type, base.id, ctx, spec);
end
if any(strcmp(strtrim(type), UNIT_SPELLINGS()))
    spec.same(end+1) = struct('path', 'element.type', ...
        'fn', @(a, ~) (ischar(a) || (isstring(a) && isscalar(a))) ...
            && any(strcmp(strtrim(char(a)), UNIT_SPELLINGS())), ...
        'why', ['`spikes`, `neuron` and `cell` are three spellings of one meaning ' ...
        '([cell spellings are one meaning], [cell spellings amended], Jess Haley, ' ...
        '2026-10-27)']);
end
% the device kind restates the type ([element type is a device kind term]):
% exactly the decided kind of the rebuilt type, or it is not placed
want = did2.convert.elementDeviceKind(type);
% [clamp mode of unrecorded probe dropped] (Jess Haley, 2026-11-03): a probe of
% a kind several types share (patch electrode, sharp electrode, microscope)
% that never recorded keeps its device kind and no `element type` statement;
% its mode is not rebuilt (element.type: an accepted loss in
% did2.convert.roundtrip.wholeBatch), and its one kind is placed. A patch or
% sharp electrode rebuilds its general type (above), whose decided kind is
% that kind, so it is placed below; a microscope rebuilds '' and is placed here
modeDropped = ~hasType && isscalar(kindNodes) && isempty(type) ...
    && ~isempty(kindNodes{1}) && isempty(did2.convert.elementTypeOfKind(kindNodes{1}));
% (a microscope whose mode was not kept rebuilds no type, and so no class)
for k = 1:numel(kindNodes)
    if modeDropped
        continue;
    end
    if isempty(want) || ~sameCurie(kindNodes{k}, want.node) || numel(kindNodes) > 1
        spec.unplaced{end+1} = sprintf(['an Equipment Type assertion (%s) is not ' ...
            'the device kind decided for element type "%s"'], kindNodes{k}, type); %#ok<AGROW>
    end
end
% [n-trode count from the channel list]: one count, on an n-trode only
if nElectrodeCounts > 0 && (nElectrodeCounts > 1 || ~strcmp(strtrim(type), 'n-trode'))
    spec.unplaced{end+1} = sprintf(['%d "number of electrodes" assertion(s) on ' ...
        'element type "%s" (one, on an n-trode, is placed)'], nElectrodeCounts, type);
end
% [unit direct and subject rebuild from the probe] (Jess Haley, 2026-10-27)
if ~isempty(underlying) && isempty(direct) && isempty(subject) ...
        && any(strcmp(strtrim(type), UNIT_SPELLINGS()))
    direct = false;
    subject = did2.convert.elementSubjects('get', underlying);
end

v1.document_class = struct('class_name', 'element');
names = {'underlying_element_id', 'subject_id'};
values = {underlying, subject};
if ~isempty(sortingRun)
    names{end+1} = 'jrclust_clusters_id';
    values{end+1} = sortingRun;
end
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', baseName, 'datestamp', base.datestamp);
blk = struct('ndi_element_class', ndiClass, 'name', name, 'type', type);
blk.reference = reference;
if ~isempty(direct)
    blk.direct = direct;
end
v1.element = blk;
end

function [ndiClass, type, spec] = rebuildClass(entity, type, id, ctx, spec)
%REBUILDCLASS element.ndi_element_class from what the element is, and a
%   Group's type from its members. Decided by Jess Haley (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): [ndi element class not
%   kept] (2026-10-27), [element recognised by its links], [ensemble has
%   members] and [assertion wins while written] (2026-11-10). The rule of
%   NDI-matlab's ndi.vintage.elementFields (#1214, 39d8603c): a device takes
%   the class probetype2object.json names for its type; a `cell` is one
%   unit, 'ndi.neuron'; a `Group` that `member_of` relations in CTX point
%   into is an ensemble ('ndi.element.ensemble', type 'ensemble'); a `Group`
%   with none is one multi-unit ('ndi.neuron', type 'spikes').
%
%   AN ENSEMBLE BEFORE NDI'S SECOND PASS. That pass writes an ensemble's
%   `member_of` relations; this round trip runs before it, so an ensemble
%   (its 'element type' assertion, still written for resolveEpochProbemap,
%   says 'ensemble') reads as a multi-unit here, as it does in NDI-matlab
%   until the pass has run ([ensemble has members]: "an ensemble whose
%   `member_of` relations the NDI second pass has not yet written reads as a
%   multi-unit"). [assertion wins while written] (1): "ensembles are checked
%   after NDI-matlab's second pass writes their `member_of` relations". So
%   its v1 class and type are not compared here: spec.same takes v1
%   'ndi.element.ensemble' / 'ensemble' as that multi-unit reading, with
%   that decision as the reason, reported `equivalent`, and nothing else.
ndiClass = '';
if ~isstruct(entity) || ~isfield(entity, 'type')
    return;
end
if did2.build.isVocabulary(entity.type, 'entity_type', 'device')
    % [unlinked device is not an element] (Decided by Jess Haley, 2026-11-11):
    % in the whole batch (CTX), a device with no recording observation
    % (`instrument_id`) and no wiring (`connected to`, RO:0002170) is not an
    % element, as NDI-matlab's ndi.vintage.linkedElements reads it: it
    % rebuilds no class, and did2.convert.roundtrip.wholeBatch reports its v1
    % class as that decided difference. With no CTX (a per-class round trip)
    % the links are not readable, so the class is rebuilt from the type.
    if ~isempty(ctx) && isempty(deviceLinks(ctx, id))
        return;
    end
    ndiClass = did2.convert.elementClassOfKind('probe', type);
elseif did2.build.isVocabulary(entity.type, 'entity_type', 'cell')
    ndiClass = did2.convert.elementClassOfKind('unit', type);
elseif did2.build.isVocabulary(entity.type, 'entity_type', 'group')
    statedEnsemble = strcmp(strtrim(type), 'ensemble');
    if hasMembers(ctx, id)
        type = 'ensemble';
        ndiClass = did2.convert.elementClassOfKind('ensemble', type);
    else
        type = 'spikes';
        ndiClass = did2.convert.elementClassOfKind('unit', type);
        if statedEnsemble
            why = ['an ensemble is checked after NDI-matlab''s second pass writes ' ...
                'its member_of relations; before it, it reads as one multi-unit ' ...
                '([assertion wins while written] (1), [ensemble has members], Jess ' ...
                'Haley, 2026-11-10)'];
            spec.same(end+1) = struct('path', 'element.ndi_element_class', ...
                'fn', @(a, r) isText(a, 'ndi.element.ensemble') && isText(r, 'ndi.neuron'), ...
                'why', why);
            spec.same(end+1) = struct('path', 'element.type', ...
                'fn', @(a, r) isText(a, 'ensemble') && isText(r, 'spikes'), 'why', why);
        end
    end
end
end

function tf = isText(v, want)
tf = (ischar(v) || (isstring(v) && isscalar(v))) && strcmp(strtrim(char(v)), want);
end

function tf = hasMembers(ctx, id)
% a `member_of` directed_relation in CTX whose parent is ID
tf = false;
for k = ctxReferrers(ctx, id)
    b = ctx.docs{k};
    if ~strcmp(classNameOf(b), 'directed_relation') || ~isequal(edgeIds(b, 'parent_id'), {id})
        continue;
    end
    if strcmp(did2.build.vocabularyHandle('relation', ...
            getIn(b, 'directed_relation', 'relation')), 'member_of')
        tf = true;
        return;
    end
end
end

function modes = recordingModes(ctx, id)
% the method term nodes of the observations in CTX whose instrument is ID
% (resolveEpochProbemap writes the mode there, inline)
modes = {};
for k = ctxReferrers(ctx, id)
    b = ctx.docs{k};
    if ~strcmp(classNameOf(b), 'observation') || ~isequal(edgeIds(b, 'instrument_id'), {id})
        continue;
    end
    m = getIn(b, 'interaction', 'method');
    if isstruct(m) && isscalar(m) && isfield(m, 'term')
        [node, ~] = termParts(m.term);
        if ~isempty(node)
            modes{end+1} = node; %#ok<AGROW>
        end
    end
end
end

function s = UNIT_SPELLINGS()
% the v1 element types that are one meaning, a sorted unit ([cell spellings
% are one meaning], Jess Haley, 2026-10-27)
s = {'spikes', 'neuron', 'cell'};
end

function tf = isUnitEntity(entity)
% the entity type of a sorted unit: cell or group, by node ([vocabulary
% nodes] L2), so the stored name ('cell', 'Group') is notation
tf = false;
if ~isstruct(entity) || ~isfield(entity, 'type')
    return;
end
tf = did2.build.isVocabulary(entity.type, 'entity_type', 'cell') ...
    || did2.build.isVocabulary(entity.type, 'entity_type', 'group');
end
