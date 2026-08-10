%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 8: what does a v1 `oneepoch` document actually become?
%
%   `oneepoch` has NO V_eta schema at all -- it was tagged non-production in
%   coverage.py, so it never got one. Before writing its source tombstone I need
%   to know what the pipeline hands to the validator, because the top-level block
%   check is strict (`did2:validation:undeclaredBlock`) and the chain check is
%   exact (`superclassesChainMismatch`). Deriving the answer from cache.m +
%   v1_to_v2.m + the NDI templates is three inferences deep, and this project's
%   record on inferred shapes is bad.
%
%   Specifically I need to know, from the output rather than from reading:
%     1. What class name comes out (does a superclass migrator rename it?)
%     2. What TOP-LEVEL blocks survive -- above all, whether `element_epoch`
%        is still there, since `oneepoch`'s only declared superclass is
%        `element_epoch` and V_eta renames that class to `acquisition_epoch`.
%     3. What `document_class.superclasses` ends up as.
%     4. Whether the `oneepoch` block (epoch_ids) survives at all.
%
%   PROBE 7's LESSON, APPLIED: print the SHAPE first. v1_to_v2 returns
%   did2.document OBJECTS read with .get('dotted.path'), NOT structs. So this
%   prints class() and the raw struct before trying to interpret anything, and
%   every step is wrapped so a throw reports rather than blanks.
%
%   IT KEEPS PAYING FOR ITSELF.
%     probe 2/3  #63's family counter was reverted once as "undiagnosable" on
%                the strength of a pass/fail result. Probe 2 showed the
%                detection logic was RIGHT; probe 3 showed the counts were
%                computed and then never assigned to the report.
%     probe 5    printed MATLAB's empty shapes instead of guessing at them:
%                unique([]) is 0-by-1, so `for n = unique([])` iterates ONCE.
%     probe 6    checked the testCorpusPRED census wiring in 2 minutes instead
%                of assuming it across a 70-minute corpus run.
%     probe 7    UNDER-DELIVERED. It correctly isolated WHICH two tests failed,
%                but its diagnostic extraction printed nothing -- the
%                DiagnosticRecord walk was written blind and never verified. A
%                probe whose output you cannot check is a probe that can
%                mislead you.

fprintf('=== PROBE 8: v1 oneepoch through v1_to_v2 (TargetVersion V_eta) ===\n\n');

% The v1 body, built from NDI origin/main rather than from a DID-side schema:
%   oneepoch.json          superclasses: [ element_epoch ]   (its ONLY one)
%   oneepoch_schema.json   superclasses: ["element_epoch","base","epochid"]
%   element_epoch.json     depends_on element_id; files epoch_binary_data.vhsb;
%                          block { epoch_clock, t0_t1 }
%   element.m:387-391      writes element_epoch.epoch_clock, element_epoch.t0_t1,
%                          epochid.epochid, oneepoch.epoch_ids
%   oneepoch.m:42          epochid is SYNTHETIC: 'whole_session_<reference>'
%   oneepoch.m:124         epoch_clock is strjoin(ecs,',') -- a LIST of clocks
%   oneepoch.m:109-115     t0_t1 is a matrix, not the 2x1 a plain element_epoch has
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_1', 'session_id', 'sess_09', ...
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', ...
                          't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

fprintf('--- INPUT top-level keys ---\n');
disp(fieldnames(v1));

% ---- 1. unvalidated, so we see the SHAPE even if it would not validate ----
fprintf('\n--- v1_to_v2, Validate=false ---\n');
try
    out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
    fprintf('migrated: %d   quarantine: %d\n', ...
        numel(out.migrated), numel(out.quarantine));
    for i = 1:numel(out.quarantine)
        fprintf('  QUARANTINE class=%s reason=%s\n', ...
            out.quarantine(i).class_name, out.quarantine(i).reason);
    end
    for i = 1:numel(out.migrated)
        d = out.migrated{i};
        fprintf('\n  [%d] class() of the migrated item: %s\n', i, class(d));
        try
            s = d.toStruct();
        catch
            try
                s = d.documentProperties;
            catch err2
                fprintf('      could not get a struct: %s\n', err2.message);
                s = struct();
            end
        end
        fprintf('      class_name : %s\n', s.document_class.class_name);
        fprintf('      TOP-LEVEL keys:\n');
        fns = fieldnames(s);
        for k = 1:numel(fns)
            fprintf('        %s\n', fns{k});
        end
        fprintf('      superclasses chain:\n');
        sc = s.document_class.superclasses;
        for k = 1:numel(sc)
            fprintf('        %s\n', sc(k).class_name);
        end
        if isfield(s, 'oneepoch')
            fprintf('      oneepoch block SURVIVED: %s\n', ...
                strjoin(fieldnames(s.oneepoch)', ', '));
        else
            fprintf('      oneepoch block: GONE\n');
        end
        if isfield(s, 'element_epoch')
            fprintf('      element_epoch block SURVIVED: %s\n', ...
                strjoin(fieldnames(s.element_epoch)', ', '));
        else
            fprintf('      element_epoch block: GONE\n');
        end
        if isfield(s, 'acquisition_epoch')
            fprintf('      acquisition_epoch block PRESENT: %s\n', ...
                strjoin(fieldnames(s.acquisition_epoch)', ', '));
        end
    end
catch err
    fprintf('THREW: %s\n  %s\n', err.identifier, err.message);
    for k = 1:numel(err.stack)
        fprintf('    at %s:%d\n', err.stack(k).name, err.stack(k).line);
    end
end

% ---- 2. WITH validation, which is what the corpus actually does ----
fprintf('\n--- v1_to_v2, Validate=true (the real corpus path) ---\n');
try
    out2 = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
    fprintf('migrated: %d   quarantine: %d\n', ...
        numel(out2.migrated), numel(out2.quarantine));
    for i = 1:numel(out2.quarantine)
        fprintf('  QUARANTINE class=%s\n    reason: %s\n', ...
            out2.quarantine(i).class_name, out2.quarantine(i).reason);
    end
catch err
    fprintf('THREW: %s\n  %s\n', err.identifier, err.message);
end

% ---- 3. does the schema cache know either class? ----
fprintf('\n--- does the V_eta schema cache know these classes? ---\n');
for nm = {'oneepoch', 'element_epoch', 'acquisition_epoch', 'epoch'}
    try
        c = did2.schema.cache.shared();
        k = c.getClass(nm{1});
        fprintf('  %-20s KNOWN   (chain: %s)\n', nm{1}, ...
            strjoin(c.superclasses(nm{1}), ' <- '));
    catch err
        fprintf('  %-20s NOT KNOWN (%s)\n', nm{1}, err.identifier);
    end
end

fprintf('\n=== PROBE 8 done ===\n');
