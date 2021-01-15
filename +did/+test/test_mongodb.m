function test_mongodb(dbname)
	%Test the functionality of mongodb implementation of the database objec
	%
	%TEST_MONGODB(DB, COLLECTION)
	%
	%the name of the db where we want to perform the testing on
	db = did.implementations.mongodb(dbname, 'test_mongodb_mock')
	disp(['creating a mock collection on db: ', dbname, ' and collection: test_mongodb_mock'])
	doc1 = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
	doc2 = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
	doc2id = subject_doc.document_properties.base.id;
	doc3 = did.document('did_document_epochid', ...
                               'epochid', '12345a');
	doc3id = element_id.document_properties.base.id;  
	doc4 = did.document('did_document_element');
	doc4 = doc4.setproperties('depends_on(1).value', element_base_id);
	doc4 = doc4.setproperties('depends_on(2).value', subject_base_id);
	doc5 = did.document('did_document_animalsubject', ...
						'animalsubject.scientific_name', ...
						'Aboma etheostoma', ...
						'animalsubject.genbank_commonname', ...
						 'scaly goby');
	disp('adding the documents into the database')
	db.add(doc1)
	db.add(doc2)
	db.add(doc3)
	db.add(doc4)
	db.add(doc5)

	
