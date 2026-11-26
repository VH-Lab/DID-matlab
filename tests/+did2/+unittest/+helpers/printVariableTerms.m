function rep = printVariableTerms(corpusName, finalDocs)
%PRINTVARIABLETERMS Print the variable-term census of a corpus run's final documents.
%
%   REP = did2.unittest.helpers.printVariableTerms(CORPUSNAME, FINALDOCS)
%   prints one line, then the distinct offenders, if any:
%
%     --- VARIABLE TERMS IN FINAL DOCUMENTS (<corpus>): <docs> document(s),
%         <n> variable(s); empty node <a>; unregistered <b> ---
%
%   counting every statement.variable and method.parameters[].variable
%   (did2.unittest.helpers.variableTermsInFinal has the paths and the rules:
%   `unregistered` is a non-empty node the term registry does not hold, and is
%   disjoint from `empty node`). It is the measurement did-schema #89 /
%   [variable terms registered before required] waits on: a corpus's variable
%   bindings switch to required once it reads 0 unregistered.
%
%   AN INSTRUMENT, NOT A GATE: it never throws and asserts nothing. When it
%   read nothing -- no document walked, no variable read, no term registry in
%   the schema, or the walk threw -- it prints NOT MEASURED and the reason,
%   never 0. REP is the variableTermsInFinal report, or [] when the walk threw.

arguments
    corpusName (1,:) char
    finalDocs
end

rep = [];
try
    rep = did2.unittest.helpers.variableTermsInFinal(finalDocs);
catch err
    fprintf('\n--- VARIABLE TERMS IN FINAL DOCUMENTS (%s): NOT MEASURED (%s) ---\n', ...
        corpusName, err.message);
    return;
end
try
    if rep.docs_walked == 0
        fprintf(['\n--- VARIABLE TERMS IN FINAL DOCUMENTS (%s): NOT MEASURED ' ...
            '(0 final documents walked, %d unreadable) ---\n'], corpusName, rep.docs_unread);
        return;
    end
    if rep.variables_read == 0
        fprintf(['\n--- VARIABLE TERMS IN FINAL DOCUMENTS (%s): NOT MEASURED ' ...
            '(%d document(s) walked, 0 variables read) ---\n'], corpusName, rep.docs_walked);
        return;
    end
    if rep.registry_present
        unreg = sprintf('%d', rep.unregistered);
    else
        unreg = 'NOT MEASURED (the schema in use has no term registry)';
    end
    fprintf(['\n--- VARIABLE TERMS IN FINAL DOCUMENTS (%s): %d document(s), %d variable(s); ' ...
        'empty node %d; unregistered %s ---\n'], corpusName, rep.docs_walked, ...
        rep.variables_read, rep.empty_node, unreg);
    if rep.docs_unread > 0
        fprintf('  (%d further document(s) could not be read and are not in the count)\n', ...
            rep.docs_unread);
    end
    if isempty(rep.offenders); return; end
    [~, order] = sort([rep.offenders.count], 'descend');
    fprintf('  %7s  %-12s  %-40s %s\n', 'count', 'kind', 'name', 'node');
    for k = order
        o = rep.offenders(k);
        fprintf('  %7d  %-12s  %-40s %s\n', o.count, o.kind, ['"' o.name '"'], o.node);
    end
catch err
    fprintf('\n--- VARIABLE TERMS IN FINAL DOCUMENTS (%s): NOT MEASURED (printing failed: %s) ---\n', ...
        corpusName, err.message);
end
end
