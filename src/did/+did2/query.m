classdef query
    % did2.query  Query value + in-memory evaluator for V_delta documents.
    %
    %   did2.query implements the abstract query model documented in
    %   did-schema/schemas/did_query_model.md, evaluated directly against
    %   the V_delta class-scoped wire shape (see did2.document).
    %
    %   The query value is a tree of search structures combined by boolean
    %   composition. A search structure has four parts:
    %
    %       field      - dot-path selector inside the document. May carry
    %                    `[*]` segments to iterate array-of-structure
    %                    fields with existential semantics. `''` for
    %                    whole-document predicates such as `isa`.
    %       operation  - operator name. May be prefixed with `~` to
    %                    negate (all operators except `or`).
    %       param1     - first operator parameter.
    %       param2     - second operator parameter.
    %
    %   In memory: did2.query.searchstructure is a struct array; the array
    %   elements are AND-ed. OR is a single struct whose operation is `or`
    %   and whose param1 / param2 are sub-search-structure arrays.
    %
    %   Independent vs. correlated array predicates: per the model spec,
    %   two `[*]` predicates over the same array combined with `and()` do
    %   not necessarily refer to the same element. Each search structure
    %   resolves its `[*]` paths independently.
    %
    %   did2.query Properties:
    %       searchstructure - struct array of the four-tuple form above.
    %
    %   did2.query Methods:
    %       query    - construct a query (see usage below).
    %       and      - conjunction.
    %       or       - disjunction.
    %       matches  - logical scalar; does this query match one document?
    %       filter   - subset (or logical mask) over a list of documents.
    %
    %   did2.query Static Methods:
    %       all    - match every document (`isa base`).
    %       none   - match no document.
    %       searchstruct - build a single search structure.
    %       evaluate - low-level: evaluate a searchstructure against a struct.
    %       resolvePath - low-level: resolve a `[*]`-aware dot-path.
    %
    %   Usage:
    %       q = did2.query('base.id', 'exact_string', someId);
    %       q = did2.query('base.name', 'regexp', '^subject_');
    %       q = did2.query('', 'isa', 'demoA');
    %       q = did2.query('axes[*].unit', 'exact_string', 'micrometer');
    %       q = and(q1, q2);  q = or(q1, q2);
    %       tf = q.matches(doc);
    %       hits = q.filter(docList);
    %
    %   See also: did2.document, did2.schema.cache, did_query_model.md.

    properties (SetAccess = protected, GetAccess = public)
        searchstructure
    end

    methods
        function obj = query(field, op, param1, param2)
            % query - construct a did2.query.
            %
            %   q = did2.query()                       empty query (matches all).
            %   q = did2.query(searchstruct)           wrap a single struct.
            %   q = did2.query(field, op)              op with no params.
            %   q = did2.query(field, op, param1)
            %   q = did2.query(field, op, param1, param2)
            if nargin == 0
                obj.searchstructure = did2.query.emptySearchstruct();
                return;
            end
            if nargin == 1
                if isstruct(field)
                    did2.query.validateSearchstructFields(field);
                    obj.searchstructure = field;
                    return;
                elseif isempty(field)
                    obj.searchstructure = did2.query.emptySearchstruct();
                    return;
                else
                    error('did2:query:badInput', ...
                        'did2.query with one argument expects a search-struct or empty.');
                end
            end
            if nargin < 3, param1 = ''; end
            if nargin < 4, param2 = ''; end
            obj.searchstructure = did2.query.searchstruct(field, op, param1, param2);
        end

        function C = and(A, B)
            % and - conjunction of two queries.
            arguments
                A (1,1) did2.query
                B (1,1) did2.query
            end
            C = did2.query();
            C.searchstructure = [A.searchstructure(:); B.searchstructure(:)];
        end

        function C = or(A, B)
            % or - disjunction of two queries.
            arguments
                A (1,1) did2.query
                B (1,1) did2.query
            end
            C = did2.query();
            C.searchstructure = did2.query.searchstruct( ...
                '', 'or', A.searchstructure(:), B.searchstructure(:));
        end

        function tf = matches(obj, doc)
            % matches - evaluate this query against a single document.
            tf = did2.query.evaluateAll(obj.searchstructure, ...
                did2.query.docToStruct(doc));
        end

        function out = filter(obj, docs, opts)
            % filter - return the elements of docs that match.
            %
            %   hits = q.filter(docArray)
            %   hits = q.filter(docArray, AsMask=true) returns a logical mask.
            arguments
                obj
                docs
                opts.AsMask (1,1) logical = false
            end
            n = numel(docs);
            mask = false(1, n);
            for k = 1:n
                if iscell(docs)
                    d = docs{k};
                else
                    d = docs(k);
                end
                mask(k) = obj.matches(d);
            end
            if opts.AsMask
                out = mask;
                return;
            end
            out = docs(mask);
        end
    end

    methods (Static)
        function q = all()
            % all - match every document.
            q = did2.query('', 'isa', 'base', '');
        end

        function q = none()
            % none - match no document.
            q = did2.query('', 'isa', '__did2_no_such_class__', '');
        end

        function ss = searchstruct(field, operation, param1, param2)
            % searchstruct - build a single four-tuple search structure.
            arguments
                field char
                operation (1,:) char {did2.query.mustBeKnownOp}
                param1 = ''
                param2 = ''
            end
            ss = struct( ...
                'field', field, ...
                'operation', operation, ...
                'param1', {param1}, ...
                'param2', {param2});
        end

        function tf = evaluate(ss, docStruct)
            % evaluate - low-level evaluator over a single search struct
            %   or a search-struct array (AND-ed).
            tf = did2.query.evaluateAll(ss, docStruct);
        end

        function values = resolvePath(s, fieldPath)
            % resolvePath - return a cell array of leaf values at fieldPath.
            %
            %   `[*]` segments expand the value list existentially. An
            %   unresolvable path returns an empty cell array.
            arguments
                s
                fieldPath (1,:) char
            end
            values = did2.query.walkPath(s, fieldPath);
        end
    end

    % ---- private static helpers ----
    methods (Static, Access = private)
        function ss = emptySearchstruct()
            ss = struct('field', {}, 'operation', {}, 'param1', {}, 'param2', {});
        end

        function validateSearchstructFields(s)
            required = {'field', 'operation', 'param1', 'param2'};
            actual = sort(fieldnames(s));
            if ~isequal(sort(required(:)), actual(:))
                error('did2:query:badStruct', ...
                    'Search structure must have fields field/operation/param1/param2.');
            end
        end

        function s = docToStruct(doc)
            if isa(doc, 'did2.document')
                s = doc.toStruct();
            elseif isstruct(doc) && isscalar(doc)
                s = doc;
            else
                error('did2:query:badDoc', ...
                    'matches() expects a did2.document or scalar struct, got %s.', ...
                    class(doc));
            end
        end

        function tf = evaluateAll(searchArray, doc)
            % AND across the searchstructure array. An empty array matches.
            tf = true;
            if isempty(searchArray)
                return;
            end
            for k = 1:numel(searchArray)
                if ~did2.query.evaluateOne(searchArray(k), doc)
                    tf = false;
                    return;
                end
            end
        end

        function tf = evaluateOne(ss, doc)
            op = ss.operation;
            isNeg = ~isempty(op) && op(1) == '~';
            if isNeg
                op = op(2:end);
            end
            switch op
                case 'or'
                    if isNeg
                        error('did2:query:badOperator', ...
                            'The `or` operator cannot be negated; negate the leaves.');
                    end
                    tf = did2.query.evaluateAll(ss.param1, doc) ...
                        || did2.query.evaluateAll(ss.param2, doc);
                    return;
                case 'isa'
                    tf = did2.query.opIsa(doc, ss.param1);
                case 'depends_on'
                    tf = did2.query.opDependsOn(doc, ss.param1, ss.param2);
                case 'hasanysubfield_contains_string'
                    tf = did2.query.opHasAnySubfieldContains(doc, ss.field, ...
                        ss.param1, ss.param2);
                case 'hasanysubfield_exact_string'
                    tf = did2.query.opHasAnySubfieldExact(doc, ss.field, ...
                        ss.param1, ss.param2);
                case 'hasfield'
                    tf = ~isempty(did2.query.walkPath(doc, ss.field));
                case 'hasmember'
                    tf = did2.query.opHasMember(doc, ss.field, ss.param1);
                case {'exact_string', 'exact_string_anycase', ...
                      'contains_string', 'regexp', ...
                      'exact_number', 'lessthan', 'lessthaneq', ...
                      'greaterthan', 'greaterthaneq'}
                    tf = did2.query.opScalar(op, doc, ss.field, ss.param1);
                otherwise
                    error('did2:query:unknownOperator', ...
                        'Unknown operator "%s".', ss.operation);
            end
            if isNeg
                tf = ~tf;
            end
        end

        % ---- operator implementations ----

        function tf = opIsa(doc, className)
            className = char(className);
            tf = false;
            if ~isfield(doc, 'document_class') || ~isstruct(doc.document_class)
                return;
            end
            dc = doc.document_class;
            if isfield(dc, 'class_name') && did2.query.charEq(dc.class_name, className)
                tf = true;
                return;
            end
            if ~isfield(dc, 'superclasses') || isempty(dc.superclasses)
                return;
            end
            sc = dc.superclasses;
            n = numel(sc);
            for k = 1:n
                if isstruct(sc)
                    entry = sc(k);
                elseif iscell(sc)
                    entry = sc{k};
                else
                    continue;
                end
                if isstruct(entry) && isfield(entry, 'class_name') ...
                        && did2.query.charEq(entry.class_name, className)
                    tf = true;
                    return;
                end
            end
        end

        function tf = opDependsOn(doc, name, value)
            tf = false;
            if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
                return;
            end
            entries = doc.depends_on;
            name = char(name);
            value = char(value);
            for k = 1:numel(entries)
                if isstruct(entries)
                    e = entries(k);
                elseif iscell(entries)
                    e = entries{k};
                else
                    continue;
                end
                if ~isstruct(e)
                    continue;
                end
                gotName = isfield(e, 'name') && did2.query.charEq(e.name, name);
                if strcmp(name, '*')
                    gotName = true;
                end
                gotValue = isfield(e, 'value') && did2.query.charEq(e.value, value);
                if gotName && gotValue
                    tf = true;
                    return;
                end
            end
        end

        function tf = opHasMember(doc, fieldPath, target)
            values = did2.query.walkPath(doc, fieldPath);
            tf = false;
            for k = 1:numel(values)
                v = values{k};
                if isnumeric(target) && isnumeric(v)
                    if any(v(:) == target)
                        tf = true; return;
                    end
                elseif ischar(target) || (isstring(target) && isscalar(target))
                    t = char(target);
                    if ischar(v) && strcmp(v, t)
                        tf = true; return;
                    elseif isstring(v) && any(strcmp(string(v), string(t)))
                        tf = true; return;
                    elseif iscell(v)
                        for j = 1:numel(v)
                            if ischar(v{j}) && strcmp(v{j}, t)
                                tf = true; return;
                            end
                        end
                    end
                end
            end
        end

        function tf = opHasAnySubfieldContains(doc, fieldPath, subFieldName, needle)
            % field resolves to an array of structures; some element has
            % a sub-field `subFieldName` whose char value contains `needle`.
            subPath = sprintf('%s[*].%s', fieldPath, char(subFieldName));
            values = did2.query.walkPath(doc, subPath);
            tf = false;
            needle = char(needle);
            for k = 1:numel(values)
                v = values{k};
                if ischar(v) && ~isempty(strfind(v, needle)) %#ok<STREMP>
                    tf = true; return;
                elseif isstring(v) && contains(string(v), string(needle))
                    tf = true; return;
                end
            end
        end

        function tf = opHasAnySubfieldExact(doc, fieldPath, subFieldNames, targetValues)
            % Correlated existence check used by depends_on lowering: each
            % element of the array-of-structures at fieldPath must match
            % every (subFieldNames{i}, targetValues{i}) pair simultaneously.
            tf = false;
            if ~iscell(subFieldNames), subFieldNames = {subFieldNames}; end
            if ~iscell(targetValues), targetValues = {targetValues}; end
            if isempty(fieldPath)
                arr = [];
            else
                parts = strsplit(fieldPath, '.');
                arr = doc;
                ok = true;
                for k = 1:numel(parts)
                    if isstruct(arr) && isfield(arr, parts{k})
                        arr = arr.(parts{k});
                    else
                        ok = false; break;
                    end
                end
                if ~ok || isempty(arr)
                    return;
                end
            end
            for k = 1:numel(arr)
                if isstruct(arr)
                    e = arr(k);
                elseif iscell(arr)
                    e = arr{k};
                else
                    continue;
                end
                if ~isstruct(e)
                    continue;
                end
                allMatch = true;
                for j = 1:numel(subFieldNames)
                    sn = char(subFieldNames{j});
                    tv = char(targetValues{j});
                    if ~isfield(e, sn) || ~did2.query.charEq(e.(sn), tv)
                        allMatch = false; break;
                    end
                end
                if allMatch
                    tf = true; return;
                end
            end
        end

        function tf = opScalar(op, doc, fieldPath, param1)
            values = did2.query.walkPath(doc, fieldPath);
            tf = false;
            for k = 1:numel(values)
                if did2.query.applyScalarOp(op, values{k}, param1)
                    tf = true; return;
                end
            end
        end

        function tf = applyScalarOp(op, value, target)
            switch op
                case 'exact_string'
                    tf = did2.query.charEq(value, target);
                case 'exact_string_anycase'
                    tf = did2.query.charEq(value, target, true);
                case 'contains_string'
                    if ischar(value) && (ischar(target) || isstring(target))
                        tf = ~isempty(strfind(value, char(target))); %#ok<STREMP>
                    elseif isstring(value) && (ischar(target) || isstring(target))
                        tf = contains(string(value), string(target));
                    else
                        tf = false;
                    end
                case 'regexp'
                    if (ischar(value) || isstring(value)) ...
                            && (ischar(target) || isstring(target))
                        m = regexp(char(value), char(target), 'once');
                        tf = ~isempty(m);
                    else
                        tf = false;
                    end
                case 'exact_number'
                    if isnumeric(value) && isnumeric(target)
                        tf = isequal(size(value), size(target)) ...
                            && all(value(:) == target(:));
                    else
                        tf = false;
                    end
                case 'lessthan'
                    tf = isnumeric(value) && isnumeric(target) ...
                        && isequal(size(value), size(target)) ...
                        && all(value(:) < target(:));
                case 'lessthaneq'
                    tf = isnumeric(value) && isnumeric(target) ...
                        && isequal(size(value), size(target)) ...
                        && all(value(:) <= target(:));
                case 'greaterthan'
                    tf = isnumeric(value) && isnumeric(target) ...
                        && isequal(size(value), size(target)) ...
                        && all(value(:) > target(:));
                case 'greaterthaneq'
                    tf = isnumeric(value) && isnumeric(target) ...
                        && isequal(size(value), size(target)) ...
                        && all(value(:) >= target(:));
                otherwise
                    tf = false;
            end
        end

        % ---- path resolution ----

        function values = walkPath(s, fieldPath)
            % walkPath - return a cell array of leaf values at fieldPath.
            %   Supports `[*]` on any segment to expand array-of-structure
            %   iteration with existential semantics. Empty if the path is
            %   unresolvable.
            if isempty(fieldPath)
                values = {s};
                return;
            end
            parts = strsplit(fieldPath, '.');
            current = {s};
            for k = 1:numel(parts)
                segment = parts{k};
                isArr = endsWith(segment, '[*]');
                if isArr
                    segment = segment(1:end-3);
                end
                next = {};
                for c = 1:numel(current)
                    v = current{c};
                    if ~isstruct(v) || ~isscalar(v) || ~isfield(v, segment)
                        continue;
                    end
                    sub = v.(segment);
                    if isArr
                        if isstruct(sub)
                            for n = 1:numel(sub)
                                next{end+1} = sub(n); %#ok<AGROW>
                            end
                        elseif iscell(sub)
                            for n = 1:numel(sub)
                                next{end+1} = sub{n}; %#ok<AGROW>
                            end
                        end
                    else
                        next{end+1} = sub; %#ok<AGROW>
                    end
                end
                current = next;
                if isempty(current)
                    values = {};
                    return;
                end
            end
            values = current;
        end

        function tf = charEq(a, b, ignoreCase)
            % charEq - compare two char/string scalars for equality.
            if nargin < 3, ignoreCase = false; end
            if ischar(a) && isempty(a), a = ''; end
            if ischar(b) && isempty(b), b = ''; end
            if (ischar(a) || isstring(a)) && (ischar(b) || isstring(b))
                if ignoreCase
                    tf = strcmpi(char(a), char(b));
                else
                    tf = strcmp(char(a), char(b));
                end
            else
                tf = false;
            end
        end

        function mustBeKnownOp(op)
            allowed = {'or', 'isa', 'depends_on', ...
                'hasfield', 'hasmember', ...
                'hasanysubfield_contains_string', ...
                'hasanysubfield_exact_string', ...
                'exact_string', 'exact_string_anycase', 'contains_string', ...
                'regexp', 'exact_number', ...
                'lessthan', 'lessthaneq', 'greaterthan', 'greaterthaneq'};
            negAllowed = cellfun(@(x) ['~', x], allowed, 'UniformOutput', false);
            negAllowed(strcmp(allowed, 'or')) = []; % no ~or
            opChar = char(op);
            if ~any(strcmp(opChar, allowed)) && ~any(strcmp(opChar, negAllowed))
                error('did2:query:badOperator', ...
                    'Unknown operator "%s".', opChar);
            end
        end
    end
end
