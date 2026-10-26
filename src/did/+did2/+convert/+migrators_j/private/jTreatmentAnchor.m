function anchor = jTreatmentAnchor(preBody, block)
%JTREATMENTANCHOR The time reference a migrated treatment manipulation is
%   anchored at.
%
%   ANCHOR = jTreatmentAnchor(PREBODY, BLOCK). When the v1 property block
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

anchor = [];
if isstruct(block) && isscalar(block)
    onset = jGetCharAny(block, {'administration_onset_time', 'administrationOnsetTime', ...
        'virus_administration_date', 'virus_AdministrationDate', 'virusAdministrationDate'});
    anchor = jAbsoluteReference(preBody, onset);
    if isempty(anchor)
        anchor = transferAnchor(preBody, block);
    end
end
if isempty(anchor)
    anchor = jSessionAnchor(preBody, 'during');
end
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
