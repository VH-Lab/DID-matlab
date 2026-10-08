function v2Body = stimulus_bath(~)
%STIMULUS_BATH Deferred: stimulus_bath migrates to a dose_manipulation in the
%   NDI layer / the coarse resolveDeferredBaths pass.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. Same
%   disposition as the Brainstorm-E/I paths, retargeted for strict J (D8, which
%   retired the `bath`/`pharmacological_manipulation` family): the legacy
%   stimulus_bath is a delivered substance -> a `dose_manipulation`
%   subject_manipulation leaf. Assembling it needs two things the per-document
%   converter cannot see -- both obtained by following stimulus_element_id to the
%   stimulator ELEMENT and its session/epoch graph:
%
%     - subject_id      : the stimulator element's subject, and
%     - time_reference  : a time anchor on the stimulator's epoch.
%
%   A manipulation must be emitted complete (all required dependencies
%   together), so the bath is assembled downstream, not here:
%
%     - standalone / corpus discovery -> did2.convert.resolveDeferredBaths
%       (coarse: subject from the migrated element in the batch + a
%       session_relative anchor), and
%     - a live NDI session -> ndi.migrate.local (precise: an
%       epoch_bounded_reference on the stimulator's epoch).
%
%   Deferring EXPLICITLY here (rather than letting the base migrator emit an
%   invalid class that validation happens to quarantine) makes the deferral
%   intentional and Validate-independent, so the transform tests see it too.

v2Body = struct(); %#ok<NASGU>  % required output; this migrator always defers
error('did2:convert:needsSessionContext', ...
    ['stimulus_bath -> dose_manipulation is assembled downstream ', ...
     '(resolveDeferredBaths / ndi.migrate.local): the manipulation''s ', ...
     'subject (from the stimulator element) and its time anchor (the ', ...
     'stimulator''s epoch) require the session/element graph. Deferred.']);
end
