function printUnregisteredTerms(corpusName, finalDocs)
%PRINTUNREGISTEREDTERMS Print the T19 unregistered-term census of a corpus run.
%
%   did2.unittest.helpers.printUnregisteredTerms(CORPUSNAME, FINALDOCS) prints
%   two blocks, after a run that collected with
%       did2.build.unregisteredTerms('-reset');
%       prev = did2.build.unregisteredTerms('-collect', true);
%   around the migration and its batch passes:
%     --- UNREGISTERED TERMS (<corpus>): ... ---         what did2.build was given
%     --- UNREGISTERED TERMS IN FINAL DOCUMENTS (<corpus>): ... ---
%                                                        those rows in FINALDOCS
%   Moved here from runCorpusDiscovery's local functions so testCorpusPRED,
%   which runs v1_to_v2 and the passes itself, prints the same lines. The text
%   is unchanged. REPORT ONLY.

arguments
    corpusName (1,:) char
    finalDocs
end

printBuilt(corpusName);
printInFinal(corpusName, finalDocs);
end

function printBuilt(corpusName)
% Every term a migrator or pass wrote that the did-schema term registry does
% not hold (tenet T19), with the field it was written to and how often.
rows = did2.build.unregisteredTerms();
fprintf('\n--- UNREGISTERED TERMS (%s): %d distinct (term, field) row(s) ---\n', ...
    corpusName, numel(rows));
if isempty(rows); return; end
[~, order] = sort([rows.count], 'descend');
for k = order
    fprintf('  %7d  %-40s %-18s %s\n', rows(k).count, ...
        ['"' rows(k).name '"'], rows(k).node, rows(k).field);
end
end

function printInFinal(corpusName, finalDocs)
% The same rows, counted in the FINAL documents. The list above is what
% did2.build was given, when each document was built, so it counts documents a
% batch pass later drops (the `element type` statements resolveEpochProbemap
% drops for recorded probes, [recording mode terms]). This says which of them a
% final document still holds. REPORT ONLY; best-effort, and a failure is
% printed as NOT MEASURED, never as 0.
rows = did2.build.unregisteredTerms();
try
    rep = did2.unittest.helpers.unregisteredTermsInFinal(finalDocs, rows);
catch err
    fprintf('--- UNREGISTERED TERMS IN FINAL DOCUMENTS (%s): NOT MEASURED (%s) ---\n', ...
        corpusName, err.message);
    return;
end
fprintf(['--- UNREGISTERED TERMS IN FINAL DOCUMENTS (%s): %d final document(s) walked ' ...
    '(%d unreadable), %d term(s) read; %d of %d row(s) above are in a final document ---\n'], ...
    corpusName, rep.docs_walked, rep.docs_unread, rep.terms_read, rep.rows_in_final, numel(rows));
if isempty(rep.rows); return; end
[~, order] = sort([rep.rows.count], 'descend');
fprintf('  %7s %7s %7s  %-40s %-18s %s\n', 'built', 'final', 'f.docs', 'name', 'node', 'field');
for k = order
    r = rep.rows(k);
    fprintf('  %7d %7d %7d  %-40s %-18s %s\n', r.count, r.final_count, r.final_docs, ...
        ['"' r.name '"'], r.node, r.field);
end
end
