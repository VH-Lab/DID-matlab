function tests = testFileList
%TESTFILELIST Tests for did2.validate.fileList -- the #64 detector: do documents
%   carry the files their class declares?
%
%   WHY THE TESTS LOOK LIKE THIS. The instrument this one is modelled on
%   (silentLoss) shipped with no tests and measured NOTHING for two days, and its
%   zeros were read as a clean bill of health. So the first two tests here are not
%   about file lists at all -- they check that the detector can SEE its input, and
%   that an all-zero report cannot be produced by a broken scan. A detector that
%   cannot distinguish "nothing wrong" from "nothing read" is worse than none.

tests = functiontests(localfunctions);
end

% ===================== can it see its input? ===============================

function testTotalDocsCountsWhatWasHandedIn(testCase)
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2')};
rep = did2.validate.fileList(docs);
verifyEqual(testCase, rep.total_docs, 2, ...
    'the detector must count the documents it was handed');
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testUnreadableInputIsCountedNotSilentlyDropped(testCase)
rep = did2.validate.fileList({[]});
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 1, ...
    'an unreadable document must be counted, never discarded');
end

% ===================== the two directions ==================================

function testFileCarriedButNotDeclaredIsReported(testCase)
% A migrator that carries bytes the target class does not declare: the payload
% survives but nothing can find it, and the tombstone is wrong about the class.
b = bodyStruct('subject', 'sub_f1');       % `subject` declares no files
b.files = struct('file_list', {{'mystery.bin'}});
rep = did2.validate.fileList({did2.document(b)});
verifyEqual(testCase, rep.docs_with_files, 1);
verifyEqual(testCase, rep.present_undeclared_count, 1);
verifyEqual(testCase, rep.present_but_undeclared(1).file_name, 'mystery.bin');
verifyEqual(testCase, rep.present_but_undeclared(1).class_name, 'subject');
end

function testDeclaredFileMissingIsReported(testCase)
% The direction that LOSES DATA: the class says the bytes are there and the
% document has none. It validates today -- cache.m allows `files` as a top-level
% key and never looks inside -- so nothing else can see this.
%
% Uses a real V_eta class that declares a file, resolved from the schema rather
% than hardcoded, so the test cannot rot into asserting a class that changed.
cache = did2.schema.cache.shared();
[className, fileName] = aClassDeclaringAFile(cache);
assumeNotEmpty(testCase, className, ...
    'no V_eta class declares a file -- nothing to test against');
b = bodyStruct(className, 'doc_missing_file');
rep = did2.validate.fileList({did2.document(b)}, 'SchemaCache', cache);
verifyGreaterThanOrEqual(testCase, rep.declared_absent_count, 1);
names = {rep.declared_but_absent.file_name};
verifyTrue(testCase, any(strcmp(fileName, names)), ...
    sprintf('%s declares %s and the document has none -- it must be reported', ...
            className, fileName));
end

function testDeclaredAndCarriedIsSilent(testCase)
% The overwhelming majority: a class that declares nothing and carries nothing
% must produce NO rows. A report that lists every quiet document says nothing.
docs = {docObj('subject', 'sub_q1'), docObj('subject', 'sub_q2')};
rep = did2.validate.fileList(docs);
verifyEqual(testCase, rep.declared_absent_count, 0);
verifyEqual(testCase, rep.present_undeclared_count, 0);
verifyEqual(testCase, rep.docs_with_files, 0);
end

function testNeverRaisesOnMalformedInput(testCase)
% The audit must never be able to break a migration.
verifyWarningFree(testCase, @() did2.validate.fileList({[]}));
verifyWarningFree(testCase, @() did2.validate.fileList(struct([])));
end

% ===================== helpers =============================================

function [className, fileName] = aClassDeclaringAFile(cache)
%ACLASSDECLARINGAFILE First V_eta class whose own schema declares a file.
className = ''; fileName = '';
% The cache exposes no class listing, so probe a few V_eta classes that DO
% declare a payload file (21 of 243 do -- this read "17 of 228" until
% 2026-08-11; both numbers drifted, partly because image_stack was restored
% to the built set on 2026-08-10, so re-derive rather than copying it).
% Resolved through the cache rather than
% hardcoded here, so the test follows the schema instead of asserting a shape
% that may change.
names = {'sampled_body', 'opaque_body', 'data_body', ...
         'daqmetadatareader_epochdata_ingested', 'ngrid'};
for i = 1:numel(names)
    try
        c = cache.getClass(names{i});
    catch
        continue;
    end
    if isstruct(c) && isfield(c, 'file') && ~isempty(c.file)
        entry = c.file(1);
        if iscell(entry); entry = entry{1}; end
        if isstruct(entry) && isfield(entry, 'name')
            className = names{i}; fileName = char(entry.name); return;
        end
    end
end
end

function d = docObj(className, id)
d = did2.document(bodyStruct(className, id));
end

function b = bodyStruct(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end
