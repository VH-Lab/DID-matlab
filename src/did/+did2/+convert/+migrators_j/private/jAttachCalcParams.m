function bodies = jAttachCalcParams(bodies, preBody, calcBlockName)
%JATTACHCALCPARAMS Retain a calculator's input_parameters on the packet-head
%   observation, so the decomposed graph packet stays reproducible (D-C /
%   Option B). A did_v1 <x>_calc document carries BOTH the result block (which
%   the delegated result-class migrator decomposes) and a calc block
%   (<calcBlockName>) holding `input_parameters` -- the knobs that produced the
%   computation. We stash those on the curve observation (bodies{1}, the packet
%   head) as subject_interaction.method_parameters, once per calculation. No-op
%   when the head has no interaction block (carry-unchanged) or the calc block
%   carries no input_parameters.
if isempty(bodies) || ~isstruct(bodies{1}) ...
        || ~isfield(bodies{1}, 'subject_interaction') ...
        || ~isstruct(bodies{1}.subject_interaction)
    return;
end
if isfield(preBody, calcBlockName) && isstruct(preBody.(calcBlockName)) ...
        && isfield(preBody.(calcBlockName), 'input_parameters') ...
        && isstruct(preBody.(calcBlockName).input_parameters)
    bodies{1}.subject_interaction.method_parameters = ...
        preBody.(calcBlockName).input_parameters;
end
end
