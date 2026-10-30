function u = responseUnitsBack(leaf, value)
%RESPONSEUNITSBACK The v1 `response_units` rebuilt from a converted tuning
%   calculation: the name of the registered term whose `synonyms` hold the
%   spelling jTuningCurve (jResponseVariable) recognised, else the unit's label.
%
%   U = responseUnitsBack(LEAF, VALUE). VALUE is LEAF's tuning_curve.value
%   (or the abs calculation's). jResponseVariable writes
%     a spikes-per-second spelling -> unit om:hertz (synonyms on om:hertz)
%     a dF/F spelling              -> unit om:one, variable EMPTY:0000397
%                                     (synonyms on EMPTY:0000397, not om:one)
%     anything else                -> the spelling as the unit's label
%   so a unit om:one under the variable EMPTY:0000397 comes back as that
%   variable's name ('dF/F'), and every other unit as its label. The v1
%   spelling is compared with U by sameTermSpelling (SPEC.same): Decided by
%   Jess Haley, 2026-10-26 [spelling is notation].
u = '';
if ~isstruct(value) || ~isfield(value, 'response_unit')
    return;
end
[node, u] = termParts(value.response_unit);
if strcmpi(node, 'om:one')
    [vnode, vname] = termParts(getIn(leaf, 'statement', 'variable'));
    if strcmpi(vnode, 'EMPTY:0000397') && ~isempty(vname)
        u = vname;
    end
end
end
