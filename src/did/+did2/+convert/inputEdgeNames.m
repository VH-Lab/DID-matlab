function names = inputEdgeNames(ids, defaults)
%INPUTEDGENAMES The v1 names of a calculation's input edges, rebuilt from the
%   class of the document each input points at.
%
%   NAMES = did2.convert.inputEdgeNames(IDS, DEFAULTS). IDS are a V2
%   calculation's `input_id` edges, in order (a cellstr). NAMES{k} is the v1
%   edge name input k had:
%     - the class of document IDS{k}, when the batch index holds it
%       (did2.convert.tuningBatchIndex 'class'), gives the name (CLASS_NAMES
%       below); a class that numbers its edges (contrasttuning_id_1, _2, ...)
%       takes the next number among the inputs of that class, in order;
%     - otherwise DEFAULTS{k}, the name the class's writer gives its k-th input
%       (e.g. {'stimulus_response_scalar_id'} for a tuningcurve_calc), or ''
%       past the end of DEFAULTS.
%
%   THE DECISION. Decided by Jess Haley, 2026-10-27 [input names rebuild from
%   the input class] (did-schema V_eta_go_forward_class_audit.md): "a v1
%   calculation's named `depends_on` input links (e.g. `stimulus_tuningcurve`'s
%   `stimulus_response_scalar_id`) become unnamed `input_id` edges on the V2
%   `calculation`; the round trip rebuilds each v1 name from the class of the
%   document the input points at; a calculation with two inputs of one class
%   under different v1 names is carried whole as v1, kind `malformed`."
%   The migrators call this with the v1 edges' ids and carry the document when
%   the names it gives are not the v1 names (two inputs of one class under
%   different names give one name twice); the round trips call it to name the
%   edges back. Both read the same index, so a converted document's edges are
%   named back as v1 named them.
%
%   See also did2.convert.tuningBatchIndex.

arguments
    ids cell
    defaults cell = {}
end

names = cell(1, numel(ids));
seen = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(ids)
    [cls, found] = did2.convert.tuningBatchIndex('class', ids{k});
    stem = '';
    numbered = false;
    if found
        [stem, numbered] = classEdge(cls);
    end
    if isempty(stem)
        if k <= numel(defaults)
            names{k} = char(defaults{k});
        else
            names{k} = '';
        end
        continue;
    end
    if numbered
        n = 1;
        if isKey(seen, stem); n = seen(stem) + 1; end
        seen(stem) = n;
        names{k} = sprintf('%s%d', stem, n);
    else
        names{k} = stem;
    end
end
end

function [stem, numbered] = classEdge(cls)
%CLASSEDGE The v1 edge name a writer gives an input of class CLS (the writers:
%   NDI-matlab locked `main` ndi.calc.stimulus.tuningcurve,
%   ndi.app.stimulus.tuning_response; NDIcalc-vis-matlab 00e3e0f
%   ndi.calc.vis.*). A tuningcurve_calc IS-A stimulus_tuningcurve.
numbered = false;
switch cls
    case 'stimulus_response_scalar'
        stem = 'stimulus_response_scalar_id';
    case {'stimulus_tuningcurve', 'tuningcurve_calc'}
        stem = 'stimulus_tuningcurve_id';
    case 'stimulus_presentation'
        stem = 'stimulus_presentation_id';
    case 'control_stimulus_ids'
        stem = 'stimulus_control_id';
    case {'contrasttuning_calc', 'contrast_tuning_calc'}
        stem = 'contrasttuning_id_';
        numbered = true;
    otherwise
        stem = '';
end
end
