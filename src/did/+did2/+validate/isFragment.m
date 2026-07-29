function tf = isFragment(v2Bodies, opts)
%ISFRAGMENT Did a migration produce nothing but scaffolding?
%
%   TF = did2.validate.isFragment(V2BODIES) returns true when every body in the
%   cell array V2BODIES is a SCAFFOLDING class -- a time_reference or a relation
%   -- i.e. the migration emitted support for a statement it never made.
%
%   TF = did2.validate.isFragment(V2BODIES, 'SchemaCache', C) resolves class
%   chains through C instead of the shared cache.
%
%   ---------------------------------------------------------------------
%   THE FRAGMENT FAILURE MODE
%   ---------------------------------------------------------------------
%   A migrator can fail in three ways, and only two had a counter:
%
%     HOLLOW      emits documents with blank values -> did2.validate.silentLoss
%     PASSTHROUGH hands its input straight back      -> unconverted_by_class
%     FRAGMENT    drops the payload, emits only side documents -> THIS
%
%   A fragment is not hollow (no required field is left blank) and not a
%   passthrough (output WAS produced), so both other counters score it as a
%   clean migration and migrated_count goes up. vmneuralresponseresiduals,
%   simple_calc, fitcurve and vmspikefit all failed this way -- each emitted a
%   lone session_relative_reference anchor while the measurement it existed to
%   carry went nowhere, and every gate stayed green. All four were found by
%   reading source, not by any check.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS ITS OWN FUNCTION
%   ---------------------------------------------------------------------
%   It started as a local function inside v1_to_v2, which meant it could only be
%   tested end-to-end THROUGH a migrator that actually fragments -- and every
%   migrator that used to has since been repaired. The first version of its test
%   suite asserted the historical behaviour of two migrators that are now
%   guarded passthroughs, and failed for exactly that reason.
%
%   A detector that needs a broken migrator to exist in order to be tested is in
%   the wrong place. Here it takes bodies and answers a question about them, so
%   the synthetic cases can be written directly and the detector keeps working
%   after the last real fragment is fixed.
%
%   The signature is STRUCTURAL, not name-based: resolved through the class
%   chain, so a new time_reference or relation subclass is covered without
%   editing a list. Deliberately NOT id-based -- "the source id is preserved
%   somewhere" is a different and also useful rule, but it would flag every
%   legitimate decomposition that mints fresh ids, and would miss a fragment
%   that happens to carry its id on the anchor.
arguments
    v2Bodies
    opts.SchemaCache = []
end

tf = false;
if isempty(v2Bodies); return; end
if ~iscell(v2Bodies); v2Bodies = {v2Bodies}; end

for k = 1:numel(v2Bodies)
    if ~isScaffoldingClass(v2Bodies{k}, opts.SchemaCache)
        return;   % something substantive was emitted -- not a fragment
    end
end
tf = true;
end

% ===================== helpers =============================================

function tf = isScaffoldingClass(body, cache)
%ISSCAFFOLDINGCLASS Is this body a time reference or a relation?
tf = false;
if ~isstruct(body) || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isfield(body.document_class, 'class_name')
    return;
end
name = char(body.document_class.class_name);
chain = {name};
try
    if isempty(cache); cache = did2.schema.cache.shared(); end
    chain = [chain, reshape(cellstr(cache.classChain(name)), 1, [])]; %#ok<AGROW>
catch
    % No schema available: fall back to the superclasses declared on the body.
    % The audit must never be able to break a migration.
    try
        sc = body.document_class.superclasses;
        for i = 1:numel(sc)
            chain{end+1} = char(sc(i).class_name); %#ok<AGROW>
        end
    catch
    end
end
tf = any(ismember({'time_reference', 'relation'}, chain));
end
