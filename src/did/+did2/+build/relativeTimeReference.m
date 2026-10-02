function doc = relativeTimeReference(referentId, options)
%RELATIVETIMEREFERENCE A time measured against another document.
%
%   DOC = did2.build.relativeTimeReference(REFERENTID, 'Clock', C, 'Start', S, ...)
%   builds a relative_time_reference: a time on clock C, offset S seconds from
%   the referent REFERENTID (an epoch, a session, an interaction, another
%   reference). A statement points at it through its `time_reference_id` edges.
%
%   Three shapes, by what is known (time reference plan, CHANGES 1-4):
%     instant    'Start'                  (+ 'Clock')
%     interval   'Start' and 'Duration'   (+ 'Clock')
%     relation   'Relation' only          -- no metric offset, e.g. "during the
%                                           session", which is the honest state
%                                           when the exact time is unknown
%   The schema rule clock_with_start is checked: a 'Start' needs a 'Clock'.
%   There is no NaN reference -- no times means no reference document at all.
%
%   Options:
%     'Clock'           utc | dev_local_time | dev_global_time | exp_global_time
%                       (a name, completed from the field's value set, or a term)
%     'Relation'        an OWL-Time interval relation, e.g. 'intervalDuring'
%     'Start'           seconds, canonical
%     'StartSourceValue', 'StartSourceUnit', 'StartApproximate'
%     'Duration'        seconds, canonical
%     'DurationSourceValue', 'DurationSourceUnit', 'DurationApproximate'
%     'End'             seconds, canonical: the end's offset from the referent
%                       ('EndSourceValue', 'EndSourceUnit', 'EndApproximate').
%                       Its own fact with its own precision; with 'Duration'
%                       too, the two must agree (rule end_consistent)
%     'StartTolerance', 'DurationTolerance', 'EndTolerance'
%                       [minus plus] seconds: that value's bound -- the true
%                       value lies in [value - minus, value + plus]; minus is
%                       EARLIER, plus LATER (CHANGE 7). Sets that value's
%                       approximate true unless given or both are 0
%     'ClockTolerance'  seconds: the stated precision of the TIMELINE (e.g. 5
%                       for NDI's approx_ clocks), not of one value
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   Example:
%     ref = did2.build.relativeTimeReference(epochId, 'Clock', 'dev_local_time', ...
%         'Start', 12.5, 'Duration', 2, 'SessionId', sessionId);
%
%   See also did2.build.absoluteTimeReference, did2.build.statement.

arguments
    referentId (1,:) char
    options.Clock = []
    options.Relation = []
    options.Start = []
    options.StartSourceValue = []
    options.StartSourceUnit = ''
    options.StartApproximate = []
    options.StartTolerance = []
    options.Duration = []
    options.DurationSourceValue = []
    options.DurationSourceUnit = ''
    options.DurationApproximate = []
    options.DurationTolerance = []
    options.End = []
    options.EndSourceValue = []
    options.EndSourceUnit = ''
    options.EndApproximate = []
    options.EndTolerance = []
    options.ClockTolerance = []
    options.Fields (1,1) struct = struct()
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

if isempty(options.Start) && (~isempty(options.Duration) || ~isempty(options.End))
    error('did2:build:ruleViolated', '''Duration'' and ''End'' need a ''Start''; give it too.');
end
if isempty(options.Start) && isempty(options.Relation)
    error('did2:build:missingField', ...
        ['A relative time needs a ''Start'' (an offset) or a ''Relation''. ' ...
         'With no time at all there is no reference to build.']);
end
for nm = {'Start', 'Duration', 'End'}
    if isempty(options.(nm{1})) && ~isempty(options.([nm{1} 'Tolerance']))
        error('did2:build:ruleViolated', '''%sTolerance'' needs a ''%s''.', nm{1}, nm{1});
    end
end
value = struct();
if ~isempty(options.Relation); value.relation = options.Relation; end
if ~isempty(options.Clock);    value.clock = options.Clock;       end
if ~isempty(options.Start)
    value.start = timeCell(options.Start, options.StartSourceValue, ...
        options.StartSourceUnit, options.StartApproximate, options.StartTolerance, 'StartTolerance');
end
if ~isempty(options.Duration)
    value.duration = timeCell(options.Duration, options.DurationSourceValue, ...
        options.DurationSourceUnit, options.DurationApproximate, options.DurationTolerance, 'DurationTolerance');
end
if ~isempty(options.End)
    value.end = timeCell(options.End, options.EndSourceValue, ...
        options.EndSourceUnit, options.EndApproximate, options.EndTolerance, 'EndTolerance');
end
fields = struct('value', value);
if ~isempty(options.ClockTolerance)
    fields.clock_tolerance = timeCell(options.ClockTolerance, [], '', [], [], 'ClockTolerance');
end
options.Files = {};
doc = forward('relative_time_reference', fields, ...
    struct('referent_id', referentId), options);
end

function c = timeCell(seconds, sourceValue, sourceUnit, approximate, tol, optName)
c = struct('seconds', seconds);
if ~isempty(sourceUnit);  c.source_unit = sourceUnit;   end
if ~isempty(sourceValue); c.source_value = sourceValue; end
[c, approximate] = toleranceCell(c, tol, approximate, optName);
if ~isempty(approximate); c.approximate = approximate;  end
end
