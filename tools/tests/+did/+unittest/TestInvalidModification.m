classdef TestInvalidModification < matlab.unittest.TestCase
    % TestInvalidModification
    % Test case for catching invalid modification to documents
    
    methods (Test)
        function testValueModifierInt2Str(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'int2str');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierBlankInt(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'blank int');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierBlankStr(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'blank str');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierNaN(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'nan');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierDouble(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'double');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierTooNegative(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'too negative');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testValueModifierTooPositive(testCase)
            [b, msg] = did.test.db_documents_invalid('value_modifier', 'too positive');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testIdModifierSubstring(testCase)
            [b, msg] = did.test.db_documents_invalid('id_modifier', 'substring');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testIdModifierReplaceUnderscore(testCase)
            [b, msg] = did.test.db_documents_invalid('id_modifier', 'replace_underscore');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testIdModifierAdd(testCase)
            [b, msg] = did.test.db_documents_invalid('id_modifier', 'add');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testIdModifierReplaceLetterInvalid1(testCase)
            [b, msg] = did.test.db_documents_invalid('id_modifier', 'replace_letter_invalid1');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testIdModifierReplaceLetterInvalid2(testCase)
            [b, msg] = did.test.db_documents_invalid('id_modifier', 'replace_letter_invalid2');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testDependencyModifierInvalidId(testCase)
            [b, msg] = did.test.db_documents_invalid('dependency_modifier', 'invalid id');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testDependencyModifierInvalidName(testCase)
            [b, msg] = did.test.db_documents_invalid('dependency_modifier', 'invalid name');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testDependencyModifierAddDependency(testCase)
            [b, msg] = did.test.db_documents_invalid('dependency_modifier', 'add dependency');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidDefinition(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid definition');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierInvalidValidation(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid validation');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidClassName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid class name');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidPropertyListName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid property list name');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierNewClassVersionNumber(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'new class version number');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierClassVersionString(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'class version string');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierInvalidSuperclassDefinition(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid superclass definition');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidSessionId(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid session id');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidBaseName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid base name');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierInvalidDatestamp(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid datestamp');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testRemoverDocumentProperties(testCase)
            [b, msg] = did.test.db_documents_invalid('remover', 'document_properties');
            testCase.verifyEqual(b, 1, msg);
        end
        
        % Continue for the remaining tests, following the same structure
        
    end
end
