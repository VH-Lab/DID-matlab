function test_mongodb(dbname)
	%Test the functionality of mongodb implementation of the database objec
	%
	%TEST_MONGODB(DB, COLLECTION)
	%
	%the name of the db where we want to perform the testing on
	try
		db = did.implementations.mongodb(dbname, 'test_mongodb_mock', 'load');
		disp('Clearing the mock database');
		db.clear('yes');
	catch
		db = did.implementations.mongodb(dbname, 'test_mongodb_mock', 'new');
	end
	disp(['creating a mock collection on db: ', dbname, ' and collection: test_mongodb_mock'])
	doc1 = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
	doc1id = doc1.document_properties.base.id;
	doc2 = did.document('did_document_subject', ...
                                'subject.local_identifier', 'sample_subject@brandeis.edu',...
                                'subject.description', '');
	doc2id = doc2.document_properties.base.id;
	doc3 = did.document('did_document_epochid', ...
                               'epochid', '12345a');
	doc3id = doc3.document_properties.base.id;  
	doc4 = did.document('did_document_element');
	doc4 = doc4.setproperties('depends_on(1).value', doc2id);
	doc4 = doc4.setproperties('depends_on(2).value', doc3id);
	doc4id = doc4.document_properties.base.id;
	doc5 = did.document('did_document_animalsubject', ...
						'animalsubject.scientific_name', ...
						'Aboma etheostoma', ...
						'animalsubject.genbank_commonname', ...
						 'scaly goby');
	doc5id = doc5.document_properties.base.id;
	doc6 = did.document('did_document_app','app.name','mytestname','base.name','mytestdocument');
	doc6id = doc6.document_properties.base.id;
	disp('adding the documents into the database');
	db.add(doc1);
	db.add(doc2);
	db.add(doc3);
	db.add(doc4);
	db.add(doc5);
	db.add(doc6);
	ids = {doc1id, doc2id, doc3id, doc4id, doc5id, doc6id};

	%Test that the document has been successfully added
	docids = db.alldocids();
	disp('Test with adding documents')
	if numel(docids) == 1
		ids = {docids}
	end
	for i = 1:numel(docids)
		assert(string(docids{i}) == string(ids{i}), "document_id that have been added fails to match");
		disp('good')
	end

	disp('Test with search (isa)')
	doc = db.search(did.query('','isa','did_document_app.json',''));
	assert(numel(doc)==1, ['Found <1 or >1 document with base.name ''mytestdocument''; this means there is a database problem.'])
	disp('good')
	doc = db.search(did.query('','isa','did_document_app.json',''));
	assert(numel(doc)==1, ['Found <1 or >1 document with base.name ''mytestdocument''; this means there is a database problem.'])
	disp('good')

	doc = db.search(did.query('','isa','did_document_subject',''));	
	assert(numel(doc)==2, ['Found <2 or >2 documents of did_document_subject; this means there is a database problem.'])
	disp('good')

	doc = db.search(did.query('','isa','did_document_epochid',''));	
	assert(numel(doc)==1, ['Found <1 or >1 documents of did_document_epochid; this means there is a database problem.'])
	disp('good')

	doc = db.search(did.query('','isa','did_document_epochid',''));	
	assert(numel(doc)==1, ['Found <1 or >1 documents of did_document_epochid; this means there is a database problem.'])
	disp('good')	

	disp('Test with search (depends_on)')
	doc = db.search(did.query('','depends_on','underlying_element_id',doc2id));
	assert(numel(doc)==1, ['Found <1 or >1 document whose superclass is base; this means there is a database problem.'])
	disp('good')

	doc = db.search(did.query('','depends_on','subject_id',doc3id));
	assert(numel(doc)==1, ['Found <1 or >1 document whose superclass is base; this means there is a database problem.'])
	disp('good')
end

	
