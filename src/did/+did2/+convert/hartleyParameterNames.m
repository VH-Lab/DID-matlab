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
%
%   Decided by Jess Haley, 2026-11-19 [hartley frame times are onset times]
%   (VH-Lab/DID-matlab#486): the stimulus sequence's frame times
%   (`hartley_reverse_correlation.frameTimes`, a method parameter under
%   `stimulus_sequence` until the stimulus model holds the sequence) are
%   EMPTY:0000368 "onset time". +migrators_j/hartley_calc writes that node
%   (its sequenceParameterName); this row is how the round trip puts the entry back
%   under `stimulus_sequence`, as the two rows above put theirs back.

names = { ...
    'X_sample', 'Horizontal Pixel Spacing'; ...
    'Y_sample', 'Vertical Pixel Spacing'; ...
    'stimulus_sequence.frame_times', 'onset time'};
end
