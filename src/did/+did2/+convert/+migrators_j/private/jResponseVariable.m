function [variable, unit, outcome] = jResponseVariable(units)
%JRESPONSEVARIABLE What a v1 tuning response measured, read from its
%   `response_units`, as the statement's `variable` and the value's plain
%   `response_unit`.
%
%   [VARIABLE, UNIT, OUTCOME] = jResponseVariable(UNITS)
%
%   did-schema V_eta_data_body_model_plan.md, Jess Haley 2026-10-22:
%     [response variable]  what a tuning response measures goes in the
%       statement's existing `variable`; `response_unit` is the plain unit, so
%       a spike rate is om:hertz, "empty where the source does not say".
%     [dF/F as variable]   dF/F is the variable, not a unit: `variable` dF/F,
%       `response_unit` om:one.
%     [response variable nodes]  firing rate is wikidata:Q71762818 "neural
%       firing rate"; dF/F is EMPTY:0000397 "dF/F".
%
%   UNITS is the v1 `response_units` value as the document holds it (char,
%   string, or the writers' real value, the empty matrix: NDI-matlab
%   +ndi/+app/+stimulus/tuning_response.m declares the field in its
%   emptystruct and never assigns it).
%
%   The spellings matched (trimmed, case-insensitive, exact):
%     spikes per second   'hz', 'spikes/s', 'sp/s', '1/s', 'spikes/sec',
%                         'spikes per second'
%                         -> VARIABLE wikidata:Q71762818, UNIT om:hertz
%     dF/F                'df/f', 'Δf/f' (either delta), 'deltaf/f', 'dff'
%                         -> VARIABLE EMPTY:0000397,      UNIT om:one
%   Node and name come from the term registry (did2.convert.registeredTerm),
%   so the registered label is written, never this file's spelling.
%
%   Anything else is NOT GUESSED: VARIABLE is [] and UNIT is [] (the caller
%   keeps the source spelling as it did before). OUTCOME says which case held,
%   for the migration report's denominator:
%     'neural firing rate'   a spikes-per-second spelling
%     'dF/F'                 a dF/F spelling
%     'not stated'           empty, blank or not text
%     'unrecognised: <s>'    any other spelling, quoted as the source has it

variable = [];
unit = [];
if isstring(units) && isscalar(units)
    units = char(units);
end
if ~ischar(units) || isempty(strtrim(units))
    outcome = 'not stated';
    return;
end
s = lower(strtrim(units));
% the Greek capital or small delta (lower() turns one into the other) is
% spelled out, so 'ΔF/F' and 'deltaF/F' are one spelling: U+0394 / U+03B4 as
% one character (MATLAB) and as their two UTF-8 bytes (text read byte-wise)
for d = deltaSpellings()
    s = strrep(s, d{1}, 'delta');
end
rate = {'hz', 'spikes/s', 'sp/s', '1/s', 'spikes/sec', 'spikes per second'};
dff = {'df/f', 'deltaf/f', 'dff'};
if any(strcmp(s, rate))
    variable = did2.convert.registeredTerm('wikidata:Q71762818', 'neural firing rate');
    unit = did2.convert.registeredTerm('om:hertz', 'hertz');
    outcome = 'neural firing rate';
elseif any(strcmp(s, dff))
    variable = did2.convert.registeredTerm('EMPTY:0000397', 'dF/F');
    unit = did2.convert.registeredTerm('om:one', 'one');
    outcome = 'dF/F';
else
    outcome = ['unrecognised: ' strtrim(units)];
end
end

function c = deltaSpellings()
% the two-byte UTF-8 forms FIRST, so a one-byte char type that cannot hold
% U+0394 (and turns char(916) into some single byte) has already replaced the
% whole sequence before that byte is looked for
c = {char([206 148]), char([206 180])};
try
    c = [c, {char(916), char(948)}];
catch
    % no U+0394 in this char type: the UTF-8 forms above remain
end
end
