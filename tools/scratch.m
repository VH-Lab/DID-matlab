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
shown = 0;
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
    % why a curve does not rebuild: the first three of this corpus, side by side
    nShown = 0;
    for k = 1:numel(bodies)
        if nShown >= 3 || ~strcmp(cls{k}, 'tuningcurve_calc'); continue; end
        b = bodies{k};
        st = b.stimulus_tuningcurve;
        ip = b.tuningcurve_calc.input_parameters;
        spl = struct('names', {{}}, 'values', []);
        if isfield(b.tuningcurve_calc, 'stim_property_list'); spl = b.tuningcurve_calc.stim_property_list; end
        names = spl.names; if ischar(names); names = {names}; end; if isempty(names); names = {}; end
        rid = '';
        for j = 1:numel(b.depends_on)
            if strcmp(b.depends_on(j).name, 'stimulus_response_scalar_id'); rid = b.depends_on(j).value; end
        end
        [rs, rspn, why] = did2.convert.tuningStimids(st.independent_variable_value, ...
            strtrim(strsplit(char(ip.independent_parameter), ',')), reshape(names, 1, []), spl.values, rid);
        v1s = jsondecode(jsonencode(st.stimid));
        if isempty(why) && isequaln(rs, v1s) && isequaln(rspn, jsondecode(jsonencode(st.stimulus_presentation_number)))
            continue;
        end
        nShown = nShown + 1;
        fprintf('\n  CURVE %s  why=%s\n', b.base.id, why);
        fprintf('    independent_parameter=%s  label=%s\n', char(ip.independent_parameter), jsonencode(st.independent_variable_label));
        fprintf('    selection=%s\n', jsonencode(ip.selection));
        fprintf('    stim_property_list=%s\n', jsonencode(spl));
        lg = ''; if isfield(b.tuningcurve_calc, 'log'); lg = b.tuningcurve_calc.log; end
        fprintf('    log=%s\n', char(lg));
        fprintf('    iv=%s\n', jsonencode(st.independent_variable_value));
        fprintf('    v1 stimid      =%s\n', jsonencode(v1s));
        fprintf('    rebuilt stimid =%s\n', jsonencode(rs));
        fprintf('    v1 spn size %s, rebuilt %s; equal stimid %d\n', mat2str(size(jsondecode(jsonencode(st.stimulus_presentation_number)))), mat2str(size(rspn)), isequaln(rs, v1s));
        [r, ~] = did2.convert.tuningBatchIndex('response', rid);
        [p, ~] = did2.convert.tuningBatchIndex('presentation', r.presentation_id);
        fprintf('    presentation stimuli: %d; first two params: %s | %s\n', numel(p), jsonencode(p{1}), jsonencode(p{min(2, end)}));
    end
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
