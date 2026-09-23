function bodies = sorting_parameters(preBody)
%SORTING_PARAMETERS Brainstorm-J migrator: did_v1 sorting_parameters -> ONE
%   `method_parameters` document (+ the `software` entity its v1 `app` block
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

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'sorting_parameters') && isstruct(preBody.sorting_parameters)
    blk = preBody.sorting_parameters;
end

% The tail is the whole block, by subtraction from nothing: a field NDI adds
% later survives instead of being dropped by an allow-list.
entries = struct('variable', {}, 'value', {});
bodies = jMethodParameters(preBody, entries, blk);
end
