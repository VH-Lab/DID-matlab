function tf = isAlreadyTarget(body, targetVersion)
%ISALREADYTARGET True when a body is already a V2 document (stamped did_v2).
%
%   TF = did2.convert.isAlreadyTarget(BODY, TARGETVERSION). The test
%   did2.convert.v1_to_v2 uses for its idempotency short-circuit (a body
%   that needs no renames and no migrators), public so a READ path can ask
%   the same question without running the whole conversion (NDI's
%   applyReadNormalization).
%
%   A STAMP CHECK, NOT A RANK. Decided by Jess Haley, 2026-10-26 [early
%   migration pieces fixed] (4) (did-schema V_eta_go_forward_class_audit.md):
%   "already converted" is a stamp check (`did_v1` / `did_v2`), not a rank
%   against `V_eta`. Both must hold:
%   (a) BODY's document_class.schema_version is a V2 stamp
%       (did2.schema.isV2Stamp: 'did_v2', [document stamps]) AND the stamp
%       TARGETVERSION writes (did2.convert.targetStamp: 'V_eta', the schema
%       SET's name, writes 'did_v2') is one too. 'V_eta' itself is not a
%       document stamp ([V_eta stamp not accepted], Jess Haley, 2026-10-25:
%       "Stop accepting veta"; refuseUnknownSchemaVersion quarantines such a
%       body before this is asked), nor is a brainstorm name (V_alpha ..
%       V_zeta) or a v1 stamp (did_v1, or none): those are converted.
%   (b) the body carries no v1-only structural markers: underscore-prefixed
%       top-level keys (e.g. legacy _classname, _class_version) that predate
%       the document_class header and could not survive a real V2 build.
%
% (a) alone would misclassify a body that was tagged V2 out-of-band but still
% carries legacy field shapes; (b) alone would skip the bulk of v1 corpora,
% which do not use the underscore markers but still need every other v1 -> V2
% rewrite.
arguments
    body % anything; only a scalar struct can be a target document
    targetVersion {mustBeText}
end

tf = false;
if ~isstruct(body) || ~isscalar(body)
    return;
end
if ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isscalar(body.document_class) ...
        || ~isfield(body.document_class, 'schema_version')
    return;
end
sv = body.document_class.schema_version;
if isstring(sv) && isscalar(sv)
    sv = char(sv);
end
if ~ischar(sv)
    return;
end
if ~did2.schema.isV2Stamp(sv) ...
        || ~did2.schema.isV2Stamp(did2.convert.targetStamp(targetVersion))
    return;
end
topKeys = fieldnames(body);
for k = 1:numel(topKeys)
    name = topKeys{k};
    if ~isempty(name) && name(1) == '_'
        return;
    end
end
tf = true;
end
