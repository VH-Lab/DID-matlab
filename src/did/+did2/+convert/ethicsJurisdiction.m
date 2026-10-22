function [term, note] = ethicsJurisdiction(value)
%ETHICSJURISDICTION A v1 / openMINDS ethics assessment as the ethics jurisdiction.
%
%   [TERM, NOTE] = did2.convert.ethicsJurisdiction(VALUE). Jess Haley
%   2026-10-22 [ethics assessment to jurisdiction] (S3b, "agreed, b"): the
%   obsolete EMPTY:0000355 ethics assessment is no longer written; a v1
%   EthicsAssessment value becomes the ethics jurisdiction (EMPTY:0000359)
%   term:
%     "EU compliant", "EU compliant +"  -> wikidata:Q458 European Union; the
%                     "+" is kept as NOTE: an additional ethics assessment was
%                     made by the data-sharing initiative
%     "US compliant"  -> wikidata:Q30 United States
%     "not required", and any other value -> TERM [] (no statement); NOTE
%                     names the value, for the caller to count
%   VALUE is text, or a term ({node, name}) whose name or openMINDS v4 IRI
%   (.../ethicsAssessment/EUCompliant, EUCompliant+, USCompliant,
%   notRequired) is read. Case, spaces and hyphens are ignored. The term's
%   name is the registry's label for its node (did2.convert.registeredTerm).
%
%   See also did2.convert.registeredTerm.

term = [];
note = '';
raw = '';
if isstruct(value) && isscalar(value)
    for f = {'name', 'node'}
        if isfield(value, f{1}) && ~isempty(strtrim(char(value.(f{1}))))
            raw = char(value.(f{1}));
            break;
        end
    end
elseif ischar(value) || (isstring(value) && isscalar(value))
    raw = char(value);
end
key = lower(regexprep(raw, '[\s\-_]', ''));
slash = find(key == '/', 1, 'last');
if ~isempty(slash); key = key(slash+1:end); end   % an openMINDS IRI
switch key
    case 'eucompliant'
        term = did2.convert.registeredTerm('wikidata:Q458', 'European Union');
    case 'eucompliant+'
        term = did2.convert.registeredTerm('wikidata:Q458', 'European Union');
        note = ['v1 EthicsAssessment "EU compliant +": an additional ethics ' ...
            'assessment was made by the data-sharing initiative.'];
    case 'uscompliant'
        term = did2.convert.registeredTerm('wikidata:Q30', 'United States');
    otherwise
        note = raw;
end
end
