function [anchor, why] = jTreatmentAnchor(preBody, block)
%JTREATMENTANCHOR The time reference a migrated treatment manipulation is
%   anchored at.
%
%   [ANCHOR, WHY] = jTreatmentAnchor(PREBODY, BLOCK). WHY is '' or, for a v1
%   treatment_drug whose times cannot be placed, the reason the caller
%   carries the document whole as v1 (see CARRIED WHOLE AS v1 below).
%
%   When the v1 property block
%   BLOCK records an `administration_onset_time` (treatment_drug's template
%   field; Babu writes it as a time of day, 'hh:mm:ss', NDIMaker documents it
%   as ISO 8601), the manipulation is anchored at THAT instant
%   (jAbsoluteReference: `start.source_value` is the string as written,
%   `start.utc` only for a UTC ISO-8601 string). Only when none is recorded
%   does it fall back to "during the session" (jSessionAnchor).
%
%   A v1 treatment_transfer's onset is its `timestamp` on its `clocktype`
%   (Jess Haley, 2026-10-21 [transfer onset]): an instant on the session's
%   clock, offset from the session (transferAnchor below).
%
%   A v1 virus_injection's onset is its `virus_AdministrationDate` (snake-cased
%   by universalRenames to `virus_administration_date`; both spellings read):
%   Jess Haley, 2026-10-21 ("a") [virus injection onset].
%
%   Decided by Jess Haley, 2026-10-21 ("a"): every treatment route --
%   immersion, exposure, dose, the Babu heat pulse -- is anchored at the
%   recorded onset, and at the session only when there is none.
%
%   A v1 treatment_drug's END and EXTENT: [drug end and duration on the
%   anchor] (Jess Haley, 2026-10-27, did-schema V_eta_go_forward_class_audit.md):
%   "`administration_offset_time` -> `absolute_time_reference.value.end`;
%   `administration_duration` -> `absolute_time_reference.value.duration`. No
%   new class or field" -- written on the anchor whose `start` is
%   `administration_onset_time` (jAbsoluteReference). The duration is in DAYS:
%   NDI-matlab main treatment_drug_schema.json documents it as "Duration of
%   drug administration duration in days", and the writers write days
%   (+setup/+conv/+birren/TreatmentCreator.m "newRow{12} = 2; % duration in
%   days"; +setup/+conv/+babu/TreatmentCreator.m days(...)). So
%   `duration.source_value` is the number as written, `duration.source_unit` the unit "day" (no term
%   in the registry holds it, so it is the name with an empty node, as
%   jSourceUnit writes a spelling no registered term matches:
%   V_eta_source_unit_plan.md item 4), and
%   `duration.seconds` is days * 86400.
%
%   CARRIED WHOLE AS v1, `needs_mapping` (WHY is set; the caller carries):
%     - an offset or duration with NO onset: [drug end without start needs
%       mapping] (Jess Haley, 2026-10-29, did-schema
%       V_eta_go_forward_class_audit.md): "a v1 `treatment_drug` with an
%       offset or a duration but no onset is carried whole as v1
%       `needs_mapping`" (an `end` needs a `start`, rule end_consistent);
%     - onset, offset and duration that disagree: [drug times that disagree
%       need mapping] (Jess Haley, 2026-10-29): "a v1 `treatment_drug` whose
%       onset, offset and duration disagree is carried whole as v1
%       `needs_mapping`, nothing chosen silently". They disagree exactly when
%       the rule end_consistent would reject them (DID-matlab
%       src/did/+did2/+build/private/checkRules.m, function endConsistent):
%       onset and offset both UTC and the offset before the onset, or, with a
%       duration too, |(offset - onset) - duration| > 1e-3 s (1 ms). Times
%       that cannot be read on the UTC timeline (a local time, no Z) are not
%       compared, as the rule does not compare them.
%   Both are register row carry-127; the note starts with its [carry-127] tag.

anchor = [];
why = '';
if isstruct(block) && isscalar(block)
    onset = jGetCharAny(block, {'administration_onset_time', 'administrationOnsetTime', ...
        'virus_administration_date', 'virus_AdministrationDate', 'virusAdministrationDate'});
    [stopText, duration, why] = drugExtent(onset, block);
    if ~isempty(why)
        return;     % the caller carries the document whole as v1
    end
    anchor = jAbsoluteReference(preBody, onset, stopText, duration);
    if isempty(anchor)
        anchor = transferAnchor(preBody, block);
    end
end
if isempty(anchor)
    anchor = jSessionAnchor(preBody, 'during');
end
end

function [stopText, duration, why] = drugExtent(onset, block)
% [drug end and duration on the anchor] (Jess Haley, 2026-10-27): the v1
% treatment_drug's offset text and duration (days) for the anchor whose start
% is ONSET; '' / [] when the block states none. WHY is set when there is an
% offset or duration but no onset, or when the three disagree on the UTC
% timeline (see the header: both are carried, Jess Haley, 2026-10-29).
duration = [];
why = '';
stopText = strtrim(jGetCharAny(block, {'administration_offset_time', 'administrationOffsetTime'}));
d = [];
for name = {'administration_duration', 'administrationDuration'}
    if isfield(block, name{1})
        d = block.(name{1});
        break;
    end
end
if isempty(strtrim(onset))
    % [drug end without start needs mapping] (Jess Haley, 2026-10-29): any
    % stated offset or duration (a NaN or empty duration states none, as
    % NDI's template default [] and a JSON null)
    if ~isempty(stopText) || statesValue(d)
        why = ['[carry-127] needs_mapping: administration_offset_time or administration_duration ' ...
            'with no administration_onset_time (an end needs a start; [drug end ' ...
            'without start needs mapping])'];
    end
    stopText = '';
    return;
end
if isnumeric(d) && isscalar(d) && isfinite(double(d))
    nDays = double(d);
    duration = struct('seconds', nDays * 86400, 'source_value', nDays, ...
        'source_unit', jSourceUnit('day'));
end
t0 = utcSeconds(strtrim(onset));
t1 = utcSeconds(stopText);
if ~isnan(t0) && ~isnan(t1)
    % the tolerance of the rule end_consistent (checkRules.m endConsistent:
    % "end = start + duration, to 1 ms")
    agree = t1 >= t0;
    if agree && ~isempty(duration)
        agree = abs((t1 - t0) - duration.seconds) <= 1e-3;
    end
    if ~agree
        % [drug times that disagree need mapping] (Jess Haley, 2026-10-29)
        why = sprintf(['[carry-127] needs_mapping: administration_onset_time "%s", ' ...
            'administration_offset_time "%s" and administration_duration %s ' ...
            'disagree (rule end_consistent; [drug times that disagree need ' ...
            'mapping])'], strtrim(onset), stopText, ...
            durationText(duration));
        stopText = '';
        duration = [];
    end
end
end

function tf = statesValue(d)
% a duration is stated unless it is empty, blank text or all NaN
if ischar(d) || isstring(d)
    tf = ~isempty(strtrim(char(d)));
elseif isnumeric(d) || islogical(d)
    tf = ~isempty(d) && ~all(isnan(double(d(:))));
else
    tf = ~isempty(d);
end
end

function s = durationText(duration)
if isempty(duration)
    s = '(none)';
else
    s = sprintf('%g days', duration.source_value);
end
end

function t = utcSeconds(s)
% seconds on the UTC timeline of an ISO-8601 UTC string (a trailing Z, as
% jAbsoluteReference reads one); NaN for anything else
t = NaN;
tok = regexp(s, ['^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):' ...
    '(\d{2}(?:\.\d+)?)Z$'], 'tokens', 'once');
if isempty(tok)
    return;
end
n = str2double(tok);
t = posixtime(datetime(n(1), n(2), n(3), n(4), n(5), n(6), 'TimeZone', 'UTC'));
end

function anchor = transferAnchor(preBody, block)
% v1 treatment_transfer: `timestamp` on clock `clocktype` (Babu writes
% seconds(hours(-TransferTime)) on dev_local_time: a number of SECONDS, negative
% for "hours before") is its onset -- an instant on the SESSION's clock, offset
% from the session (Jess Haley, 2026-10-21 [transfer onset]). [] when there is
% no finite number to anchor at.
anchor = [];
if ~isfield(block, 'timestamp'); return; end
t = block.timestamp;
if ischar(t) || isstring(t); t = str2double(t); end
if ~isnumeric(t) || isempty(t) || ~isfinite(double(t(1))); return; end
t = double(t(1));
clk = jGetCharAny(block, {'clocktype', 'clockType'});
if isempty(clk)
    % [one-reading quick answers] (Q2): no clock type is not `dev_local_time`;
    % treatment_transfer carries such a document before reaching here
    return;
end
% (Q2) "a global-clock time is written in its true unit": NDI's
% treatment_transfer schema states the timestamp is "a datenum (if global
% clock) or in seconds (if local clock)", so a global clock's number is DAYS
% (its source unit), a local clock's seconds.
unit = struct('node', 'om:second-Time', 'name', 'second');
startSec = t;
if any(strcmp(regexprep(clk, '^approx_', ''), {'utc', 'dev_global_time', 'exp_global_time'}))
    unit = struct('node', 'om:day', 'name', 'day');
    startSec = t * 86400;
end
o = jOpts(preBody);
anchor = did2.build.relativeTimeReference(jSid(preBody), 'Clock', clk, ...
    'Start', startSec, 'StartSourceValue', t, 'StartSourceUnit', unit, ...
    'StartApproximate', false, o{:});
end
