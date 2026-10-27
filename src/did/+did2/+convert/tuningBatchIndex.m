function [out, found] = tuningBatchIndex(action, arg)
%TUNINGBATCHINDEX What the tuning and response migrators need to know about
%   OTHER v1 documents of the batch.
%
%   A per-document migrator is called with one body and cannot follow an edge.
%   Three decisions need what an edge names (Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md):
%     [input names rebuild from the input class]  the class of the document an
%         input edge points at;
%     [tuning stimids rebuild]  a tuning curve's response (its readings'
%         `stimid`, and the presentation it names) and that presentation's
%         stimuli.
%   did2.convert.v1_to_v2 therefore indexes them before the first migrator
%   runs, as it does the presentations' generator settings for hartley_calc
%   (did2.convert.stimulusPresentationSpecs), and the migrators and their round
%   trips read them here.
%
%   did2.convert.tuningBatchIndex('reset')          forget all
%   did2.convert.tuningBatchIndex('load', BODIES)   index the v1 documents of
%       the cell BODIES (adds to what is held; v1_to_v2 resets first)
%   [CLS, FOUND] = did2.convert.tuningBatchIndex('class', ID)
%       the v1 class name of document ID, for the classes an input edge of a
%       tuning calculation or a response names (INPUT_CLASSES below)
%   [R, FOUND] = did2.convert.tuningBatchIndex('response', ID)
%       a v1 stimulus_response_scalar: R.stimid (its readings' stimulus
%       numbers, a row) and R.presentation_id
%   [S, FOUND] = did2.convert.tuningBatchIndex('presentation', ID)
%       a v1 stimulus_presentation: S, a cell of its stimuli's `parameters`
%       structs, in order (struct() for a stimulus with none)
%
%   FOUND is false when ID is not in the index. Not found is never a pass: the
%   caller carries what it could not check.
%
%   See also did2.convert.tuningStimids, did2.convert.inputEdgeNames,
%            did2.convert.stimulusPresentationSpecs.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'class', 'response', 'presentation'})}
    arg = []
end

persistent classes responses presentations
if isempty(classes) || ~isa(classes, 'containers.Map')
    classes = containers.Map('KeyType', 'char', 'ValueType', 'char');
    responses = containers.Map('KeyType', 'char', 'ValueType', 'any');
    presentations = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
out = [];
found = false;
switch action
    case 'reset'
        classes = containers.Map('KeyType', 'char', 'ValueType', 'char');
        responses = containers.Map('KeyType', 'char', 'ValueType', 'any');
        presentations = containers.Map('KeyType', 'char', 'ValueType', 'any');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        if ~iscell(bodies); return; end
        for k = 1:numel(bodies)
            b = bodies{k};
            if ischar(b) || (isstring(b) && isscalar(b))
                % a JSON body (v1_to_v2 accepts them): decoded only when it can
                % be one of the classes held here
                if ~mentionsAny(char(b))
                    continue;
                end
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            [id, cls] = identity(b);
            if isempty(id) || ~any(strcmp(cls, INPUT_CLASSES()))
                continue;
            end
            classes(id) = cls;
            switch cls
                case 'stimulus_response_scalar'
                    responses(id) = responseOf(b);
                case 'stimulus_presentation'
                    presentations(id) = stimuliOf(b);
            end
        end
    case 'class'
        id = char(arg);
        if ~isempty(id) && isKey(classes, id)
            out = classes(id);
            found = true;
        else
            out = '';
        end
    case 'response'
        id = char(arg);
        if ~isempty(id) && isKey(responses, id)
            out = responses(id);
            found = true;
        end
    case 'presentation'
        id = char(arg);
        if ~isempty(id) && isKey(presentations, id)
            out = presentations(id);
            found = true;
        end
end
end

function c = INPUT_CLASSES()
%INPUT_CLASSES The v1 classes an input edge of a tuning calculation or a
%   stimulus response names (did2.convert.inputEdgeNames).
c = {'stimulus_response_scalar', 'stimulus_tuningcurve', 'tuningcurve_calc', ...
    'stimulus_presentation', 'contrasttuning_calc', 'contrast_tuning_calc', ...
    'control_stimulus_ids'};
end

function tf = mentionsAny(s)
tf = false;
names = INPUT_CLASSES();
for k = 1:numel(names)
    if contains(s, names{k})
        tf = true;
        return;
    end
end
end

function [id, cls] = identity(b)
id = '';
cls = '';
if ~isstruct(b) || ~isscalar(b)
    return;
end
try
    st = did2.convert.v1read.readStamp(b);
    cls = char(st.class_name);
    bs = did2.convert.v1read.readBase(b);
    if ischar(bs.id)
        id = bs.id;
    end
catch
    id = '';
end
end

function r = responseOf(b)
r = struct('stimid', [], 'presentation_id', '');
try
    deps = did2.convert.v1read.readDependsOn(b);
    for k = 1:numel(deps)
        if strcmp(deps(k).name, 'stimulus_presentation_id')
            r.presentation_id = char(deps(k).document_id);
        end
    end
catch
end
if isfield(b, 'stimulus_response_scalar') && isstruct(b.stimulus_response_scalar) ...
        && isscalar(b.stimulus_response_scalar) ...
        && isfield(b.stimulus_response_scalar, 'responses') ...
        && isstruct(b.stimulus_response_scalar.responses) ...
        && isscalar(b.stimulus_response_scalar.responses) ...
        && isfield(b.stimulus_response_scalar.responses, 'stimid')
    s = b.stimulus_response_scalar.responses.stimid;
    if isnumeric(s)
        r.stimid = reshape(double(s), 1, []);
    end
end
end

function c = stimuliOf(b)
c = {};
if ~isfield(b, 'stimulus_presentation') || ~isstruct(b.stimulus_presentation)
    return;
end
blk = b.stimulus_presentation;
if ~isscalar(blk); blk = blk(1); end
if ~isfield(blk, 'stimuli'); return; end
st = blk.stimuli;
if isstruct(st)
    st = num2cell(reshape(st, 1, []));
end
if ~iscell(st); return; end
c = cell(1, numel(st));
for k = 1:numel(st)
    p = struct();
    s = st{k};
    if isstruct(s) && isscalar(s) && isfield(s, 'parameters') && isstruct(s.parameters) ...
            && ~isempty(s.parameters)
        p = s.parameters(1);
    end
    c{k} = p;
end
end
