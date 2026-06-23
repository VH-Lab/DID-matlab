function v2Body = stimulus_bath(~)
%STIMULUS_BATH Deferred: stimulus_bath migrates to a `bath` in the NDI layer.
%
%   The legacy stimulus_bath is really a bath (pharmacological_manipulation):
%   its mixture/location live in the document, but the resulting bath needs two
%   things that can only be obtained by following stimulus_element_id to the
%   stimulator ELEMENT and its session/epoch graph --
%
%     - subject_id      : the stimulator element's subject, and
%     - time_reference  : an epoch_bounded_reference on the stimulator's epoch
%                         (the stimulator is the time referent; no other
%                         connection to it is kept).
%
%   A manipulation must be emitted complete (all required dependencies
%   together), so the whole bath is assembled in ndi.migrate.local, which has
%   the element and epoch in hand. The per-document converter cannot complete
%   it, so it defers here with a clear, queryable reason rather than emitting a
%   partial (or a wrong-block fallback that reads as "mixture missing").
%
%   See ndi.migrate.internal.stimulusBathToBath (NDI-matlab) for the build.

v2Body = struct(); %#ok<NASGU>  % required output; this migrator always defers
error('did2:convert:needsSessionContext', ...
    ['stimulus_bath -> bath is migrated in the NDI layer ', ...
     '(ndi.migrate.local): the bath''s subject (from the stimulator ', ...
     'element) and its epoch_bounded_reference time anchor (the ', ...
     'stimulator''s epoch) require the session/element graph. Deferred.']);
end
