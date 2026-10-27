function bodies = sorting_parameters(preBody)
%SORTING_PARAMETERS Brainstorm-J migrator: did_v1 sorting_parameters -> ONE
%   `method` document (`method_parameters` before did-schema #88) (+ the
%   `software` entity its v1 `app` block
%   names).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   1 -> 1 (2 with the software entity), base.id AND base.name PRESERVED.
%   Both are load-bearing exactly as for spike_extraction_parameters:
%
%     base.id    <- spike_clusters.sorting_parameters_id
%                   (git grep -n sorting_parameters_id origin/main -- '*.json'
%                    -> .../spikesorter/spike_clusters.json:15)
%     base.name  <- spikesorter.m:373
%                    ndi.query('base.name','exact_string',sorting_parameters_name,'')
%
%   NO BOUND PARAMETERS, AND THAT IS THE DECIDED OUTCOME, not an oversight. The
%   template's six fields are all algorithm-specific knobs, and the plan puts
%   every one of them in the bag by name:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/\
%         spikesorter/sorting_parameters.json
%        graphical_mode 1  num_pca_features 10  interpolation 3
%        min_clusters 3  max_clusters 10  num_start 5
%
%     V_eta_method_parameters_plan.md, "What stays in the bag, deliberately":
%        graphical_mode                    a GUI flag; arguably not archival
%        num_pca_features, interpolation, num_start   algorithm-specific
%        min_clusters, max_clusters        JUDGMENT CALL -- bounding a cluster
%                                          search is arguably canonical, but the
%                                          shape varies by algorithm
%
%   So the emitted document carries an EMPTY `method_parameters` list and a full
%   `other` bag. That is not a hollow document: every source field survives
%   verbatim, and `method_parameters` is optional on the class. Promoting
%   min_clusters/max_clusters to bound variables is a team call, deliberately
%   not taken here.
%
%   The template declares NO dependencies ("depends_on": [ ] in the
%   schema_documents pair; no depends_on key at all in the template) and the
%   writer adds none (spikesorter.m:319-322 is settings struct + newdocument() +
%   base.name), so subject_id / epoch_id / derived_from_id are all legitimately
%   absent -- omitted, never written blank.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it:
%     ndi.app.spikesorter struct2doc: the settings struct over
%     sorting_parameters.json + app.json + base.json at the locked NDI-matlab
%     `main`, 3cb19a8, base.name the sorting name
%   Its block and edges are snake_case already, and the `app` block is read
%   in either spelling (jSoftwareFromApp), so the raw read changes nothing the
%   fold writes; a nameless app block's leftover keeps the bag spelling the
%   renamed path gave it (jMethodParameters). Every block field goes to a
%   bound parameter or the bag, as before. What the renamed path would have
%   discarded is carried, carry-049, as before; a block, base field or edge
%   no part of this fold reads, or an `app` field outside NDI's app.json (all
%   dropped without a word on the renamed path), now carries the document
%   whole as v1 (private/jRawAccount, jRawCarry; [fields outside the template
%   are malformed], carry-100).
%   Every writer document carries, carry-002, as before: ndi.app/newdocument
%   always writes the run's os and interpreter, which no method keeps. A carry
%   is the untouched v1 source. did2.convert.roundtrip.sorting_parameters
%   rebuilds the v1 document; testRawV1RoundTripSpikeParameters compares the
%   two.
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'sorting_parameters') && isstruct(preBody.sorting_parameters)
    blk = preBody.sorting_parameters;
end

% The tail is the whole block, by subtraction from nothing: a field NDI adds
% later survives instead of being dropped by an allow-list.
entries = {};

% THE RAW READ (see READS RAW v1 above). The bag reads every field of the
% block, so the block's own fields are all read; the other blocks, base and
% edges are checked.
src = preBody;
blockFields = fieldnames(blk);
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'sorting_parameters', {blockFields(:)'}, ...
    'app', {{'name', 'version', 'url', 'os', 'os_version', 'interpreter', 'interpreter_version'}}), ...
    {'^element_id$', '^subject_id$', '^epoch_id$'});
if jRawCarry('sorting_parameters', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

bodies = jMethodParameters(preBody, entries, blk);
if isscalar(bodies) && isequaln(bodies{1}, preBody)
    bodies = {src};   % a carry is the untouched v1 source
end
end
