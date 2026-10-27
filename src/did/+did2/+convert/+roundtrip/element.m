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
%     element.name, element.reference  entity.local_identifier, read back by
%                                      did2.convert.elementNameReference
%                                      ('<name> | <reference>'; the name alone
%                                      for an element with no reference)
%     element.type                     the 'element type' assertion's value
%     element.ndi_element_class        the 'ndi element class' assertion's value
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
%   NOT REBUILT, because V2 does not keep it (the round trip reports it): for
%   an element with an underlying element, its `direct` and its `subject_id`
%   (NDI's writer copies the underlying element's subject; the migrator writes
%   only the derived_from edge). A 'modality unresolved' assertion is a
%   worklist label made from `type` and states nothing more; it is placed.
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
ndiClass = '';
underlying = '';
subject = '';
direct = [];
sortingRun = '';
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
                    used(k) = true;
                case 'ndi element class'
                    ndiClass = value;
                    used(k) = true;
                case 'modality unresolved'
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

v1.document_class = struct('class_name', 'element');
names = {'underlying_element_id', 'subject_id'};
values = {underlying, subject};
if ~isempty(sortingRun)
    names{end+1} = 'jrclust_clusters_id';
    values{end+1} = sortingRun;
end
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
blk = struct('ndi_element_class', ndiClass, 'name', name, 'type', type);
blk.reference = reference;
if ~isempty(direct)
    blk.direct = direct;
end
v1.element = blk;
end
