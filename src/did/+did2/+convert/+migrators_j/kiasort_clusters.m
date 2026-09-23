function bodies = kiasort_clusters(preBody)
%KIASORT_CLUSTERS Brainstorm-J migrator: did_v1 kiasort_clusters -> the D-C
%   analysis-tier shape (count_observation + opaque_body + session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   kiasort_clusters is a Kiasort spike-sorting RUN: an external, session-relative
%   output DIRECTORY (`kiasort_directory`) plus a curated-output MD5. Identical
%   disposition to kilosort_clusters (a sibling sorter class) -- an id-preserved
%   count_observation handle on the recording subject + the sorter output directory
%   as an opaque_body + the 'during' anchor. 1 -> 3. See
%   did2.convert.migrators_j.private.jSorterOutput.
arguments
    preBody (1,1) struct
end
bodies = jSorterOutput(preBody, 'kiasort', 'kiasort_directory');
end
