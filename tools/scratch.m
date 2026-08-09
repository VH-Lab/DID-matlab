%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 4: the new v1 SOURCE census (did2.validate.sourceCensus). Runs its
%   test file and PRINTS every diagnostic, rather than letting the quick gate
%   reduce a failure to a red X. #63 cost two CI rounds and a revert to that
%   exact economy, so the first run of a new instrument gets the log.

fprintf('=== testSourceCensus ===\n');
r = runtests('did2.unittest.testSourceCensus');
disp(table(r));
for k = 1:numel(r)
    if r(k).Failed
        fprintf(2, '\n--- FAILED: %s ---\n', r(k).Name);
        d = r(k).Details;
        if isfield(d, 'DiagnosticRecord')
            for j = 1:numel(d.DiagnosticRecord)
                fprintf(2, '%s\n', d.DiagnosticRecord(j).Report);
            end
        end
    end
end

fprintf('\n=== a hand-built census, printed in full ===\n');
docs = { ...
    mk('session',              'sess_doc', '',                 ''), ...
    mk('spikewaves',           'w1',       'epoch_aaa',        'el_1'), ...
    mk('spikewaves',           'w2',       'epoch_aaa',        'el_2'), ...
    mk('spikewaves',           'w3',       'whole_session_r',  'el_1'), ...
    mk('spikewaves',           'w4',       'whole_session_r',  'el_2'), ...
    mk('openminds_stimulus',   'ap_1',     'epoch_aaa',        ''), ...
    mk('stimulus_presentation','p1',       'epoch_aaa',        'stim_1'), ...
    mk('stimulus_presentation','p2',       'epoch_aaa',        'stim_2')};
rep = did2.validate.sourceCensus(docs);
disp(rep);
fprintf('epoch_id_by_prefix:\n');
for k = 1:numel(rep.epoch_id_by_prefix)
    e = rep.epoch_id_by_prefix(k);
    fprintf('  %-16s %d distinct, %d doc(s)\n', e.prefix, e.distinct_ids, e.doc_count);
end
fprintf('synthetic ids (expect 1, fusing 2 elements): %d\n', rep.synthetic_epoch_id_count);
for k = 1:numel(rep.synthetic_epoch_ids)
    s = rep.synthetic_epoch_ids(k);
    fprintf('  %s fuses %d element(s) over %d doc(s)\n', ...
        s.epoch_id, s.distinct_elements, s.doc_count);
end
fprintf('session docs: %d, distinct session ids: %d\n', ...
    rep.session_doc_count, rep.distinct_session_ids);
fprintf('subjects per approach epoch (expect 2 subjects x 1 epoch):\n');
for k = 1:numel(rep.subjects_per_approach_epoch)
    d = rep.subjects_per_approach_epoch(k);
    fprintf('  %d subject(s): %d epoch(s)\n', d.n_subjects, d.n_epochs);
end

fprintf('\nDONE\n');

function b = mk(className, id, epochId, elementId)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
if ~isempty(epochId); b.epochid = struct('epochid', epochId); end
if ~isempty(elementId)
    b.depends_on = struct('name', 'stimulus_element_id', 'value', elementId);
end
end
