function [kind, value] = statementValue(doc)
%STATEMENTVALUE The value-kind block of a statement and its `value`.
%
%   [KIND, VALUE] = statementValue(DOC). A statement keeps its value in the
%   block of its value kind (`mass.value`, `term.value`, ...; T2/T3), the block
%   jStatement's 'ValueKind' names. KIND is that block's name ('' when the
%   document has none), VALUE its `value` field. The blocks every statement
%   has (document_class, base, depends_on, statement and the direction
%   classes) are skipped.
%
%   See also did2.convert.roundtrip.measurement.

kind = '';
value = [];
skip = {'document_class', 'base', 'depends_on', 'statement', 'observation', ...
    'assertion', 'manipulation', 'calculation', 'interaction', 'files', 'file'};
fns = fieldnames(doc);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, skip)); continue; end
    b = doc.(f);
    if isstruct(b) && isscalar(b) && isfield(b, 'value')
        kind = f;
        value = b.value;
        return;
    end
end
end
