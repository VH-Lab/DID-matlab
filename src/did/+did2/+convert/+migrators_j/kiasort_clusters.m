function bodies = kiasort_clusters(preBody)
%KIASORT_CLUSTERS Brainstorm-J migrator: did_v1 kiasort_clusters -> the D-C
%   analysis-tier shape (a `calculation` with value kind `label` + opaque_body +
%   session anchor, + software and run documents).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   kiasort_clusters is a Kiasort spike-sorting RUN: an external, session-relative
%   output DIRECTORY (`kiasort_directory`) plus a curated-output MD5. Identical
%   disposition to kilosort_clusters (a sibling sorter class) -- an id-preserved
%   count_observation handle on the recording subject + the sorter output directory
%   as an opaque_body + the 'during' anchor. 1 -> 3. See
%   did2.convert.migrators_j.private.jSorterOutput.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (kiasort_clusters.json + app.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+probe/+import/+kiasort/probe.m writes it:
%   the app block naming the whole pipeline, kiasort_directory '<dir>/<element>',
%   curated_output_MD5_checksum the md5sum of spike_clusters.npy, element_id).
%   Every v1 field and where it goes; did2.convert.roundtrip.kiasort_clusters
%   rebuilds the v1 document and testRawV1RoundTripSpikeParameters compares:
%
%     base.id, session_id, datestamp    -> the calculation's
%     base.name                         -> not written (the writer leaves '')
%     depends_on element_id             -> the calculation's entity_id
%     app.name, version, url            -> the software entity
%     app.os, os_version, interpreter,  -> the run's operating_system and
%       interpreter_version                interpreter entities
%     kiasort_clusters.kiasort_directory  -> the opaque_body's filename and file location
%     kiasort_clusters.curated_output_MD5_checksum
%                                       -> the body's content_hash (MD5)
%
%   The checksum is written lower-cased and trimmed: one that is not already
%   so (the writer's md5sum / md5 output always is) would be rewritten, so it
%   carries the document. What the renamed path would have discarded is
%   carried, carry-049, as before; a block, field or edge no part of this fold
%   reads (dropped without a word on the renamed path) now carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; [fields outside the
%   template are malformed], carry-100; a rewritten checksum has no register
%   row yet). A carry is the untouched v1 source.
arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'kiasort_clusters', {{'kiasort_directory', 'curated_output_MD5_checksum'}}, ...
    'app', {{'name', 'version', 'url', 'os', 'os_version', 'interpreter', 'interpreter_version'}}), ...
    {'^element_id$', '^subject_id$'});
md5 = '';
valueReasons = {};
if isfield(src, 'kiasort_clusters') && isstruct(src.kiasort_clusters)
    md5 = jGetCharAny(src.kiasort_clusters, {'curated_output_MD5_checksum', 'curated_output_md5_checksum'});
end
if ~isempty(md5) && ~strcmp(md5, lower(strtrim(md5)))
    valueReasons{end+1} = 'kiasort_clusters.curated_output_MD5_checksum (not lower-case hex: the body would rewrite it)';
end
if jRawCarry('kiasort_clusters', src, collision, unplaced, 'carry-100', valueReasons)
    bodies = {src};
    return;
end
bodies = jSorterOutput(preBody, 'kiasort', 'kiasort_directory');
end
