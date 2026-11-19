function rep = unregisteredTermsInFinal(docs, rows)
%UNREGISTEREDTERMSINFINAL How many of the unregistered terms a run wrote are in its final documents.
%
%   REP = did2.unittest.helpers.unregisteredTermsInFinal(DOCS, ROWS). ROWS is
%   did2.build.unregisteredTerms() after a run: every unregistered term
%   did2.build was GIVEN, with the field it was written to and how often.
%   That count is taken when a document is built, so it includes documents a
%   later batch pass drops or replaces (+migrators_j/element.m's `element
%   type` statement, which did2.convert.resolveEpochProbemap drops when the
%   probe's recordings rebuild the word: [recording mode terms]). This walks
%   DOCS, the run's FINAL documents (did2.document, struct or cell of
%   either), and counts, for each row, the final documents holding a term
%   with that name and node at that field.
%
%   A field is compared without its array positions ('term.value[]' and
%   'term.value' are one field), because a decoded document does not say
%   whether a one-element list was a list.
%
%   REP fields:
%     docs_walked    the final documents read (THE DENOMINATOR)
%     docs_unread    documents that could not be read as a struct
%     terms_read     {node, name} structs met in the walk
%     rows           ROWS with `final_docs` (final documents holding the
%                    term at the field) and `final_count` (occurrences)
%     rows_in_final  how many ROWS have final_docs > 0
%
%   REPORT ONLY; it asserts nothing.

arguments
    docs
    rows struct
end

want = containers.Map('KeyType', 'char', 'ValueType', 'double');
for r = 1:numel(rows)
    want(keyOf(rows(r).name, rows(r).node, rows(r).field)) = r;
end
finalDocs = zeros(1, numel(rows));
finalCount = zeros(1, numel(rows));

if isa(docs, 'did2.document')
    docs = num2cell(docs(:));
elseif isstruct(docs)
    docs = num2cell(docs(:));
end
rep = struct('docs_walked', 0, 'docs_unread', 0, 'terms_read', 0, ...
    'rows', rows, 'rows_in_final', 0);
for d = 1:numel(docs)
    s = docs{d};
    try
        if isa(s, 'did2.document')
            s = s.toStruct();
        end
    catch
        rep.docs_unread = rep.docs_unread + 1;
        continue;
    end
    if ~isstruct(s)
        rep.docs_unread = rep.docs_unread + 1;
        continue;
    end
    rep.docs_walked = rep.docs_walked + 1;
    hits = zeros(1, numel(rows));
    [hits, nTerms] = walk(s, '', hits, 0, want);
    rep.terms_read = rep.terms_read + nTerms;
    finalCount = finalCount + hits;
    finalDocs = finalDocs + (hits > 0);
end
for r = 1:numel(rows)
    rep.rows(r).final_docs = finalDocs(r);
    rep.rows(r).final_count = finalCount(r);
end
if isempty(rows)
    rep.rows = struct('name', {}, 'node', {}, 'field', {}, 'reason', {}, ...
        'count', {}, 'final_docs', {}, 'final_count', {});
end
rep.rows_in_final = nnz(finalDocs > 0);
end

function [hits, nTerms] = walk(x, path, hits, nTerms, want)
    if iscell(x)
        for c = 1:numel(x)
            [hits, nTerms] = walk(x{c}, path, hits, nTerms, want);
        end
        return;
    end
    if ~isstruct(x)
        return;
    end
    f = fieldnames(x);
    isTerm = any(strcmp(f, 'node')) && any(strcmp(f, 'name'));
    for e = 1:numel(x)
        if isTerm
            nm = x(e).name;
            nd = x(e).node;
            if (ischar(nm) || isstring(nm)) && (ischar(nd) || isstring(nd) || isempty(nd))
                nTerms = nTerms + 1;
                if isempty(nd); nd = ''; end
                k = keyOf(nm, nd, path);
                if isKey(want, k)
                    hits(want(k)) = hits(want(k)) + 1;
                end
            end
        end
        for j = 1:numel(f)
            v = x(e).(f{j});
            if isstruct(v) || iscell(v)
                if isempty(path)
                    p = f{j};
                else
                    p = [path '.' f{j}];
                end
                [hits, nTerms] = walk(v, p, hits, nTerms, want);
            end
        end
    end
end

function k = keyOf(name, node, field)
k = sprintf('%s|%s|%s', char(name), char(node), regexprep(char(field), '\[\]|\(\d+\)', ''));
end
