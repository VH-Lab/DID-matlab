function names = hartleyParameterNames()
%HARTLEYPARAMETERNAMES The hartley_calc settings named by a decided term, as
%   {v1 path, v2 name} rows (+migrators_j/hartley_calc writes them through
%   jCalculation's 'ParameterNames'; +roundtrip/hartley_calc reads them back).
%
%   Decided by Jess Haley, 2026-11-09 [term picks batch 3] (did-schema
%   did_v2_go_forward_class_audit.md): "The hartley reconstruction's two steps
%   (`hartley.m` `1:X_sample:M`, 210 each) are two parameters, because a
%   method's parameter variables are unique: `X_sample` -> NCIT:C69201
%   Horizontal Pixel Spacing, `Y_sample` -> NCIT:C69210 Vertical Pixel
%   Spacing, plain numbers in stimulus pixels with no unit." The names resolve
%   to their nodes through the term registry (jLabel). Every other setting
%   keeps its v1 name with '_' as ' '.

names = { ...
    'X_sample', 'Horizontal Pixel Spacing'; ...
    'Y_sample', 'Vertical Pixel Spacing'};
end
