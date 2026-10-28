function [label, found] = unitQualityLabels(action, arg)
%UNITQUALITYLABELS The single/multi label the batch's sorting runs give each
%   sorted unit.
%
%   Decided by Jess Haley, 2026-10-26 [sorted units are cells or groups]
%   (did-schema V_eta_go_forward_class_audit.md): a sorted unit (a v1 `element`
%   of type `spikes`) is a `cell` when it is a SINGLE unit and a `Group` of
%   unidentified cells when it is a MULTI-unit cluster; "whether it is single
%   or multi is an assertion by the sorting run". In v1 that assertion is not
%   on the element: it is `quality_label` ('single' / 'multi') of the
%   `neuron_extracellular` document whose `element_id` names the element.
%   [unlabelled units need a map]: a unit with no label is carried as v1
%   (carry-062). [sorter labels map] (Jess Haley, 2026-10-27): a Kilosort/phy
%   label maps, `good` to single and `mua` to multi; `noise` is carried. A per-document migrator cannot follow an edge, so
%   did2.convert.v1_to_v2 indexes the labels of every v1 neuron_extracellular in
%   its batch before the first migrator runs (as stimulusPresentationSpecs).
%
%   did2.convert.unitQualityLabels('reset')         forget all
%   did2.convert.unitQualityLabels('load', BODIES)  index every v1
%       `neuron_extracellular` in the cell BODIES by the id its `element_id`
%       edge names (adds to what is held; v1_to_v2 resets first)
%   did2.convert.unitQualityLabels('add', PAIRS)  add labels a caller already
%       holds, PAIRS = {ELEMENTID, LABEL, ELEMENTID, LABEL, ...} (v1_to_v2's
%       'UnitQualityLabels': a caller migrating an element whose
%       neuron_extracellular is not in the same batch, or a test). A label the
%       batch also states and that differs is 'conflict'.
%   [LABEL, FOUND] = did2.convert.unitQualityLabels('get', ELEMENTID)
%       LABEL is 'single' or 'multi', or a Kilosort/phy curation label 'good',
%       'mua' or 'noise' (as written, case and edge blanks aside: NDI-matlab
%       main +ndi/+fun/+probe/+import/+kilosort/probe.m writes the cluster's
%       label, ne.quality_label = char(cluster_labels(ci)), matched
%       case-insensitively)
%       when every neuron_extracellular naming ELEMENTID states that one label;
%       '' when none in the batch names it or none states a label (FOUND
%       false); any other label as written; 'conflict' when two state
%       different labels (FOUND true).
%
%   A label not in the batch is NOT a pass: element.m carries the unit.
%
%   See also did2.convert.migrators_j.element,
%            did2.convert.migrators_j.neuron_extracellular.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'add', 'get'})}
    arg = []
end

persistent index
if isempty(index) || ~isa(index, 'containers.Map')
    index = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
label = '';
found = false;
switch action
    case 'reset'
        index = containers.Map('KeyType', 'char', 'ValueType', 'char');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if ischar(b) || (isstring(b) && isscalar(b))
                if ~contains(b, 'neuron_extracellular'); continue; end
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            if ~isUnit(b); continue; end
            id = elementIdOf(b);
            lab = labelOf(b.neuron_extracellular);
            if isempty(id) || isempty(lab); continue; end
            if isKey(index, id) && ~strcmp(index(id), lab)
                index(id) = 'conflict';
            elseif ~isKey(index, id)
                index(id) = lab;
            end
        end
    case 'add'
        pairs = arg;
        for k = 1:2:numel(pairs) - 1
            id = char(pairs{k});
            lab = labelOf(struct('quality_label', pairs{k + 1}));
            if isempty(id) || isempty(lab); continue; end
            if isKey(index, id) && ~strcmp(index(id), lab)
                index(id) = 'conflict';
            elseif ~isKey(index, id)
                index(id) = lab;
            end
        end
    case 'get'
        id = char(arg);
        if ~isempty(id) && isKey(index, id)
            label = index(id);
            found = true;
        end
end
end

function tf = isUnit(b)
tf = isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
    && isstruct(b.document_class) && isfield(b.document_class, 'class_name') ...
    && strcmp(char(b.document_class.class_name), 'neuron_extracellular') ...
    && isfield(b, 'neuron_extracellular') && isstruct(b.neuron_extracellular) ...
    && isscalar(b.neuron_extracellular);
end

function id = elementIdOf(b)
id = '';
try
    deps = did2.convert.v1read.readDependsOn(b, 'Name', '^element_id$');
catch
    return;
end
if ~isempty(deps)
    id = char(deps(1).document_id);
end
end

function lab = labelOf(blk)
lab = '';
if isfield(blk, 'quality_label')
    v = blk.quality_label;
    if ischar(v) || (isstring(v) && isscalar(v))
        lab = strtrim(char(v));
        if any(strcmpi(lab, {'single', 'multi', 'good', 'mua', 'noise'}))
            lab = lower(lab);
        end
    end
end
end
