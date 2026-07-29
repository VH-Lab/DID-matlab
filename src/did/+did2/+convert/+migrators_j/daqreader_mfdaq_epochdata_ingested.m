function v2Body = daqreader_mfdaq_epochdata_ingested(preBody)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Chunk-b/c de-encode: the mfdaq ingested cache
%   dissolves into the generic daqreader_epochdata_ingested.
%
%   The reader subtype ('mfdaq') was encoded in the CLASS NAME, but the ingested
%   epoch cache is generic; the only mfdaq-specific content is the `parameters`
%   block (per-segment sample-count cutoffs), which de-encodes onto the parent as
%   an OPTIONAL field. The `epochid` block is CARRIED THROUGH -- it is a did_v1
%   SUPERCLASS holding the epoch-id string, not a stale duplicate of a dependency
%   (there is no epochid dependency; see the note at the bottom of this file).
%   The daqreader_epochdata_ingested superclass chain is rebuilt by
%   ensureClassBlocks after this.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
v2Body.document_class.class_name = 'daqreader_epochdata_ingested';
v2Body.document_class.class_version = '2.0.0';

% de-encode `parameters` from the mfdaq block onto the generic cache block.
if ~isfield(v2Body, 'daqreader_epochdata_ingested') || ...
        ~isstruct(v2Body.daqreader_epochdata_ingested)
    v2Body.daqreader_epochdata_ingested = struct();
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested') && ...
        isstruct(v2Body.daqreader_mfdaq_epochdata_ingested)
    sub = v2Body.daqreader_mfdaq_epochdata_ingested;
    if isfield(sub, 'parameters')
        v2Body.daqreader_epochdata_ingested.parameters = sub.parameters;
    end
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested')
    v2Body = rmfield(v2Body, 'daqreader_mfdaq_epochdata_ingested');
end

% The epochid block is KEPT. It used to be deleted here, on the premise that
% "the epoch link is the epochid dep" -- but did_v1 has NO epochid dependency.
% All three NDI ingest templates declare exactly one, `daqreader_id`, and
% `epochid` is a SUPERCLASS whose block holds the epoch-id STRING (e.g.
% 't00001'), set explicitly by both concrete writers (+ndi/+daq/+reader/image.m
% and mfdaq.m). Deleting it destroyed the only record of which epoch the
% ingested bytes belong to, and the document still validated -- the FRAGMENT
% mode no counter sees. See V_eta_6_7_walkthrough_STATE.md for the correction.
end
