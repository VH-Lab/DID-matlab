function tests = testCalculatorTemplate
%TESTCALCULATORTEMPLATE did2.convert.v1read.calculatorTemplate is the NDI
%   templates and the writers' outputs it says it is.
%
%   private/jCalculation cites a field it cannot place by this table: carry-100
%   for a field outside the class's NDI template, carry-056 for a template
%   field the writer writes with no V2 home (Decided by Jess Haley, 2026-10-27
%   [tuning stray fields are malformed], did-schema
%   V_eta_go_forward_class_audit.md). A table that drifted from the templates
%   would cite the wrong row without failing anything else, so it is checked
%   here against the fixture copies the round-trip tests already use:
%   tests/+did2/fixtures/ndi_templates (NDIcalc-vis-matlab 00e3e0f; NDI-matlab
%   3cb19a8) and tests/+did2/fixtures/ndi_writer_outputs.
tests = functiontests(localfunctions);
end

function testTheTableIsTheTemplates(testCase)
% every class's paths and edges are exactly its composed template's
inspected = 0;
for c = classNames()
    t = did2.convert.v1read.calculatorTemplate(c{1});
    verifyTrue(testCase, t.found, c{1});
    [paths, edges] = composed(c{1});
    % jsondecode reads a one-entry JSON list of objects (a block's inner
    % depends_on, tuningcurve_calc's input_parameters.selection) as a struct,
    % so its fields come back as paths under the table's leaf: compare each
    % fixture path with the table leaf that holds it
    held = cellfun(@(p) holder(p, t.paths), paths, 'UniformOutput', false);
    verifyEmpty(testCase, paths(cellfun(@isempty, held)), ...
        [c{1} ': template paths the table does not hold']);
    verifyEqual(testCase, sort(reshape(unique(held(~cellfun(@isempty, held))), 1, [])), ...
        sort(reshape(t.paths, 1, [])), ...
        [c{1} ': table paths that are not template paths']);
    verifyEqual(testCase, sort(t.edges), sort(strcat('^', edges, '$')), [c{1} ': edges']);
    inspected = inspected + 1;
end
verifyEqual(testCase, inspected, 14, 'the 14 classes jCalculation folds');
end

function testEveryWriterFieldIsInTheTable(testCase)
% every non-empty field and edge of each writer's stored output is a template
% or writer path of its class's row; every writer path is one the writer wrote
% (orientation_direction_tuning's `app` is ndi.app's newdocument(), which has no
% stored output here)
files = dir(fullfile(fixtureDir(), 'ndi_writer_outputs', '*.json'));
verifyGreaterThan(testCase, numel(files), 0, 'no writer outputs found');
for k = 1:numel(files)
    m = jsondecode(fileread(fullfile(files(k).folder, files(k).name)));
    c = char(m.document_class.class_name);
    t = did2.convert.v1read.calculatorTemplate(c);
    verifyTrue(testCase, t.found, c);
    defs = lower([t.paths, t.writer_paths]);
    leaves = documentLeaves(m, false);
    for j = 1:numel(leaves)
        verifyTrue(testCase, covered(lower(leaves{j}), defs), ...
            sprintf('%s: the writer writes %s, which the table does not hold', c, leaves{j}));
    end
    written = lower(documentLeaves(m, true));   % a template blank is written too
    for j = 1:numel(t.writer_paths)
        w = lower(t.writer_paths{j});
        verifyTrue(testCase, any(strcmp(written, w)) || any(startsWith(written, [w '.'])), ...
            sprintf('%s: writer path %s is not in the writer''s output', c, t.writer_paths{j}));
    end
    names = edgeNames(m);
    res = [t.edges, t.writer_edges];
    for j = 1:numel(names)
        verifyTrue(testCase, any(cellfun(@(re) ~isempty(regexp(names{j}, re, 'once')), res)), ...
            sprintf('%s: the writer writes edge %s, which the table does not hold', c, names{j}));
    end
end
end

function testAliasesAndAnUnknownClass(testCase)
for a = {'contrast_tuning_calc', 'contrasttuning_calc'; ...
        'contrast_sensitivity_calc', 'contrastsensitivity_calc'; ...
        'speed_tuning_calc', 'speedtuning_calc'}'
    t = did2.convert.v1read.calculatorTemplate(a{1});
    verifyTrue(testCase, t.found, a{1});
    verifyEqual(testCase, t.class_name, a{2});
end
t = did2.convert.v1read.calculatorTemplate('subject');
verifyFalse(testCase, t.found);
verifyEmpty(testCase, t.paths);
end

% ===================== helpers =========================================

function c = classNames()
c = {'contrastsensitivity_calc', 'contrasttuning_calc', 'contrast_tuning', ...
    'hartley_calc', 'oridirtuning_calc', 'orientation_direction_tuning', ...
    'spatial_frequency_tuning', 'spatial_frequency_tuning_calc', 'speed_tuning', ...
    'speedtuning_calc', 'stimulus_tuningcurve', 'temporal_frequency_tuning', ...
    'temporal_frequency_tuning_calc', 'tuningcurve_calc'};
end

function d = fixtureDir()
thisDir = fileparts(mfilename('fullpath'));
d = fullfile(fileparts(thisDir), 'fixtures');
end

function [paths, edges] = composed(cls)
%COMPOSED The leaf paths and depends_on names of template CLS over its
%   superclasses (base.json's identity and document_class excluded; the empty
%   `calculator` block declares no field and is not a path).
s = jsondecode(fileread(fullfile(fixtureDir(), 'ndi_templates', [cls '.json'])));
paths = {};
edges = edgeNames(s);
fns = fieldnames(s);
for k = 1:numel(fns)
    if any(strcmp(fns{k}, {'document_class', 'base', 'depends_on'}))
        continue;
    end
    paths = [paths, leavesOf(s.(fns{k}), fns{k})]; %#ok<AGROW>
end
sup = s.document_class.superclasses;
if isstruct(sup); sup = num2cell(sup); end
for k = 1:numel(sup)
    [~, name] = fileparts(char(sup{k}.definition));
    if strcmp(name, 'base')
        continue;
    end
    [p, e] = composed(name);
    paths = [paths, p]; %#ok<AGROW>
    edges = [edges, e]; %#ok<AGROW>
end
paths = unique(paths(~strcmp(paths, 'calculator')));
edges = unique(edges);
end

function c = leavesOf(v, p)
%LEAVESOF Every leaf path under P: a scalar struct with fields is walked; any
%   other value (an empty struct, an array, a list) is a leaf.
if isstruct(v) && isscalar(v) && ~isempty(fieldnames(v))
    c = {};
    fns = fieldnames(v);
    for k = 1:numel(fns)
        c = [c, leavesOf(v.(fns{k}), [p '.' fns{k}])]; %#ok<AGROW>
    end
else
    c = {p};
end
end

function c = documentLeaves(m, withEmpty)
%DOCUMENTLEAVES The leaf paths of a stored document (the non-empty ones unless
%   WITHEMPTY), outside its identity, document_class and depends_on.
c = {};
fns = fieldnames(m);
for k = 1:numel(fns)
    if any(strcmp(fns{k}, {'document_class', 'base', 'depends_on'}))
        continue;
    end
    for p = leavesOf(m.(fns{k}), fns{k})
        if withEmpty || ~isEmptyAt(m, p{1})
            c{end+1} = p{1}; %#ok<AGROW>
        end
    end
end
end

function tf = isEmptyAt(m, p)
v = m;
parts = strsplit(p, '.');
for k = 1:numel(parts)
    v = v.(parts{k});
end
tf = isempty(v) || (isstruct(v) && isscalar(v) && isempty(fieldnames(v)));
end

function h = holder(p, defs)
%HOLDER The entry of DEFS equal to P, or the one P lies under ('' if none).
h = '';
for k = 1:numel(defs)
    if strcmp(p, defs{k}) || startsWith(p, [defs{k} '.'])
        h = defs{k};
        return;
    end
end
end

function tf = covered(p, defs)
tf = any(strcmp(p, defs)) || any(startsWith(p, strcat(defs, '.')));
end

function n = edgeNames(s)
n = {};
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
d = s.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    n{end+1} = char(d{k}.name); %#ok<AGROW>
end
end
