function v2Body = element(preBody)
%ELEMENT Migrate a did_v1 element body to V_delta.
%
%   Field renames inside the element property block:
%       element.name -> element.element_name   (required, char)
%       element.type -> element.element_type   (optional, char)
%
%   Type coercions (v1 ships native JSON types that V_delta types
%   reject):
%       element.reference : numeric -> char   (V_delta type is char)
%       element.direct    : logical -> integer 0/1 (V_delta type is
%                                                  integer)
%
%   The v1 `ndi_element_class` field name is already snake_case and
%   matches the V_delta field name, so it is passed through unchanged.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'element') || ~isstruct(v2Body.element)
    error('did2:convert:missingBlock', ...
        'element body is missing the element property block.');
end

block = v2Body.element;

if isfield(block, 'name')
    block.element_name = char(block.name);
    block = rmfield(block, 'name');
end

if isfield(block, 'type')
    block.element_type = char(block.type);
    block = rmfield(block, 'type');
end

if isfield(block, 'reference')
    block.reference = toChar(block.reference);
end

if isfield(block, 'direct')
    block.direct = toInteger(block.direct);
end

v2Body.element = block;
end

function out = toChar(value)
if ischar(value)
    out = value;
elseif isstring(value) && isscalar(value)
    out = char(value);
elseif islogical(value) && isscalar(value)
    if value
        out = '1';
    else
        out = '0';
    end
elseif isnumeric(value) && isscalar(value)
    if value == floor(value) && isfinite(value)
        out = sprintf('%d', value);
    else
        out = sprintf('%g', value);
    end
else
    out = char(string(value));
end
end

function out = toInteger(value)
if islogical(value)
    out = double(value);
elseif isnumeric(value)
    out = double(value);
else
    error('did2:convert:badValue', ...
        'Cannot coerce value of type %s to integer.', class(value));
end
end
