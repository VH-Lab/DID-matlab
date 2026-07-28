function v2Body = daqreader_mfdaq_epochdata_ingested(preBody)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Chunk-b/c de-encode: the mfdaq ingested cache
%   dissolves into the generic daqreader_epoch_cache (R5 rename: data/ingested
%   dropped, `cache` names what it is per T6).
%
%   The reader subtype ('mfdaq') was encoded in the CLASS NAME, but the ingested
%   epoch cache is generic; the only mfdaq-specific content is the `parameters`
%   block (per-segment sample-count cutoffs), which de-encodes onto the parent as
%   an OPTIONAL field. The redundant `epochid` superclass mixin is dropped too
%   (dep-only, V_eta chunk b): the epoch link is the inherited `epochid` dep, so
%   any inline epochid block is stale and must be removed (an undeclared top-level
%   block quarantines). The daqreader_epoch_cache superclass chain is
%   rebuilt by ensureClassBlocks after this.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
v2Body.document_class.class_name = 'daqreader_epoch_cache';
v2Body.document_class.class_version = '2.0.0';

% de-encode `parameters` from the mfdaq block onto the generic cache block.
if ~isfield(v2Body, 'daqreader_epoch_cache') || ...
        ~isstruct(v2Body.daqreader_epoch_cache)
    v2Body.daqreader_epoch_cache = struct();
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested') && ...
        isstruct(v2Body.daqreader_mfdaq_epochdata_ingested)
    sub = v2Body.daqreader_mfdaq_epochdata_ingested;
    if isfield(sub, 'parameters')
        v2Body.daqreader_epoch_cache.parameters = sub.parameters;
    end
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested')
    v2Body = rmfield(v2Body, 'daqreader_mfdaq_epochdata_ingested');
end

% dep-only: drop the stale inline epochid block (epoch link is the epochid dep).
if isfield(v2Body, 'epochid')
    v2Body = rmfield(v2Body, 'epochid');
end
end
