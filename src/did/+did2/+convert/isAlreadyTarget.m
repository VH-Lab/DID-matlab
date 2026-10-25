function tf = isAlreadyTarget(body, targetVersion)
%ISALREADYTARGET True when a body is already at (or past) TARGETVERSION.
%
%   TF = did2.convert.isAlreadyTarget(BODY, TARGETVERSION). The test
%   did2.convert.v1_to_v2 uses for its idempotency short-circuit (a body
%   that needs no renames and no migrators), public so a READ path can ask
%   the same question without running the whole conversion (NDI's
%   applyReadNormalization). Moved out of v1_to_v2 unchanged, 2026-10-06.
% Return true when BODY is already a TARGETVERSION-shaped document so the
% per-body migration loop can skip universalRenames and the per-class
% migrators (it still gets ensureClassBlocks + validate). Both conditions
% must hold so the short-circuit only fires when we have high confidence
% the body is already at the target:
%   (a) document_class.schema_version ranks AT OR BEYOND TARGETVERSION on the
%       did_v1 -> V_eta line (did2.convert.schemaVersionRank), the version
%       having been set by the last run of universalRenames, the writer, or --
%       for the former 'V_epsilon' target (deleted 2026-10-21) -- a context
%       assembler such as
%       ndi.migrate.internal.stimulusBathToBath that emits ready-made target
%       bodies. This was an EQUALITY test until 2026-08-14, which made a body
%       newer than the target indistinguishable from one older than it; an
%       unrecognised version still falls through to conversion, deliberately,
%       AND
%   (b) the body carries no v1-only structural markers — underscore-
%       prefixed top-level keys (e.g., legacy _classname,
%       _class_version) that predate the document_class header and
%       could not survive a real V2 build.
%
% (a) alone would misclassify a body that was tagged V2 out-of-
% band but still carries legacy field shapes; (b) alone would skip
% the bulk of v1 corpora, which do not happen to use the underscore
% markers but still need every other v1 -> V2 rewrite.
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
% AT OR BEYOND THE TARGET, not equal to it. `strcmp` here had no notion of
% before and after, so a body NEWER than the target took the same branch as one
% older than it -- and that branch runs the migrators. Converting an old body
% forward is the point; running the same pipeline over a body that has already
% passed the target is the opposite, and it was silent.
%
% An UNRECOGNISED version cannot reach here: refuseUnknownSchemaVersion runs
% first and quarantines it. The `~svKnown` guard below is kept as a defence for
% any other caller of this helper, and it returns FALSE only because a body
% that got this far with an unknown version is already a contradiction -- the
% refusal, not this line, is what decides that case.
[svRank, svKnown] = did2.convert.schemaVersionRank(sv);
% TARGETVERSION names the schema set ('V_eta'); its documents carry the stamp
% did2.convert.targetStamp gives ('did_v2', [document stamps]).
[tgtRank, tgtKnown] = did2.convert.schemaVersionRank( ...
    did2.convert.targetStamp(targetVersion));
if ~svKnown || ~tgtKnown || svRank < tgtRank
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
