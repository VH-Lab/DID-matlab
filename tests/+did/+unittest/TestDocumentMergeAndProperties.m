classdef TestDocumentMergeAndProperties < matlab.unittest.TestCase
    % did.document merging, property assignment and dependency lookup.
    %
    % These cover four behaviours ported from ndi.document, which had been
    % carrying a separate copy of this API since before it was a subclass and
    % had fixed things along the way that did.document had not:
    %
    %   plus                  merged depends_on by concatenation, so two
    %                         documents declaring the same dependency produced
    %                         a list with that name twice
    %   setproperties         assigned through eval on a caller-supplied
    %                         property name
    %   dependency_value_n    could not see a dependency recorded unnumbered
    %   set_dependency_value  threw on a document whose depends_on was
    %                         declared but empty
    %
    % None of it was tested here, which is why it survived.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function names = dependencyNames(~, doc)
            names = {doc.document_properties.depends_on.name};
        end
    end

    methods (Test)

        % ---- plus: dependency merging --------------------------------

        function testMergingSharedDependencyNamesDoesNotDuplicateThem(testCase)
            % demoC declares item1, item2 and item3. Adding two of them once
            % produced six entries with every name twice.
            docA = did.document('demoC');
            docB = did.document('demoC');
            merged = docA + docB;

            names = testCase.dependencyNames(merged);
            testCase.verifyNumElements(names, 3);
            testCase.verifyEqual(sort(names), {'item1','item2','item3'});
            testCase.verifyEqual(numel(unique(names)), numel(names), ...
                'depends_on should not carry the same name twice');
        end

        function testTheLeftDocumentWinsANameCollision(testCase)
            docA = did.document('demoC');
            docA = docA.set_dependency_value('item1', 'from_A');
            docB = did.document('demoC');
            docB = docB.set_dependency_value('item1', 'from_B');

            merged = docA + docB;
            testCase.verifyEqual(merged.dependency_value('item1'), 'from_A');
        end

        function testDisjointDependencyNamesAreAllKept(testCase)
            % did_document_element declares underlying_element_id and
            % subject_id; demoC declares item1..3. Nothing overlaps, so all
            % five survive.
            docA = did.document('did_document_element');
            docB = did.document('demoC');
            merged = docA + docB;

            names = testCase.dependencyNames(merged);
            testCase.verifyNumElements(names, 5);
            testCase.verifyTrue(all(ismember( ...
                {'underlying_element_id','subject_id','item1','item2','item3'}, names)));
        end

        function testMergingStillCombinesSuperclasses(testCase)
            % The dependency change should not have disturbed step 1.
            docA = did.document('demoC');
            docB = did.document('demoA');
            merged = docA + docB;
            testCase.verifyNotEmpty( ...
                merged.document_properties.document_class.superclasses);
        end

        % ---- setproperties: no eval ----------------------------------

        function testSetPropertiesAssignsANestedPath(testCase)
            doc = did.document('demoA');
            doc = doc.setproperties('demoA.value', 42);
            testCase.verifyEqual(doc.document_properties.demoA.value, 42);
        end

        function testSetPropertiesRejectsAPropertyNameThatIsNotOne(testCase)
            % The point of dropping eval: a property name is a name, not a
            % fragment of MATLAB to run. Anything that is not a valid field
            % path is refused rather than evaluated.
            doc = did.document('demoA');
            testCase.verifyError( ...
                @() doc.setproperties('demoA.value); disp(''x''); %', 1), ?MException);
            testCase.verifyError( ...
                @() doc.setproperties('demoA.(1)', 1), ?MException);
        end

        function testConstructorAssignsANestedPath(testCase)
            % The constructor used eval for the same job.
            doc = did.document('demoA', 'demoA.value', 7);
            testCase.verifyEqual(doc.document_properties.demoA.value, 7);
        end

        % ---- dependency_value_n: unnumbered fallback -----------------

        function testDependencyValueNFindsAnUnnumberedEntry(testCase)
            % demoC declares item1 plainly, not item1_1. Before the port,
            % dependency_value_n looked only for item1_1 and reported the
            % document had no such dependency.
            doc = did.document('demoC');
            doc = doc.set_dependency_value('item1', 'a_value');
            d = doc.dependency_value_n('item1');
            testCase.verifyEqual(d, {'a_value'});
        end

        function testAnUnsetUnnumberedEntryIsNotAMatch(testCase)
            % A blank definition carries the name with an empty value. That is
            % a placeholder, not an entry, so it must not count as found.
            doc = did.document('demoC');
            testCase.verifyError(@() doc.dependency_value_n('item1'), ?MException);
            testCase.verifyEmpty(doc.dependency_value_n('item1','ErrorIfNotFound',0));
        end

        function testNumberedEntriesStillWork(testCase)
            doc = did.document('demoC');
            doc = doc.add_dependency_value_n('extra', 'first');
            doc = doc.add_dependency_value_n('extra', 'second');
            testCase.verifyEqual(doc.dependency_value_n('extra'), {'first','second'});
        end

        % ---- set_dependency_value: empty depends_on ------------------

        function testSetDependencyValueOnAnEmptyDependsOnCreatesTheList(testCase)
            % "depends_on": [ ] in a definition decodes to an empty array,
            % which has no .name to index. This used to throw reaching for it
            % instead of creating the first entry.
            props = did.document('demoC').document_properties;
            props.depends_on = [];
            doc = did.document(props);

            doc = doc.set_dependency_value('item1', 'a_value', 'ErrorIfNotFound', 0);
            testCase.verifyEqual(doc.dependency_value('item1'), 'a_value');
        end

        function testDependencyValueNOnAnEmptyDependsOnIsNotFound(testCase)
            props = did.document('demoC').document_properties;
            props.depends_on = [];
            doc = did.document(props);
            testCase.verifyEmpty(doc.dependency_value_n('item1','ErrorIfNotFound',0));
        end

        function testDependencyValueOnAnEmptyDependsOnIsNotFound(testCase)
            % The same guard in the third reader. Without it this threw
            % "Attempt to reference field of non-structure array" rather than
            % answering that the dependency is not there.
            props = did.document('demoC').document_properties;
            props.depends_on = [];
            doc = did.document(props);
            testCase.verifyEmpty(doc.dependency_value('item1','ErrorIfNotFound',0));
            testCase.verifyError(@() doc.dependency_value('item1'), ?MException);
        end

    end
end
