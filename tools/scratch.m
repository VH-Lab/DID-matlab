%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE: the tuning family's NDI writer outputs through v1_to_v2 today.
d = fullfile(pwd, 'tests', '+did2', 'fixtures', 'ndi_writer_outputs');
files = dir(fullfile(d, '*.json'));
for k = 1:numel(files)
    f = fullfile(d, files(k).name);
    v1 = jsondecode(fileread(f));
    fprintf('\n\n######## %s (class %s)\n', files(k).name, v1.document_class.class_name);
    for validate = [false true]
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
