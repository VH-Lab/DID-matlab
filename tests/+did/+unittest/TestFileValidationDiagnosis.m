classdef TestFileValidationDiagnosis < matlab.unittest.TestCase
    % WHICH FIELD a file-validation failure blames.
    %
    % validate_doc_vs_schema used to read files.file_info and files.file_list
    % in one try/catch, file_list last. Dot-indexing an empty file_info throws
    % -- [] is what a document that binds nothing carries -- so a file_list
    % that was sitting there, readable and correct, was never assigned, and the
    % catch replaced it with {}. checkfiles then reported every required name
    % as missing "from the file_list in document X": the one field that was
    % right, while the real absence was the bound file. See issue #199.
    %
    % These tests pin the diagnosis, not just the verdict. A document that is
    % genuinely invalid is still rejected -- see the fail-open PR #182 closed --
    % but it is rejected while naming the field that is actually at fault.

    properties (Constant)
        db_filename = 'filevalidationdiagnosisdb.sqlite'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function db = openDatabase(testCase)
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');
        end

        function doc = demoFileDoc(~, fileInfo, fileList)
            % A demoFile document whose files section is set by the caller.
            % demoFile declares filename1.ext and filename2.ext, both
            % mustbenotempty.
            doc = did.document('demoFile', 'demoFile.value', 1);
            props = doc.document_properties;
            props.files.file_info = fileInfo;
            if nargin > 2
                props.files.file_list = fileList;
            end
            doc = doc.setproperties('files', props.files);
        end

        function msg = validationError(testCase, doc)
            % Validate DOC, require that it is refused, and return the message.
            db = testCase.openDatabase();
            msg = '';
            try
                db.validate_docs(doc);
                testCase.verifyFail( ...
                    'validate_docs should have refused this document');
            catch ME
                testCase.verifyEqual(ME.identifier, 'DID:Database:ValidationFiles', ...
                    ['refused for the wrong reason: ' ME.message]);
                msg = ME.message;
            end
        end

        function verifyValidates(testCase, doc, why)
            db = testCase.openDatabase();
            try
                db.validate_docs(doc);
            catch ME
                testCase.verifyFail([why ': ' ME.message]);
            end
        end
    end

    methods (Test)

        function testEmptyFileInfoBlamesTheUnboundFileNotTheFileList(testCase)
            % The reported case. The file_list declares both names and is
            % correct; nothing is bound to them. file_info = [] is the shape a
            % document that has been read back as a struct carries, and it is
            % the one that used to throw.
            doc = testCase.demoFileDoc([]);

            msg = testCase.validationError(doc);

            testCase.verifySubstring(msg, 'filename1.ext', ...
                'the message must name the file that is not bound');
            testCase.verifySubstring(msg, 'file_info', ...
                'the message must name the field that is actually empty');
            testCase.verifyFalse(contains(msg, 'from the file_list'), ...
                ['the file_list declares the file and is correct, so the ' ...
                 'message must not send the reader there: ' msg]);
        end

        function testEmptyStructFileInfoIsTreatedTheSameWay(testCase)
            % A freshly constructed document carries file_info as a 0x0 struct
            % array (did.document/reset_file_info), where {s.name} yields {}
            % without throwing. Same condition as [] above -- nothing is bound
            % -- so the same answer, rather than one that depends on which
            % empty the caller happened to produce.
            doc = did.document('demoFile', 'demoFile.value', 1);
            fileInfo = doc.document_properties.files.file_info;
            testCase.assertTrue(isstruct(fileInfo), ...
                'precondition: a fresh document carries a struct file_info');
            testCase.assertEmpty(fileInfo, ...
                'precondition: with nothing bound it is empty');

            msg = testCase.validationError(doc);

            testCase.verifySubstring(msg, 'filename1.ext', ...
                'the message must name the file that is not bound');
            testCase.verifySubstring(msg, 'file_info', ...
                'the message must name the field that is actually empty');
            testCase.verifyFalse(contains(msg, 'from the file_list'), ...
                ['the file_list declares the file and is correct, so the ' ...
                 'message must not send the reader there: ' msg]);
        end

        function testNameMissingFromFileListNamesTheAbsentName(testCase)
            % A document whose file_list is genuinely incomplete: it holds
            % filename1.ext and not filename2.ext. The absent name is
            % filename2.ext, and that is what the message must say. Discarding
            % the file_list made every declared name look absent, so the old
            % code reported filename1.ext -- which was there.
            doc = testCase.demoFileDoc([], {'filename1.ext'});

            msg = testCase.validationError(doc);

            testCase.verifySubstring(msg, 'file_list', ...
                'a name absent from the file_list IS a file_list problem');
            testCase.verifySubstring(msg, 'filename2.ext', ...
                'the message must name the file that is absent from the list');
            testCase.verifyFalse(contains(msg, 'filename1.ext'), ...
                ['filename1.ext is in the file_list; only filename2.ext is ' ...
                 'absent from it: ' msg]);
        end

        function testDocumentWithNoFilesFieldStillValidates(testCase)
            % Most classes declare no files at all, and their documents have no
            % files section. That is what the try/catch was there for, and it
            % must keep working now that the read asks whether the field is
            % there instead of letting an error stand in for the answer.
            doc = did.document('demoA', 'demoA.value', 1);
            testCase.assertFalse(isfield(doc.document_properties, 'files'), ...
                'precondition: a demoA document has no files section');

            testCase.verifyValidates(doc, ...
                'a document with no files section must validate');
        end

        function testDeclaredOptionalFilesNeedNotBeBound(testCase)
            % demoSeries declares both of its files mustbenotempty = 0, and
            % this document binds neither. Its file_list is correct and nothing
            % it declares is required, so it is valid -- it was refused only
            % because the throw on an empty file_info discarded the file_list.
            doc = did.document('demoSeries', 'demoSeries.value', 1);
            props = doc.document_properties;
            props.files.file_info = [];
            doc = doc.setproperties('files', props.files);

            testCase.verifyValidates(doc, ...
                'a document whose declared files are all optional must validate');
        end

        function testBoundRequiredFilesValidate(testCase)
            % The other side of the tightening: a document that binds what its
            % schema requires still validates. Validation does no file I/O, so
            % the locations need not exist yet.
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', fullfile(pwd, 'one.ext'));
            doc = doc.add_file('filename2.ext', fullfile(pwd, 'two.ext'));

            testCase.verifyValidates(doc, ...
                'a document that binds both required files must validate');
        end

    end
end
