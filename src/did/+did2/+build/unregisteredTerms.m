function out = unregisteredTerms(cmd, arg1, arg2, arg3)
%UNREGISTEREDTERMS The terms did2.build was given that the term registry does not hold.
%
%   L = did2.build.unregisteredTerms() returns the terms recorded since the
%   last reset, one per distinct (name, node, field): a struct array with
%   name, node, field, reason and count. A term is recorded only while
%   collection is on.
%
%   PREV = did2.build.unregisteredTerms('-collect', TF) turns collection on
%   or off and returns the previous setting, so a caller can restore it.
%   TF = did2.build.unregisteredTerms('-collecting') reads the setting.
%   did2.build.unregisteredTerms('-reset') forgets what was recorded.
%
%   Collection is how one run lists EVERY unregistered term an import writes,
%   instead of stopping at the first: turn collection on and the error off
%   (did2.schema.cache.strictMode('TermRegistry', false)), run the import,
%   then read the list. With the switch on (the default) the first
%   unregistered term is an error, did2:build:unregisteredTerm.
%
%   DID-schema V_eta_term_registry_plan.md; tenet T19.
%
%   See also did2.schema.termRegistered, did2.schema.cache.strictMode.

arguments
    cmd {mustBeText} = ''
    arg1 = []        % '-collect': TF; '-add': the term
    arg2 = ''        % '-add': the field it was written to
    arg3 = ''        % '-add': why it is not registered
end

persistent rows collecting
if isempty(rows)
    rows = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
if isempty(collecting)
    collecting = false;
end
switch char(cmd)
    case ''
        v = values(rows);
        out = [v{:}];
        if isempty(out)
            out = struct('name', {}, 'node', {}, 'field', {}, 'reason', {}, 'count', {});
        end
    case '-collect'
        out = collecting;
        collecting = logical(arg1);
    case '-collecting'
        out = collecting;
    case '-reset'
        rows = containers.Map('KeyType', 'char', 'ValueType', 'any');
        out = [];
    case '-add'
        % used by did2.build's own field filling
        t = arg1;
        field = regexprep(char(arg2), '\(\d+\)', '[]');
        reason = char(arg3);
        key = sprintf('%s|%s|%s', t.name, t.node, field);
        if isKey(rows, key)
            r = rows(key);
            r.count = r.count + 1;
        else
            r = struct('name', t.name, 'node', t.node, 'field', field, ...
                'reason', reason, 'count', 1);
        end
        rows(key) = r;
        out = [];
    otherwise
        error('did2:build:badOption', ...
            'unregisteredTerms: unknown command "%s".', char(cmd));
end
end
