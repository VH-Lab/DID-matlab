function v2Body = jrclust_clusters(preBody)
%JRCLUST_CLUSTERS Migrate a did_v1 jrclust_clusters body to V_delta.
%
%   Drops the legacy `ndi_document` top-level block. v1 sometimes ships
%   a sibling `ndi_document: {name: 'jrclust.prm'}` that pre-dates the
%   schema's `file` mechanism; V_delta replaces it with the
%   `jrclust_output_file` declared in the class schema, so the block has
%   no V_delta-side meaning and would otherwise trip strict-block
%   validation. Also lowercases the v1 `res_mat_MD5_checksum` to
%   `res_mat_md5_checksum` (universalRenames misses it because MD5 is an
%   embedded acronym in the middle of the identifier).

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if isfield(v2Body, 'ndi_document')
    v2Body = rmfield(v2Body, 'ndi_document');
end
if isfield(v2Body, 'jrclust_clusters') && isstruct(v2Body.jrclust_clusters)
    block = v2Body.jrclust_clusters;
    if isfield(block, 'res_mat_MD5_checksum') && ~isfield(block, 'res_mat_md5_checksum')
        block.res_mat_md5_checksum = block.res_mat_MD5_checksum;
        block = rmfield(block, 'res_mat_MD5_checksum');
    end
    v2Body.jrclust_clusters = block;
end
end
