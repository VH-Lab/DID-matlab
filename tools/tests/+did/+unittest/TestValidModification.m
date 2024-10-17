classdef TestValidModification < did.unittest.abstract.TestModification
    % TestValidModification
    % Test case for making valid modification to documents
    
    properties (TestParameter)
        value_modifier = {'sham'},
        id_modifier = {...
            'sham'}
        dependency_modifier = {...
            'add dependency'}
        other_modifier = {...
            'invalid definition', ...
            'invalid property list name', ...
            'new class version number', ...
            'class version string', ....
            'invalid base name'}
        remover = {...
            'definition', ...
            'validation'}
    end

    methods
        function doVerification(testCase, b)
            testCase.verifyFalse(b)
        end
    end
end