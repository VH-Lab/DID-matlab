function [spec, found] = stimulusPresentationSpecs(action, arg)
%STIMULUSPRESENTATIONSPECS The generator settings of the batch's v1 presentations.
%
%   A per-document migrator is called with one body and cannot follow an edge.
%   `hartley_calc` must compare its copied `stimulus_properties` VALUES with the
%   referenced `stimulus_presentation`'s generator settings before it may leave
%   them unwritten ([hartley leftovers checked], Jess Haley, 2026-10-26,
%   did-schema V_eta_go_forward_class_audit.md; TEAM-SIGN-OFF [receptive field
%   fold], "dropped only when equal"). did2.convert.v1_to_v2 therefore indexes
%   the settings of every presentation in its batch before the first migrator
%   runs, and the migrator reads them here.
%
%   did2.convert.stimulusPresentationSpecs('reset')         forget all
%   did2.convert.stimulusPresentationSpecs('load', BODIES)  index every v1
%       `stimulus_presentation` in the cell BODIES by its base.id (adds to what
%       is held; v1_to_v2 resets first)
%   [SPEC, FOUND] = did2.convert.stimulusPresentationSpecs('get', ID)
%       SPEC is the first stimulus's `parameters` struct of presentation ID;
%       FOUND is false when ID is not in the index. A presentation that is in
%       the index and carries no parameters gives FOUND true and SPEC struct().
%
%   THE SAME READ AS did2.validate.sourceCensus's presentationGeneratorSpec
%   (the first entry of `stimulus_presentation.stimuli`, its `parameters`),
%   which measured 210 of 210 equal on 20211116. A presentation not in the batch
%   is NOT a pass: the caller carries its document as v1.
%
%   See also: did2.convert.migrators_j.hartley_calc, did2.validate.sourceCensus.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get'})}
    arg = []
end

persistent index
if isempty(index) || ~isa(index, 'containers.Map')
    index = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
spec = struct();
found = false;
switch action
    case 'reset'
        index = containers.Map('KeyType', 'char', 'ValueType', 'any');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if (ischar(b) || (isstring(b) && isscalar(b))) ...
                    && contains(b, 'stimulus_presentation')
                % a JSON body (v1_to_v2 accepts them); decoded only when it
                % can be a presentation, and one that does not decode is
                % left to v1_to_v2 to refuse
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            if ~isPresentation(b); continue; end
            id = char(b.base.id);
            if isempty(id); continue; end
            index(id) = generatorSpec(b);
        end
    case 'get'
        id = char(arg);
        if ~isempty(id) && isKey(index, id)
            spec = index(id);
            found = true;
        end
end
end

function tf = isPresentation(b)
tf = isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
    && isstruct(b.document_class) && isfield(b.document_class, 'class_name') ...
    && strcmp(char(b.document_class.class_name), 'stimulus_presentation') ...
    && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id');
end

function spec = generatorSpec(b)
spec = struct();
if ~isfield(b, 'stimulus_presentation') || ~isstruct(b.stimulus_presentation)
    return;
end
blk = b.stimulus_presentation;
if ~isscalar(blk); blk = blk(1); end
if ~isfield(blk, 'stimuli'); return; end
st = blk.stimuli;
if iscell(st) && ~isempty(st); st = st{1}; end
if isempty(st) || ~isstruct(st); return; end
st = st(1);
if isfield(st, 'parameters') && isstruct(st.parameters) && ~isempty(st.parameters)
    spec = st.parameters(1);
end
end
