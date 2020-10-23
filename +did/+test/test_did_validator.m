function test_did_validator()
% TEST_NDI_DOCUMENT - Test the functionality of the NDI_VALIDATE object 
%
% TEST_NDI_DOCUMENT()
%
% Create a variety of mock ndi_document objects to test if the ndi_validate 
% can correctly detect ndi_document object with invalid types based on its 
% corresponding schema
%

    did.globals

    % validate classes that don't have depnds-on and have relatively few super-classes
    subject_doc = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
    validator = did.validate(subject_doc);
    assert(validator.is_valid == 1, 'fail');
    disp('good')

    subject_doc = subject_doc.setproperties('subject.description', 5);
    validator = did.validate(subject_doc);
    assert(validator.is_valid == 0, 'fail');

    try
        assert(validator.is_valid == 0, "fail");
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
    disp("")

    subject_doc = subject_doc.setproperties('did.base.document_version', 'not a number');
    validator = did.validate(subject_doc);
    assert(validator.is_valid == 0, 'fail');
    disp('good');

    try
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
    disp("")

    % validate more complicated classes that may contain depends-on and more
    % super-classes
    dirname = fileparts(which('did.test.test_did_validator'));
    try
        E = did.implementations.matlabdumbjsondb('LOAD', [dirname filesep '.test_database', filesep, 'test.db']);
    catch
        E = did.implementations.matlabdumbjsondb('NEW', [dirname filesep '.test_database', filesep, 'test.db']);
    end

    disp('Let us clear the database first before we proceed')
    E.clear('yes')
    subject_doc = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
    subject_base_id = subject_doc.document_properties.base.id;
    element_id = did.document('did_document_epochid', ...
                               'epochid', '12345a');
    element_base_id = element_id.document_properties.base.id;                    

    E.add(subject_doc);
    E.add(element_id);

    document_element = did.document('did_document_element');
    validator = did.validate(document_element, E);
    assert(validator.is_valid == 0, 'fail');
    try
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
    disp("")

    document_element = document_element.setproperties('depends_on(1).value', element_base_id);
    validator = did.validate(document_element, E);
    assert(validator.is_valid == 0, 'fail');
    try
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
    disp("")

    document_element = document_element.setproperties('depends_on(2).value', subject_base_id);
    validator = did.validate(document_element, E);
    assert(validator.is_valid == 1, 'fail');
    disp('good')

    %test format_validators
    animal_subject_good_doc = did.document('did_document_animalsubject', 'animalsubject.scientific_name', 'Aboma etheostoma', 'animalsubject.genbank_commonname', 'scaly goby');
    validator = did.validate(animal_subject_good_doc);
    assert(validator.is_valid == 1, "fail");
    disp('good')

    animal_subject_bad_doc_with_hint = did.document('did_document_animalsubject.json', 'animalsubject.scientific_name', 'scaly goby', 'animalsubject.genbank_commonname', 'Aboma etheostoma');
    errormsg = "";
    try
        validator = did.validate(animal_subject_bad_doc_with_hint);
        assert(validator.is_valid == 0, "fail");
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + newline +  errormsg)
    disp("")

    animal_subject_bad_doc = did.document('did_document_animalsubject', 'animalsubject.scientific_name', 'invalid_scientific_name', 'animalsubject.genbank_commonname', 'invalid_genbank_commonname');
    try
        validator = did.validate(animal_subject_bad_doc);
        assert(validator.is_valid == 0, "fail");
        validator.throw_error();
    catch e
        errormsg = e.message;
    end
    disp("good" + newline)
    disp("Here is the error message that is supposed to display" + newline + errormsg)
    disp("")
    disp('All test cases have passed.')

    disp('clearing the database')
    E.clear('yes')
end