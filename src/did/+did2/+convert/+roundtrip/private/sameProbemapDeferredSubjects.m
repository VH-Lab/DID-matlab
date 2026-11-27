function tf = sameProbemapDeferredSubjects(v1pm, rebuiltPm)
%SAMEPROBEMAPDEFERREDSUBJECTS True when a rebuilt probe map is the v1 one
%   except for the subjectstring of the rows whose element's subject is
%   deferred to NDI-matlab's second pass.
%
%   TF = sameProbemapDeferredSubjects(V1PM, REBUILTPM). Decided by Jess Haley,
%   2026-11-26 [no observes relation in v2] (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md): pass 1 writes no `observes`
%   relation, and "its round trip defers the element's v1 `subject_id` to
%   the second pass". A probe-map row rebuilt from a wiring relation alone
%   (private/manifestProbemap, A ROW WITH NO STATEMENT) takes its
%   subjectstring from the element's subject, so where the batch does not
%   hold that subject the row is written with an empty subjectstring.
%
%   HOW IT COMPARES. Each REBUILTPM row whose subjectstring is empty names a
%   probe (name, reference, type, the columns NDI finds a probe's rows by,
%   ndi.probe.epochprobemapmatch). Every V1PM row of such a probe has its
%   subjectstring emptied, and the two maps are then compared by
%   private/sameProbemapSeveralRows ([probe in several rows is one wiring],
%   [probe map rows compared as a set]). TF is false when no rebuilt row has
%   an empty subjectstring (nothing is deferred), or when a V1PM row of such
%   a probe already had none. did2.convert.roundtrip.check counts the leaf
%   DEFERRED, not matched, when TF is true (spec.deferred `fn`).
%
%   See also did2.convert.roundtrip.epochfiles_ingested,
%            did2.convert.roundtrip.syncrule_mapping.

tf = false;
if ~(ischar(v1pm) || (isstring(v1pm) && isscalar(v1pm))) ...
        || ~(ischar(rebuiltPm) || (isstring(rebuiltPm) && isscalar(rebuiltPm)))
    return;
end
tab = sprintf('\t');
[h1, rows1] = splitRows(char(v1pm));
[~, rows2] = splitRows(char(rebuiltPm));
deferredKeys = {};
for k = 1:numel(rows2)
    c = columns(rows2{k});
    if isempty(c{5})
        deferredKeys{end+1} = strjoin(c(1:3), tab); %#ok<AGROW>
    end
end
if isempty(deferredKeys)
    return;
end
blanked = 0;
for k = 1:numel(rows1)
    c = columns(rows1{k});
    if any(strcmp(strjoin(c(1:3), tab), deferredKeys))
        if isempty(c{5})
            return;   % v1 states no subject here: nothing was deferred
        end
        c{5} = '';
        rows1{k} = strjoin(c(1:5), tab);
        blanked = blanked + 1;
    end
end
if blanked == 0
    return;
end
v1Blanked = strjoin([{h1}, rows1], newline);
if ~isempty(rows1)
    v1Blanked = [v1Blanked, newline];
end
tf = sameProbemapSeveralRows(v1Blanked, char(rebuiltPm));
end

function [header, rows] = splitRows(s)
lines = strsplit(s, newline, 'CollapseDelimiters', false);
lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
header = '';
rows = {};
if isempty(lines)
    return;
end
header = lines{1};
rows = lines(2:end);
end

function c = columns(line)
c = strsplit(line, sprintf('\t'), 'CollapseDelimiters', false);
c = cellfun(@strtrim, c, 'UniformOutput', false);
c(end+1:5) = {''};
end
