function sv = stampOf(body)
%STAMPOF A document's generation stamp, document_class.schema_version, as char.
%
%   SV = did2.schema.stampOf(BODY) returns BODY's
%   `document_class.schema_version` as a char row. BODY may be a struct, a
%   did2.document or a did.document. SV is '' when BODY carries no stamp
%   (a v1 document written before the stamps were named), when the stamp is
%   not text, or when BODY is not a document at all.
%
%   What the stamp MEANS is asked of did2.schema.isV1Stamp and
%   did2.schema.isV2Stamp (Decided by Jess Haley, 2026-10-25 [document
%   stamps], did-schema V_eta_go_forward_class_audit.md: v1 = 'did_v1',
%   V2 = 'did_v2', which is 'V_eta' today).
%
%   See also did2.schema.isV1Stamp, did2.schema.isV2Stamp,
%            did2.convert.schemaVersionRank.

sv = '';
if isa(body, 'did2.document')
    body = body.toStruct();
elseif isa(body, 'did.document')
    body = body.document_properties;
end
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) || ~isscalar(body.document_class) ...
        || ~isfield(body.document_class, 'schema_version')
    return;
end
v = body.document_class.schema_version;
if isstring(v) && isscalar(v)
    v = char(v);
end
if ischar(v) && (isrow(v) || isempty(v))
    sv = reshape(v, 1, []);
end
end
