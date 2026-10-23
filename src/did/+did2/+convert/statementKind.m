function [direction, kind] = statementKind(body)
%STATEMENTKIND The direction class and value kind of a statement document.
%
%   [DIRECTION, KIND] = did2.convert.statementKind(BODY). On did-schema #88 a
%   statement is a direction class ('observation', 'assertion', 'manipulation',
%   'calculation') whose `superclasses` list ONE value-kind mixin ('voltage',
%   'term', ...); DIRECTION is the class and KIND the mixin. One of the named
%   calculator classes (V_eta stable/*_calculation.json: tuning_curve and its
%   five descendants, receptive_field, contrast_sensitivity) answers its own
%   class name and KIND ''. Anything that is not a statement answers its
%   class_name (or '') and KIND ''.
%
%   OLD-VINTAGE INPUT. A document written before the port names a joined
%   '<kind>_<direction>' class. It is READ here as DIRECTION plus KIND, so a
%   matcher that uses this function recognises both vintages. Nothing may
%   write that form (tests/+did2/+unittest/testNoOldLeafNames.m).
%
%   See also did2.build.statement ('ValueKind'), did2.schema.cache/documentValueKind.

direction = '';
kind = '';
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) || ~isfield(body.document_class, 'class_name')
    return;
end
cn = char(body.document_class.class_name);
direction = cn;
directions = {'observation', 'assertion', 'manipulation', 'calculation'};
if any(strcmp(cn, directions))
    names = superclassNames(body.document_class);
    try
        kind = char(did2.schema.cache.shared().documentValueKind(cn, names));
    catch
        kind = firstNonSpine(names);
    end
    return;
end
if any(strcmp(cn, namedCalculators()))
    return;
end
% old vintage: '<kind>_<direction>' (accepted on input only)
for d = 1:numel(directions)
    suffix = ['_' directions{d}];
    if numel(cn) > numel(suffix) && endsWith(cn, suffix)
        direction = directions{d};
        kind = cn(1:end - numel(suffix));
        return;
    end
end
end

function names = namedCalculators()
% The eight named calculators of did-schema #88 (stable/*_calculation.json).
names = {'tuning_curve_calculation', 'orientation_direction_tuning_calculation', ...
    'spatial_frequency_tuning_calculation', 'temporal_frequency_tuning_calculation', ...
    'speed_tuning_calculation', 'contrast_tuning_calculation', ...
    'receptive_field_calculation', 'contrast_sensitivity_calculation'};
end

function names = superclassNames(dc)
names = {};
if ~isfield(dc, 'superclasses'); return; end
sc = dc.superclasses;
if isstruct(sc); sc = num2cell(sc); end
if ~iscell(sc); return; end
names = cell(1, numel(sc));
for k = 1:numel(sc)
    if isstruct(sc{k}) && isfield(sc{k}, 'class_name')
        names{k} = char(sc{k}.class_name);
    else
        names{k} = char(sc{k});
    end
end
end

function kind = firstNonSpine(names)
% Without a schema cache: the first superclass that is not on a statement's
% own spine.
spine = {'base', 'statement', 'interaction', 'observation', 'assertion', ...
    'manipulation', 'calculation', 'value'};
kind = '';
for k = 1:numel(names)
    if ~any(strcmp(names{k}, spine))
        kind = names{k};
        return;
    end
end
end
