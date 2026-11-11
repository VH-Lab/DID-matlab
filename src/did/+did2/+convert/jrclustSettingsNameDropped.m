function body = jrclustSettingsNameDropped(body)
%JRCLUSTSETTINGSNAMEDROPPED A raw v1 `jrclust_clusters` without the
%   settings-file name of its legacy `ndi_document` block.
%
%   BODY = did2.convert.jrclustSettingsNameDropped(BODY). Decided by Jess
%   Haley, 2026-11-11 [jrclust settings-file name dropped] (did-schema
%   did_v2_go_forward_class_audit.md; replaces [one-reading quick answers]
%   Q5): the settings-file name a `jrclust_clusters` document holds is NOT
%   carried. NDI-matlab's writer (+ndi/+fun/+probe/+import/+jrclust/probe.m)
%   sets it from its `prmName` option, as `base.name`; the Soph vintage holds
%   it as `ndi_document.name` in an `ndi_document` block beside `base`
%   ('jrclust.prm'). The document migrates to its decided shape instead of
%   being carried whole as v1 for that name, and the round trip lists the name
%   as an accepted loss (did2.convert.roundtrip.wholeBatch).
%
%   This removes ONLY `ndi_document.name`, and the `ndi_document` block when
%   that leaves it with no field, so the block's other fields are still read
%   as `base` ([ndi_document read as base]) and one `base` cannot hold still
%   carries the document (carry-100). `base.name` is left as it is: no
%   migrator writes it (#73 item 54), and v1_to_v2 does not carry a
%   `jrclust_clusters` for it. A body that is not a scalar struct, or has no
%   such field, is returned unchanged.
%
%   The caller reads the result; a carry is still the untouched v1 source
%   ([migrators read raw v1]).
%
%   See also did2.convert.v1_to_v2, did2.convert.migrators_j.jrclust_clusters,
%            did2.convert.roundtrip.jrclust_clusters.

if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'ndi_document')
    return;
end
blk = body.ndi_document;
if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, 'name')
    return;
end
blk = rmfield(blk, 'name');
if isempty(fieldnames(blk))
    body = rmfield(body, 'ndi_document');
else
    body.ndi_document = blk;
end
end
