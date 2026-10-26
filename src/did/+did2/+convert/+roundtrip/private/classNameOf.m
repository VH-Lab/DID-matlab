function name = classNameOf(body)
%CLASSNAMEOF An emitted body's document_class.class_name ('' when none).
name = '';
if isstruct(body) && isscalar(body) && isfield(body, 'document_class') ...
        && isstruct(body.document_class) && isfield(body.document_class, 'class_name')
    name = char(body.document_class.class_name);
end
end
