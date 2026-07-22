function bodies = kilosort_clusters(preBody)
%KILOSORT_CLUSTERS Brainstorm-J migrator: did_v1 kilosort_clusters -> the D-C
%   analysis-tier shape (count_observation + opaque_body + session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   kilosort_clusters is a Kilosort spike-sorting RUN: an external, session-relative
%   output DIRECTORY (`kilosort_directory`) plus a curated-output MD5. Same family
%   as jrclust_clusters, so it decomposes the same way -- an id-preserved
%   count_observation handle on the recording subject + the sorter output as a body
%   + the 'during' anchor -- except the output is an external directory (opaque_body)
%   rather than attached res.mat bytes (sampled_body). 1 -> 3. See
%   ndi_common analysis tier (#9 / D-C) and did2.convert.migrators_j.private.jSorterOutput.
arguments
    preBody (1,1) struct
end
bodies = jSorterOutput(preBody, 'kilosort', 'kilosort_directory');
end
