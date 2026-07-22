classdef TestDoc2sql < matlab.unittest.TestCase
    % TestDoc2sql
    % Regression for did.implementations.doc2sql superclass handling. The legacy
    % sql layer derived meta.superclass solely from `superclass.definition`
    % (the did1 "$DIDDOCUMENT/base.json" path form). did2-form documents carry
    % the superclass name directly in `.class_name` with no `.definition`, so
    % adding such a document errored ("Unrecognized field name definition").
    % doc2sql now falls back to `.class_name` (commit 8f982bc, applied as
    % written - definition preferred, class_name fallback, else empty).

    methods (Test)

        function testClassNameSuperclasses(testCase)
            % Superclasses given as class_name only (no definition) must
            % populate meta.superclass with the unique, comma-joined names.
            doc_props = struct();
            doc_props.base = struct( ...
                'id', '0123456789abcdef_fedcba9876543210', ...
                'datestamp', '2026-01-01T00:00:00.000Z');
            doc_props.document_class = struct( ...
                'class_name', 'myclass', ...
                'superclasses', struct('class_name', {'base', 'app'}));

            % doc2sql only needs a .document_properties accessor (its isa()
            % assert is disabled), so a plain struct stands in for the document.
            doc = struct('document_properties', doc_props);

            meta = did.implementations.doc2sql(doc);
            cols = meta(1).columns;
            idx = find(strcmp({cols.name}, 'superclass'), 1);
            testCase.verifyNotEmpty(idx, 'meta.superclass column must exist');
            testCase.verifyEqual(cols(idx).value, 'app, base', ...
                'class_name-only superclasses must populate meta.superclass');
        end

        function testDefinitionSuperclassesStillWork(testCase)
            % did1 definition-path superclasses must be unchanged (backward
            % compatible): the bare basename is still extracted.
            doc_props = struct();
            doc_props.base = struct( ...
                'id', '0123456789abcdef_fedcba9876543210', ...
                'datestamp', '2026-01-01T00:00:00.000Z');
            doc_props.document_class = struct( ...
                'class_name', 'myclass', ...
                'superclasses', struct('definition', ...
                    {'$DIDDOCUMENT/base.json', '$DIDDOCUMENT/app.json'}));

            doc = struct('document_properties', doc_props);

            meta = did.implementations.doc2sql(doc);
            cols = meta(1).columns;
            idx = find(strcmp({cols.name}, 'superclass'), 1);
            testCase.verifyEqual(cols(idx).value, 'app, base', ...
                'definition-path superclasses must still strip to bare names');
        end

    end
end
