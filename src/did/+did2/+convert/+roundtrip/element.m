function [v1, spec] = element(bodies)
%ELEMENT Rebuild a v1 `element` from what did2.convert.migrators_j.element
%   emitted when it CONVERTED it: one `entity` (device, cell or group), its
%   term assertions, and its relations.
%
%   [V1, SPEC] = did2.convert.roundtrip.element(BODIES). V1 is the element in
%   NDI's v1 shape (element.json + base.json at the locked NDI-matlab `main`,
%   3cb19a8, as ndi.element/newdocument writes it):
%
%     base.id, session_id, datestamp   the entity (rebuildBase)
%     base.name                        entity.name ('' when the entity has
%                                      none; [v1 name is the entity name],
%                                      Jess Haley, 2026-10-27)
%     element.name, element.reference  entity.local_identifier, read back by
%                                      did2.convert.elementNameReference
%                                      ('<name> | <reference>'; the name alone
%                                      for an element with no reference)
%     element.type                     the 'element type' assertion's value;
%                                      with none, the device kind (the
%                                      Equipment Type assertion) read back by
%                                      did2.convert.elementTypeOfKind, where
%                                      one v1 type has that kind ([element
%                                      type is a device kind term]: "the round
%                                      trip rebuilds the v1 word from kind
%                                      plus mode"; a kind several types share
%                                      keeps the 'element type' assertion
%                                      until its mode is written, so needs no
%                                      mode here)
%     element.ndi_element_class        the 'ndi element class' assertion's value
%     (a device's Equipment Type assertion states its device kind,
%     did2.convert.elementDeviceKind; it is placed when its node is the kind
%     decided for the rebuilt type, and reported unplaced otherwise)
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
%   NOT REBUILT, because V2 does not keep it (the round trip reports it): for
%   any OTHER element with an underlying element, its `direct` and its
%   `subject_id`. A 'modality unresolved' assertion is a worklist label made
%   from `type` and states nothing more; it is placed.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.element.

arguments
    bodies cell
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
[name, reference] = did2.convert.elementNameReference(fieldText(entity, 'local_identifier'));

type = '';
hasType = false;
ndiClass = '';
underlying = '';
subject = '';
direct = [];
sortingRun = '';
kindNodes = {};
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
% no 'element type' assertion: the type is the one its device kind names
if ~hasType && isscalar(kindNodes)
    type = did2.convert.elementTypeOfKind(kindNodes{1});
end
% the device kind restates the type ([element type is a device kind term]):
% exactly the decided kind of the rebuilt type, or it is not placed
want = did2.convert.elementDeviceKind(type);
for k = 1:numel(kindNodes)
    if isempty(want) || ~sameCurie(kindNodes{k}, want.node) || numel(kindNodes) > 1
        spec.unplaced{end+1} = sprintf(['an Equipment Type assertion (%s) is not ' ...
            'the device kind decided for element type "%s"'], kindNodes{k}, type); %#ok<AGROW>
    end
end
% [unit direct and subject rebuild from the probe] (Jess Haley, 2026-10-27)
if ~isempty(underlying) && isempty(direct) && isempty(subject) ...
        && any(strcmp(strtrim(type), {'spikes', 'neuron', 'cell'}))
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
    'name', fieldText(entity, 'name'), 'datestamp', base.datestamp);
blk = struct('ndi_element_class', ndiClass, 'name', name, 'type', type);
blk.reference = reference;
if ~isempty(direct)
    blk.direct = direct;
end
v1.element = blk;
end
