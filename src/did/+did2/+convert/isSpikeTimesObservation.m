function tf = isSpikeTimesObservation(body)
%ISSPIKETIMESOBSERVATION Is BODY a unit's spike-times observation?
%
%   TF = did2.convert.isSpikeTimesObservation(BODY). BODY is a document struct
%   (a did2.document's toStruct). TF is true when it is an `observation` whose
%   value kind is `time` and whose variable is GO:0001508 "action potential"
%   (by node): the per-epoch spike train did2.convert.resolveEpochProbemap
%   makes from a sorted unit's element_epoch ([spike trains as epoch bodies],
%   [spike train variable], Jess Haley, 2026-10-21).
%
%   One definition, read by the pass that links a stimulus response to it
%   (did2.convert.resolveResponseParameters) and by the round trips that
%   rebuild the v1 response and its parameters from that link
%   (did2.convert.roundtrip.stimulus_response_scalar,
%   did2.convert.roundtrip.stimulus_response_scalar_parameters_basic):
%   [response computed from the spike times] (Jess Haley, 2026-11-12).
%
%   See also did2.convert.statementKind.

tf = false;
if ~isstruct(body) || ~isscalar(body)
    return;
end
[direction, kind] = did2.convert.statementKind(body);
if ~strcmp(direction, 'observation') || ~strcmp(kind, 'time')
    return;
end
if ~isfield(body, 'statement') || ~isstruct(body.statement) ...
        || ~isscalar(body.statement) || ~isfield(body.statement, 'variable')
    return;
end
v = body.statement.variable;
tf = isstruct(v) && isscalar(v) && isfield(v, 'node') ...
    && strcmpi(char(v.node), 'GO:0001508');
end
