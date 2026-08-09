%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 5: WHY did an empty distribution emit one row? The fix guards with
%   isempty rather than relying on `for n = unique(counts)` doing nothing, but
%   the guard should not stand on a guess about MATLAB's empty shapes. Print
%   them, so the comment states the mechanism instead of assuming it.

fprintf('=== shapes of empty unique() ===\n');
c = [];
fprintf('counts        = [] : size %s, class %s\n', mat2str(size(c)), class(c));
u = unique(c);
fprintf('unique(counts)     : size %s\n', mat2str(size(u)));
n = 0;
for x = u; n = n + 1; end %#ok<NASGU>
fprintf('iterations of `for x = unique(counts)` : %d   (0 would mean no phantom row)\n', n);

u2 = unique(c(:)');
fprintf('unique(counts(:)'') : size %s\n', mat2str(size(u2)));
n2 = 0;
for x = u2; n2 = n2 + 1; end %#ok<NASGU>
fprintf('iterations of `for x = unique(counts(:)'')` : %d\n', n2);

fprintf('\n=== the real thing: one approach, no presentations ===\n');
b = mk('openminds_stimulus', 'ap_1', 'epoch_lonely', '');
rep = did2.validate.sourceCensus({b});
fprintf('approach_doc_count              : %d\n', rep.approach_doc_count);
fprintf('approach_epochs_no_presentation : %d\n', rep.approach_epochs_no_presentation);
fprintf('presentation_doc_count          : %d\n', rep.presentation_doc_count);
fprintf('numel(subjects_per_approach_epoch) : %d   (expect 0)\n', ...
    numel(rep.subjects_per_approach_epoch));

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
