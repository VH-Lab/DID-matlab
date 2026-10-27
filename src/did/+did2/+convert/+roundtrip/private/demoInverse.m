function [v1, spec] = demoInverse(bodies, v1Class)
%DEMOINVERSE A v1 `demoNDI` / `demoNDIMock` rebuilt from the `demo` document
%   +migrators_j/private/jDemoFold made of it.
%
%   [V1, SPEC] = demoInverse(BODIES, V1CLASS). BODIES is the one `demo`
%   document (id preserved): base and edges are the v1 ones with v1_to_v2's
%   outbound renames undone (private/undoOutbound); `files` is the v1 block,
%   kept. demoNDI.value is demo.value; for demoNDIMock, mock.ismock is
%   demo.mock and the demoNDIMock block is empty, as the template has it.
%
%   See also did2.convert.roundtrip.demoNDI, did2.convert.roundtrip.demoNDIMock.

spec = emptySpec();
v1 = struct();
if ~(isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'demo'))
    spec.unplaced{end+1} = sprintf('%d emitted document(s); the demo fold emits one demo', ...
        numel(bodies));
    return;
end
v1 = undoOutbound(bodies{1});
demo = struct();
if isfield(v1, 'demo'); demo = v1.demo; v1 = rmfield(v1, 'demo'); end
v1.document_class = struct('class_name', v1Class);
v1.demoNDI = struct('value', []);
if isfield(demo, 'value'); v1.demoNDI.value = demo.value; end
if strcmp(v1Class, 'demoNDIMock')
    v1.demoNDIMock = struct();
    v1.mock = struct('ismock', []);
    if isfield(demo, 'mock'); v1.mock.ismock = double(demo.mock); end
end
fns = setdiff(fieldnames(v1), {'document_class', 'base', 'depends_on', 'files', ...
    'demoNDI', 'demoNDIMock', 'mock'});
for k = 1:numel(fns)
    if ~allEmpty(v1.(fns{k}))
        spec.unplaced{end+1} = sprintf('the demo document carries a %s block', fns{k}); %#ok<AGROW>
    end
end
end
