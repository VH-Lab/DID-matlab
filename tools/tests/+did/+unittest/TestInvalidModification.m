classdef TestInvalidModification < did.unittest.abstract.TestModification
    % TestInvalidModification
    % Test case for catching invalid modification to documents

    properties (TestParameter)
        value_modifier = {...
            'int2str', ...
            'blank int', ...
            'blank str', ...
            'nan', ...
            'too negative', ...
            'too positive'}
        id_modifier = {...
            'substring', ...
            'replace_underscore', ...
            'add', ...
            'replace_letter_invalid1', ...
            'replace_letter_invalid2'}
        dependency_modifier = {...
            'invalid id', ...
            'invalid name'}
        other_modifier = {...
            'invalid validation', ...
            'invalid class name', ...
            'invalid superclass definition', ...
            'invalid session id', ...
            'invalid datestamp'}
        remover = {...
            'document_properties', ...
            'base', ...
            'session_id', ...
            'id', ...
            'name', ...
            'datestamp', ...
            'demoA', ...
            'demoB', ...
            'demoC', ...
            'depends_on.name', ...
            'depends_on.value', ...
            'item1', ...
            'item2', ...
            'item3', ...
            'value', ...
            'document_class', ...
            'class_name', ...
            'property_list_name', ...
            'class_version', ...
            'superclasses', ...
            'superclasses.definition'}
    end

    methods
        function doVerification(testCase, b)
            testCase.verifyTrue(b)
        end
    end
end
