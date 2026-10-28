function [v1, spec] = epochfiles_ingested(bodies, ctx)
%EPOCHFILES_INGESTED Rebuild a v1 `epochfiles_ingested` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.epochfiles_ingested(BODIES) and
%   (BODIES, CTX). V1 is the manifest in NDI's v1 shape (epochfiles_ingested.json
%   + base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+file/navigator.m writes it: epoch_id, files, epochprobemap and the
%   filenavigator_id edge). BODIES is one of:
%
%   THE PASS-1 PASSTHROUGH, one `epochfiles_ingested` document as v1_to_v2
%   padded and stamped it: the document itself, its session edge read back into
%   base.session_id and its creation_timestamp into base.datestamp.
%
%   THE BATCH PASS'S MANIFEST, one `ingestion_manifest`: did2.convert.
%   resolveEpochProbemap renames the manifest once every probe-map row has a
%   home, keeping its id, and decomposes the probe map into statements (see
%   private/manifestProbemap). CTX, the index of the final batch the
%   whole-batch round trip hands an inverse ([whole-batch round trip], Jess
%   Haley, 2026-10-27), is where those statements are read:
%
%     base.id, session_id, datestamp   the manifest's (rebuildBase)
%     base.name                        '' (V2 writes none)
%     depends_on filenavigator_id      its epoch_file_pattern_id (the v1
%                                      filenavigator keeps its id)
%     epochfiles_ingested.epoch_id     its epoch_id entity's local_identifier
%     epochfiles_ingested.files        its files, verbatim
%     epochfiles_ingested.epochprobemap  rebuilt from the batch
%                                      (private/manifestProbemap)
%
%   With no CTX the epoch string and the probe map cannot be read, and say so
%   (unplaced). Anything else is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.epochfiles_ingested,
%            did2.convert.resolveEpochProbemap.

arguments
    bodies cell
    ctx = []
end

CLASS = 'epochfiles_ingested';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'ingestion_manifest')
    m = bodies{1};
    base = rebuildBase(m);
    nav = edgeIds(m, 'epoch_file_pattern_id');
    if isempty(nav); nav = {''}; end
    blk = getIn(m, 'ingestion_manifest');
    spec.unplaced = [spec.unplaced, others(blk, {'files'}, 'ingestion_manifest')];
    files = {};
    if isstruct(blk) && isfield(blk, 'files') && ~isempty(blk.files)
        files = blk.files;
        if ischar(files) || (isstring(files) && isscalar(files))
            files = {char(files)};
        end
        files = reshape(cellstr(files), [], 1);   % jsondecode's column
    end
    [pm, why, epochString] = manifestProbemap(m, ctx);
    spec.unplaced = [spec.unplaced, why];
    v1.document_class = struct('class_name', CLASS);
    v1.depends_on = struct('name', 'filenavigator_id', 'value', nav{1});
    v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
        'datestamp', base.datestamp);
    v1.epochfiles_ingested = struct('epoch_id', epochString, 'files', {files}, ...
        'epochprobemap', pm);
    return;
end
for k = 1:numel(bodies)
    spec.unplaced{end+1} = sprintf(['emitted document %d (%s) is neither the pass-1 ' ...
        'passthrough nor its ingestion_manifest'], k, classNameOf(bodies{k}));
end
if isempty(bodies)
    spec.unplaced{end+1} = 'nothing was emitted';
end
end
