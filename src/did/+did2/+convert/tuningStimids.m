function [stimid, spn, why] = tuningStimids(iv, params, condNames, condValues, responseId)
%TUNINGSTIMIDS Rebuild a v1 tuning curve's `stimid` and
%   `stimulus_presentation_number` from the stimulus presentation and the
%   curve's conditions.
%
%   [STIMID, SPN, WHY] = did2.convert.tuningStimids(IV, PARAMS, CONDNAMES,
%   CONDVALUES, RESPONSEID)
%     IV          the curve's independent_variable_value (n x d, one row per
%                 point; a vector is one column)
%     PARAMS      the d stimulus parameter names the curve varies (cellstr;
%                 tuningcurve_calc's input_parameters.independent_parameter,
%                 split at ','; for a raw stimulus_tuningcurve, its label)
%     CONDNAMES, CONDVALUES   the curve's conditions: the properties it holds
%                 fixed (v1 stim_property_list names / values)
%     RESPONSEID  the stimulus_response_scalar the curve was made from
%   STIMID and SPN are the two fields as the writer stores them and jsondecode
%   reads them back; WHY is '' when the rebuild ran, else why it could not
%   (STIMID and SPN are then []).
%
%   THE DECISION. Decided by Jess Haley, 2026-10-27 [tuning stimids rebuild]
%   (did-schema V_eta_go_forward_class_audit.md): "a tuning curve's `stimid`
%   and `stimulus_presentation_number` are not stored; the round trip rebuilds
%   them from the stimulus presentation and the curve's conditions; a curve
%   that does not rebuild exactly is carried whole as v1. The count over all
%   curves is reported." The migrators (jCalculation) compare this rebuild
%   with the v1 values and carry a curve where they differ; the round trip
%   (roundtrip/private/rawCurveBlock) writes it back.
%
%   THE WRITER'S RULE (NDI-matlab locked `main`,
%   +ndi/+app/+stimulus/tuning_response.m `tuning_curve`): for each
%   presentation stimulus n in order, when it is included, the point I whose
%   value equals the stimulus's values gets stimid(I) = n (so the LAST such n);
%   stimulus_presentation_number{I} = find(response stimid == n); both are
%   stored through vlt.data.cellarray2mat (one column per point, NaN-padded)
%   and JSON. "Included" is the writer's constraint list, which the curve does
%   not store in full: here a stimulus is included when it holds every
%   varied parameter as one number and every condition at its value. A curve
%   whose writer excluded a stimulus this includes rebuilds differently, and
%   is carried.
%
%   The response and the presentation are read from the batch
%   (did2.convert.tuningBatchIndex); one not in the batch is not a rebuild.

arguments
    iv
    params cell
    condNames cell
    condValues
    responseId
end

stimid = [];
spn = [];
why = '';
responseId = char(responseId);
[r, found] = did2.convert.tuningBatchIndex('response', responseId);
if isempty(responseId) || ~found
    why = sprintf('response %s is not in the batch', responseId);
    return;
end
[stimuli, found] = did2.convert.tuningBatchIndex('presentation', r.presentation_id);
if ~found
    why = sprintf('presentation %s is not in the batch', r.presentation_id);
    return;
end
if isempty(params)
    why = 'no varied stimulus parameter is named';
    return;
end
iv = double(iv);
if isvector(iv) && isscalar(params)
    iv = iv(:);
end
if size(iv, 2) ~= numel(params)
    why = sprintf('%d varied parameters for %d value columns', numel(params), size(iv, 2));
    return;
end
condValues = double(condValues(:)');
if numel(condValues) ~= numel(condNames)
    why = 'the conditions'' names and values differ in number';
    return;
end
n = size(iv, 1);
ids = nan(1, n);
for s = 1:numel(stimuli)
    p = stimuli{s};
    ok = true;
    for c = 1:numel(condNames)
        v = valueAt(p, condNames{c});
        if ~(isnumeric(v) && isscalar(v) && double(v) == condValues(c))
            ok = false;
            break;
        end
    end
    if ~ok; continue; end
    val = zeros(1, numel(params));
    for i = 1:numel(params)
        v = valueAt(p, params{i});
        if ~(isnumeric(v) && isscalar(v))
            ok = false;
            break;
        end
        val(i) = double(v);
    end
    if ~ok; continue; end
    I = find(all(iv == val, 2));
    ids(I) = s;
end
cols = cell(1, n);
for I = 1:n
    if isnan(ids(I))
        cols{I} = [];
    else
        cols{I} = find(r.stimid == ids(I));
    end
end
m = cellarray2mat(cols);
stimid = jsondecode(jsonencode(ids));
spn = jsondecode(jsonencode(m));
end

function v = valueAt(p, name)
%VALUEAT P.(NAME), NAME a field or a dotted path; [] when absent.
v = [];
parts = strsplit(char(name), '.');
for k = 1:numel(parts)
    if ~isstruct(p) || ~isscalar(p) || ~isfield(p, parts{k})
        v = [];
        return;
    end
    p = p.(parts{k});
end
v = p;
end

function m = cellarray2mat(c)
%CELLARRAY2MAT vlt.data.cellarray2mat (vhlab-toolbox-matlab): each cell a
%   column, the shorter ones padded with NaN.
if isempty(c)
    m = [];
    return;
end
rows = max(cellfun(@numel, c));
m = NaN(rows, numel(c));
for i = 1:numel(c)
    m(1:numel(c{i}), i) = c{i}(:);
end
end
