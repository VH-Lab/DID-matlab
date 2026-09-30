function [datumType, sourceDatumType] = datumType(typeName, options)
%DATUMTYPE The V_eta `datum_type` for a MATLAB or source type name.
%
%   [DT, SOURCE] = did2.build.datumType(TYPENAME) maps a type name onto the
%   data_type.datum_type enum
%
%       uint8 uint16 uint32 uint64 int8 int16 int32 int64
%       float16 float32 float64 complex64 complex128 bool utf8
%
%   and returns SOURCE, the name as given, for `source_datum_type`. SOURCE is
%   '' when TYPENAME is already canonical (the source adds nothing).
%
%       int*/uint*/float*/complex*/bool/utf8   unchanged
%       'double'            float64    ('Complex', true -> complex128)
%       'single'            float32    ('Complex', true -> complex64)
%       'logical', 'ubit1'  bool
%       'string'            utf8       MATLAB text
%
%   For a MATLAB array X, use did2.build.datumType(class(X), 'Complex', ~isreal(X)).
%
%   ANY OTHER NAME IS AN ERROR (did2:build:unknownDatumType), including 'char':
%   as a MATLAB class it is text, but as an fread/fwrite precision (which is
%   where most source type names come from) it is an 8-bit integer. The caller
%   knows which it meant; pass 'utf8' or 'uint8'.
%
%   The name mapping follows +migrators_j/private/jDatumType.m (int/uint
%   identical, double->float64, single->float32, logical/ubit1->bool); 'string'
%   -> utf8 and the complex forms are added here.

arguments
    typeName {mustBeTextScalar}
    options.Complex (1,1) logical = false
end

raw = char(typeName);
canonical = {'uint8', 'uint16', 'uint32', 'uint64', 'int8', 'int16', 'int32', ...
    'int64', 'float16', 'float32', 'float64', 'complex64', 'complex128', 'bool', 'utf8'};
if any(strcmp(raw, canonical))
    datumType = raw;
    sourceDatumType = '';
    if options.Complex && ~startsWith(raw, 'complex')
        error('did2:build:unknownDatumType', ...
            '"%s" is not a complex type; name the complex type instead.', raw);
    end
    return;
end
switch raw
    case 'double'
        datumType = 'float64';
        if options.Complex; datumType = 'complex128'; end
    case 'single'
        datumType = 'float32';
        if options.Complex; datumType = 'complex64'; end
    case {'logical', 'ubit1'}
        datumType = 'bool';
    case 'string'
        datumType = 'utf8';
    otherwise
        error('did2:build:unknownDatumType', ...
            ['No datum_type for "%s". Name one of: %s (or double, single, ' ...
             'logical, ubit1, string).'], raw, strjoin(canonical, ', '));
end
if options.Complex && ~startsWith(datumType, 'complex')
    error('did2:build:unknownDatumType', '"%s" cannot be complex.', raw);
end
sourceDatumType = raw;
end
