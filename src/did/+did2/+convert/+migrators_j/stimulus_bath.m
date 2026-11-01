function v2Body = stimulus_bath(preBody)
%STIMULUS_BATH Deferred: stimulus_bath migrates to a formulation-valued
%   manipulation in the NDI layer / the coarse resolveDeferredBaths pass.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. Same
%   disposition as the Brainstorm-E/I paths, retargeted for strict J (D8, which
%   retired the `bath`/`pharmacological_manipulation` family): the legacy
%   stimulus_bath is a `manipulation` whose value is the bath's `formulation`,
%   through `value_id` -- not a dose, since a dose always has an amount and a
%   bath gives none (Jess Haley, 2026-10-21; did-schema
%   V_eta_go_forward_class_audit.md). Assembling it needs two things the per-document
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI stimulus_bath.json + base.json + epochid.json at
%   the locked NDI-matlab `main`, 3cb19a8, as +setup/+NDIMaker/
%   stimulusDocMaker.m createBathDocs writes it). Before deferring, it accounts
%   for every v1 field; the two resolvers read them from the quarantined source
%   (the raw v1 document on either path):
%
%     base.id, session_id, datestamp   the bath manipulation's
%     base.name                        not written (the writer leaves '')
%     depends_on stimulus_element_id   followed to the element's subject (the
%                                      manipulation's entity_id); NDI also keeps
%                                      it as the instrument_id
%     epochid.epochid                  NDI's anchor on the stimulator's epoch;
%                                      the coarse DID pass anchors to the
%                                      session and keeps it nowhere
%     stimulus_bath.location           ontologyNode + name: a site observation,
%                                      or none for the generic bath
%                                      (NCIm:C0179246)
%     stimulus_bath.mixture_table      the chemicals and the formulation (pH and
%                                      osmolarity rows on the formulation)
%
%   did2.convert.roundtrip.stimulus_bath rebuilds the v1 document from what
%   resolveDeferredBaths assembles, and testRawV1RoundTripBath compares the two
%   (what the coarse pass does not keep is listed there as known findings).
%
%   A document the resolvers cannot read whole is CARRIED, not deferred: what
%   the renamed path would have discarded (carry-100, [rename clashes are malformed]), and a field,
%   location field or edge no part of the bath reads, or a mixture_table that
%   is not text (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]). Such a
%   document is stored as v1, so neither resolver sees it.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
[~, collision, unplaced] = jRawAccount(preBody, ...
    struct('stimulus_bath', {{'location', 'mixture_table'}}, 'epochid', {{'epochid'}}), ...
    {'^stimulus_element_id$'});
[offTemplate, valueReasons] = unreadBathFields(preBody);
unplaced = [unplaced, offTemplate];
if jRawCarry('stimulus_bath', preBody, collision, unplaced, 'carry-100', valueReasons)
    v2Body = {preBody};
    return;
end

v2Body = struct(); %#ok<NASGU>  % required output; a whole document always defers
error('did2:convert:needsSessionContext', ...
    ['stimulus_bath -> manipulation (valued by its formulation) is assembled downstream ', ...
     '(resolveDeferredBaths / ndi.migrate.local): the manipulation''s ', ...
     'subject (from the stimulator element) and its time anchor (the ', ...
     'stimulator''s epoch) require the session/element graph. Deferred.']);
end

function [unplaced, valueReasons] = unreadBathFields(body)
%UNREADBATHFIELDS What jRawAccount does not look inside: the `location`
%   struct's fields other than the two the resolvers read (ontologyNode, name),
%   and a mixture_table that is not text (both resolvers parse text only).
unplaced = {};       % location fields outside the template (carry-100)
valueReasons = {};   % template fields whose value the resolvers cannot read
if ~isfield(body, 'stimulus_bath') || ~isstruct(body.stimulus_bath) ...
        || ~isscalar(body.stimulus_bath)
    return;
end
sb = body.stimulus_bath;
if isfield(sb, 'location') && ~isempty(sb.location)
    loc = sb.location;
    if ~isstruct(loc) || ~isscalar(loc)
        % NDI's writer (+setup/+NDIMaker/stimulusDocMaker.m createBathDoc)
        % writes location as one {ontologyNode, name} and mixture_table as
        % text (writetablechar): anything else is a value no NDI writer
        % produces, [values no writer produces are malformed] (Jess Haley,
        % 2026-10-27, did-schema V_eta_go_forward_class_audit.md), carry-120
        valueReasons{end+1} = '[carry-120] stimulus_bath.location (not one {ontologyNode, name})';
    else
        fns = fieldnames(loc);
        for k = 1:numel(fns)
            if ~any(strcmp(fns{k}, {'ontologyNode', 'name'})) && ~isEmptyValue(loc.(fns{k}))
                unplaced{end+1} = ['stimulus_bath.location.' fns{k}]; %#ok<AGROW>
            end
        end
    end
end
if isfield(sb, 'mixture_table') && ~isempty(sb.mixture_table)
    mt = sb.mixture_table;
    if ~(ischar(mt) || (isstring(mt) && isscalar(mt)))
        valueReasons{end+1} = '[carry-120] stimulus_bath.mixture_table (not text)';  % see location above
    end
end
end

function tf = isEmptyValue(v)
if isempty(v)
    tf = true;
elseif isstruct(v) && isscalar(v)
    tf = all(cellfun(@(f) isEmptyValue(v.(f)), fieldnames(v)));
else
    tf = false;
end
end
