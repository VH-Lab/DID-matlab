%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 3 (#79): probe 2 proved the detection logic is right -- it found
%   time_reference_# with min_count 1 and computed VIOLATION=1 on a body with no
%   edges. So the fault was downstream of detection, in the REPORT. This probe
%   calls the real silentLoss and prints what comes back, so a failure names
%   itself instead of costing another round trip.

fprintf('=== silentLoss on a voltage_observation with NO edges ===\n');
b = struct();
b.document_class = struct('class_name', 'voltage_observation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', 'probe_1', 'session_id', 'sess_1', 'name', 'probe_1', ...
    'datestamp', '2024-06-01T12:00:00.000Z');

rep = did2.validate.silentLoss({did2.document(b)});
disp(rep);

fprintf('\nfamily_violation_count : %s\n', mat2str(rep.family_violation_count));
fprintf('family_count_violation : class %s, numel %d\n', ...
    class(rep.family_count_violation), numel(rep.family_count_violation));
if ~isempty(rep.family_count_violation)
    fprintf('fields: %s\n', strjoin(fieldnames(rep.family_count_violation)', ', '));
    for k = 1:numel(rep.family_count_violation)
        e = rep.family_count_violation(k);
        fprintf('  [%d] %s / %s  declared=%s found=%s count=%d\n', k, ...
            e.class_name, e.edge_name, e.declared, e.found, e.count);
    end
else
    fprintf('EMPTY -- detection ran (probe 2 proved it) but nothing reached the report.\n');
end

fprintf('\n=== and a body that SATISFIES the family ===\n');
b2 = b;
b2.depends_on = struct('name', {'time_reference_1'}, 'value', {'tr_1'});
rep2 = did2.validate.silentLoss({did2.document(b2)});
fprintf('family_violation_count : %s (expect 0)\n', mat2str(rep2.family_violation_count));

fprintf('\nDONE\n');
