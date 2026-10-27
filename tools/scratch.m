%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 2: the tuning family's writer outputs, the carried fields removed.
d = fullfile(pwd, 'tests', '+did2', 'fixtures', 'ndi_writer_outputs');
files = dir(fullfile(d, '*.json'));
for k = 1:numel(files)
    f = fullfile(d, files(k).name);
    v1 = jsondecode(fileread(f));
    switch v1.document_class.class_name
        case 'tuningcurve_calc'
            v1.stimulus_tuningcurve.stimid = [];
            v1.stimulus_tuningcurve.stimulus_presentation_number = [];
            v1.tuningcurve_calc.log = 'contrast best value is 1.';
        case 'contrasttuning_calc'
            for m = {'RB', 'RBN', 'RBNS'}
                for x = {'relative_max_gain', 'saturation_index', 'sensitivity'}
                    v1.contrast_tuning.fit = rmfield(v1.contrast_tuning.fit, ['naka_rushton_' m{1} '_' x{1}]);
                end
            end
        case 'spatial_frequency_tuning_calc'
            v1.spatial_frequency_tuning = rmfield(v1.spatial_frequency_tuning, 'abs');
        case 'temporal_frequency_tuning_calc'
            v1.temporal_frequency_tuning = rmfield(v1.temporal_frequency_tuning, 'abs');
        otherwise
            continue;
    end
    fprintf('\n\n######## %s (class %s)\n', files(k).name, v1.document_class.class_name);
    for validate = false
        try
            out = did2.convert.v1_to_v2(v1, 'Validate', validate, 'TargetVersion', 'V_eta');
            fprintf('validate=%d migrated=%d quarantine=%d passthrough=%d\n', validate, ...
                numel(out.migrated), numel(out.quarantine), numel(out.passthrough));
            if ~isempty(out.quarantine)
                disp(out.quarantine);
                q = out.quarantine;
                if iscell(q); q = q{1}; end
                try; disp(q(1).reason); catch; end
                try; disp(q(1).error); catch; end
            end
            n = out.summary.migration_notes;
            fn = fieldnames(n);
            for j = 1:numel(fn)
                x = n.(fn{j});
                if isstruct(x) && isfield(x, 'distinct_details')
                    fprintf('  note %s: %s\n', fn{j}, strjoin(cellstr(x.distinct_details), ' || '));
                end
            end
            if ~validate
                for j = 1:numel(out.migrated)
                    s = out.migrated{j}.toStruct();
                    fprintf('--- doc %d class %s\n', j, s.document_class.class_name);
                    disp(jsonencode(s, 'PrettyPrint', true, 'ConvertInfAndNaN', false));
                    fprintf('    sizes: ');
                    printSizes(s, '');
                    fprintf('\n');
                end
            end
        catch ME
            fprintf(2, 'THREW %s: %s\n', ME.identifier, ME.message);
            for q = 1:numel(ME.stack)
                fprintf(2, '  at %s (line %d)\n', ME.stack(q).name, ME.stack(q).line);
            end
        end
    end
end

function printSizes(s, p)
if isstruct(s) && isscalar(s)
    fn = fieldnames(s);
    for i = 1:numel(fn)
        printSizes(s.(fn{i}), [p '.' fn{i}]);
    end
elseif isstruct(s)
    fprintf('%s=struct%s ', p, mat2str(size(s)));
    for i = 1:numel(s)
        printSizes(s(i), sprintf('%s(%d)', p, i));
    end
elseif isnumeric(s) || islogical(s)
    if ~isscalar(s)
        fprintf('%s=%s%s ', p, class(s), mat2str(size(s)));
    end
elseif iscell(s)
    fprintf('%s=cell%s ', p, mat2str(size(s)));
end
end
