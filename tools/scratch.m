%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE: [tuning stimids rebuild] (Jess Haley, 2026-10-27) over the
%   20211116 and Soph corpora. Each corpus is cut to the four classes the
%   rebuild reads (tuning curves, their responses, their presentations), run
%   through did2.convert.v1_to_v2, and the per-curve outcome printed with its
%   denominator, plus the distinct carry notes of the curves.

classes = {'tuningcurve_calc', 'stimulus_tuningcurve', 'stimulus_response_scalar', ...
    'stimulus_presentation'};
corpora = {'20211116', 'Soph'};
for c = 1:numel(corpora)
    name = corpora{c};
    url = ['https://ndi-programming-development.s3.us-east-1.amazonaws.com/' name '.zip'];
    dirc = did2.unittest.helpers.ensureCorpus(url, ['did2-corpus-' name], name);
    files = dir(fullfile(dirc, '*.json'));
    files = files(~startsWith({files.name}, '._'));
    fprintf('\n===== %s: %d JSON file(s) in the corpus\n', name, numel(files));
    bodies = {};
    for k = 1:numel(files)
        t = fileread(fullfile(files(k).folder, files(k).name));
        m = regexp(t, '"class_name"\s*:\s*"([^"]*)"', 'tokens', 'once');
        if isempty(m) || ~any(strcmp(m{1}, classes)); continue; end
        b = jsondecode(t);
        cn = did2.convert.v1read.readStamp(b).class_name;
        if any(strcmp(cn, classes)); bodies{end+1} = b; end %#ok<SAGROW>
    end
    cls = cellfun(@(b) char(did2.convert.v1read.readStamp(b).class_name), bodies, 'UniformOutput', false);
    for k = 1:numel(classes)
        fprintf('  read %-26s %d\n', classes{k}, sum(strcmp(cls, classes{k})));
    end
    out = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
    fprintf('  migrated %d, quarantined %d\n', numel(out.migrated), numel(out.quarantine));
    n = out.summary.migration_notes;
    if isfield(n, 'tuning_stimid_rebuild')
        s = n.tuning_stimid_rebuild;
        fprintf('  tuning_stimid_rebuild notes (one per curve): %d\n', s.count);
        for k = 1:numel(s.distinct_details)
            fprintf('    %-20s %d\n', s.distinct_details{k}, s.distinct_detail_counts(k));
        end
    else
        fprintf('  tuning_stimid_rebuild: NO NOTES (no curve reached the fold)\n');
    end
    if isfield(n, 'carried_as_v1')
        s = n.carried_as_v1;
        fprintf('  carried_as_v1 notes: %d; by class:\n', s.count);
        disp(s.by_class);
        [~, ix] = sort(s.distinct_detail_counts, 'descend');
        for k = ix(1:min(15, numel(ix)))
            d = s.distinct_details{k};
            d = regexprep(d, '[0-9a-f]{16}_[0-9a-f]{16}', '<id>');
            fprintf('    %6d  %s\n', s.distinct_detail_counts(k), d(1:min(end, 400)));
        end
    end
end
