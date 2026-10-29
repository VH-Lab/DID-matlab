function v2Body = ngrid(preBody)
%NGRID Base migrator: a standalone did_v1 `ngrid` document is CARRIED whole as
%   v1, needs_mapping (the document is returned UNCHANGED).
%
%   [ngrid with no statement carried] (Decided by Jess Haley, 2026-10-29,
%   did-schema V_eta_go_forward_class_audit.md): "an ontologyImage `ngrid` whose
%   only edge is its table row, and a standalone `ngrid`, are carried whole as
%   v1 `needs_mapping`; every other `ngrid` migrates into `sampled_body` as
%   [ngrid migrates to sampled bodies]". A `sampled_body` belongs to a
%   statement, and a standalone `ngrid` names none (NDI's template gives it no
%   `depends_on`; no NDI writer at the locked main makes one: mat2ngrid is
%   called only by imageDocMaker, for an ontologyImage's raster block). The
%   ontologyImage case is in did2.convert.migrators_j.ontology_image.
%
%   WHO REACHES THIS. Under every target v1_to_v2 accepts (did_v2 / V_eta,
%   did2.convert.isV2Set), a document that lists `ngrid` among its
%   SUPERCLASSES gets the override did2.convert.migrators_j.super.ngrid
%   (a guard that carries the block verbatim), never this file, and every
%   consumer's own migrator (hartley_calc, ontology_image) folds the block into
%   a sampled_body. So this base migrator runs only as the CONCRETE migrator of
%   a document whose class is `ngrid` itself.
%
%   WHAT CHANGED. Until 2026-10-29 this reshaped the block (data_dim ->
%   dim_sizes, derived ndims) and DELETED `data_size` and `coordinates`
%   "per the conversion default", which [generic stage is lossless] (Jess
%   Haley, 2026-10-25) forbids; did-schema #227 recorded that loss for a
%   standalone ngrid. A carry is the untouched v1 source (v1_to_v2 stores the
%   universalRenames output it handed in, recorded as a pass-1 passthrough), so
%   every field is kept.
%
%   THE REGISTER ROW. The decision asks for a did-schema register row: it is
%   carry-123 (did-schema 64ad58b8), and the note starts with its [carry-123]
%   tag.

arguments
    preBody (1,1) struct
end

b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: carry-123
did2.convert.reportNote('carried_as_v1', 'ngrid', id, ...
    ['[carry-123] needs_mapping: a standalone ngrid names no statement for its sampled_body ' ...
    '([ngrid with no statement carried])']);
v2Body = preBody;
end
