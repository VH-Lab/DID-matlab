function v2Body = jrclust_clusters(preBody)
%JRCLUST_CLUSTERS Migrate a did_v1 jrclust_clusters body to V_delta.
%
%   Lowercases the v1 `res_mat_MD5_checksum` field name to
%   `res_mat_md5_checksum`. universalRenames's snake_case pass treats
%   the trailing-camel `Checksum` as a word boundary but leaves the
%   embedded `MD5` ALLCAPS run alone, so this class-specific rename
%   handles it explicitly. The companion legacy `ndi_document` block
%   that v1 sometimes ships on these documents is reconciled in
%   universalRenames (the universal `ndi_document -> base` rule).

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if isfield(v2Body, 'jrclust_clusters') && isstruct(v2Body.jrclust_clusters)
    block = v2Body.jrclust_clusters;
    if isfield(block, 'res_mat_MD5_checksum') && ~isfield(block, 'res_mat_md5_checksum')
        block.res_mat_md5_checksum = block.res_mat_MD5_checksum;
        block = rmfield(block, 'res_mat_MD5_checksum');
    end
    v2Body.jrclust_clusters = block;
end
end
