function varargout = tuningLabelNote(direction, varargin)
%TUNINGLABELNOTE The v1 display label of a tuning curve, kept in its notes.
%
%   NOTES = did2.convert.tuningLabelNote('write', LOG, LABEL)
%   [LOG, LABEL, HAS] = did2.convert.tuningLabelNote('read', NOTES)
%
%   [tuning axes named from the varied property] (Decided by Jess Haley,
%   2026-11-12, did-schema docs/plans/did_v2_go_forward_class_audit.md): a
%   migrated tuning curve's axis is named from its v1 `independent_parameter`
%   through the registered terms, not from `independent_variable_label`, and
%   "the label text is kept in notes". The curve's notes already hold its
%   `log`, verbatim ([tuning log in notes], 2026-10-27), so the label is ONE
%   LAST LINE after it:
%
%       v1 independent_variable_label: <the v1 value, JSON-encoded>
%
%   (alone when there is no log). LABEL is the v1 value as read (text, or a
%   cell of text), and jsonencode / jsondecode give it back as read.
%   'write' with an empty LABEL returns LOG unchanged. 'read' returns NOTES
%   unchanged as LOG, LABEL [] and HAS false when its last line is not such a
%   line. The migrator (jTuningCurve via jCalculation) writes it only when the
%   label is not already restated by the axis terms ([display label compared
%   loosely], 2026-11-10: case and '_' versus space aside); the round trip
%   (+roundtrip/private/rawCurveBlock.m, tuningInverse.m) reads it.

PREFIX = 'v1 independent_variable_label: ';
switch direction
    case 'write'
        logText = textOf(varargin{1});
        label = varargin{2};
        if isempty(label)
            varargout{1} = logText;
            return;
        end
        line = [PREFIX char(jsonencode(label))];
        if isempty(logText)
            varargout{1} = line;
        else
            varargout{1} = [logText newline line];
        end
    case 'read'
        notes = textOf(varargin{1});
        logText = notes;
        label = [];
        has = false;
        cut = find(notes == newline, 1, 'last');
        if isempty(cut)
            last = notes;
            before = '';
        else
            last = notes(cut + 1:end);
            before = notes(1:cut - 1);
        end
        if startsWith(last, PREFIX)
            try
                label = jsondecode(last(numel(PREFIX) + 1:end));
                has = true;
                logText = before;
            catch
                label = [];
            end
        end
        varargout = {logText, label, has};
    otherwise
        error('did2:convert:tuningLabelNote:direction', ...
            'direction must be ''write'' or ''read'', not ''%s''.', char(direction));
end
end

function t = textOf(x)
t = '';
if isstring(x) && isscalar(x); x = char(x); end
if ischar(x); t = x; end
end
