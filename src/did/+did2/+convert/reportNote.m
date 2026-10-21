function out = reportNote(action, arg2, arg3, arg4)
%REPORTNOTE A note a per-document migrator leaves for the migration report.
%
%   A migrator returns documents, nothing else, so a fact about HOW it migrated
%   a document (not a failure: the document still migrates) has no other way to
%   reach the report. did2.convert.v1_to_v2 resets the notes at the start of a
%   batch, takes a mark before each source body and truncates back to it when
%   that body is quarantined (a quarantined body did not migrate, so its note
%   would count something that is not in the output), and collects the notes
%   into `summary.migration_notes` at the end.
%
%   did2.convert.reportNote(KIND, CLASSNAME, DOCID)   record one note
%   did2.convert.reportNote(KIND, CLASSNAME, DOCID, DETAIL)
%                                                     ... naming WHAT (a char)
%   did2.convert.reportNote('reset')                  forget all notes
%   N = did2.convert.reportNote('mark')               the number recorded so far
%   did2.convert.reportNote('truncate', N)            keep only the first N
%   S = did2.convert.reportNote('collect')            the notes, summarised:
%       S.<kind>.count       how many documents carry the note
%       S.<kind>.by_class    a struct, class name -> count
%       S.<kind>.ids         the source document ids, in order
%       S.<kind>.details     the DETAIL of each note, parallel to ids ('' if none)
%
%   KINDS IN USE:
%     route_unknown   a v1 treatment (treatment / treatment_drug) that names no
%                     location, so whether it was an immersion or a dose cannot
%                     be read from it; it migrates as a dose with a NaN amount
%                     (Jess Haley, 2026-10-21, did-schema
%                     V_eta_go_forward_class_audit.md).
%     dose_amount_conflict  a v1 treatment with two rows of one amount kind
%                     (two volumes, two masses, ...) that disagree: the dose
%                     keeps the first; DETAIL names the kind and both amounts
%                     (jDoseValue; Jess Haley, 2026-10-21, "a").
%     field_dropped   a v1 field a calculator fold (jCalculation, via
%                     jTuningCurve / jContrastSensitivityValue) has no home for
%                     on did-schema #88; DETAIL is its path in the source
%                     document ('<block>.<field>'). One note per field.

persistent notes
if isempty(notes)
    notes = struct('kind', {}, 'class_name', {}, 'id', {}, 'detail', {});
end
out = [];
switch action
    case 'reset'
        notes = struct('kind', {}, 'class_name', {}, 'id', {}, 'detail', {});
    case 'mark'
        out = numel(notes);
    case 'truncate'
        n = arg2;
        if n < numel(notes)
            notes = notes(1:n);
        end
    case 'collect'
        out = struct();
        for k = 1:numel(notes)
            f = matlab.lang.makeValidName(notes(k).kind);
            if ~isfield(out, f)
                out.(f) = struct('count', 0, 'by_class', struct(), 'ids', {{}}, ...
                    'details', {{}});
            end
            out.(f).count = out.(f).count + 1;
            c = matlab.lang.makeValidName(notes(k).class_name);
            if isfield(out.(f).by_class, c)
                out.(f).by_class.(c) = out.(f).by_class.(c) + 1;
            else
                out.(f).by_class.(c) = 1;
            end
            out.(f).ids{end+1} = notes(k).id;
            out.(f).details{end+1} = notes(k).detail;
        end
    otherwise
        % record: reportNote(KIND, CLASSNAME, DOCID)
        className = '';
        docId = '';
        if nargin >= 2; className = arg2; end
        if nargin >= 3; docId = arg3; end
        detail = '';
        if nargin >= 4; detail = arg4; end
        notes(end+1) = struct('kind', char(action), ...
            'class_name', char(className), 'id', char(docId), ...
            'detail', char(detail));
end
end
