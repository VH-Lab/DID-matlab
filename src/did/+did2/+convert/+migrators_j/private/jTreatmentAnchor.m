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
%   Decided by Jess Haley, 2026-10-21 ("a"): every treatment route --
%   immersion, exposure, dose, the Babu heat pulse -- is anchored at the
%   recorded onset, and at the session only when there is none.

anchor = [];
if isstruct(block) && isscalar(block)
    onset = jGetCharAny(block, {'administration_onset_time', 'administrationOnsetTime'});
    anchor = jAbsoluteReference(preBody, onset);
end
if isempty(anchor)
    anchor = jSessionAnchor(preBody, 'during');
end
end
