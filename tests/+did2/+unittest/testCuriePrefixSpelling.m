function tests = testCuriePrefixSpelling
%TESTCURIEPREFIXSPELLING A CURIE's prefix is written the way its issuer cites
%   it, and read by key, spelling or synonym, ignoring case.
%
%   DID-schema V_eta_prefix_spelling_plan.md, TEAM-SIGN-OFF [prefix spelling],
%   2026-10-19: "a CURIE's prefix is written as its issuer cites it (the
%   registry entry's spelling: ORCID:, ROR:, PMID:, PMCID:, RRID:, doi:,
%   WormBase:, EDAM:format_), for identifiers and term nodes alike; readers
%   match a prefix by key, spelling or synonym, ignoring case; registry keys
%   stay the lowercase Bioregistry prefixes."
%
%   Covers did2.schema.curiePrefixIndex, did2.schema.curieKey and
%   did2.schema.curieSpelling over a registry written here in the V_eta
%   shape, decoded with jsondecode as the schema cache decodes the real one
%   (so a key like `pubchem.compound` arrives as `pubchem_compound`).
%
%   NOT YET RUN: written where there is no MATLAB.
%
%   Run with:
%       results = runtests('did2.unittest.testCuriePrefixSpelling');

tests = functiontests(localfunctions);
end

% ===================== fixtures ============================================

function setupOnce(testCase)
testCase.TestData.index = did2.schema.curiePrefixIndex(jsondecode(registryJSON()));
end

% ===================== the index ===========================================

function testTheIndexKnowsKeysSpellingsAndSynonyms(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, ix.names('pubmed'), 'pubmed');
verifyEqual(testCase, ix.names('pmid'), 'pubmed');
verifyEqual(testCase, ix.names('medline'), 'pubmed');
verifyEqual(testCase, ix.names('ncbit'), 'ncbitaxon');
verifyEqual(testCase, ix.spelling('pubmed'), 'PMID');
verifyEqual(testCase, ix.spelling('pubchem_compound'), 'PubChem');
% a written_as entry's spelling names the entry it is written as
verifyEqual(testCase, ix.names('rrid'), 'rrid');
verifyTrue(testCase, isKey(ix.writtenAs, 'cellosaurus'));
verifyTrue(testCase, isKey(ix.legacy, 'wbstrain'));
end

function testARegistryWithNoSpellingsStillMatchesIgnoringCase(testCase)
% V_delta's registry carries `_prefixes` (jsondecode: `x_prefixes`), and
% V_zeta's entries have no `spelling`. Neither may make a reader stricter.
ix = did2.schema.curiePrefixIndex(jsondecode( ...
    '{"_prefixes": {"uberon": {"_uri_base": "x"}}}'));
verifyEqual(testCase, did2.schema.curieKey('UBERON:0000955', ix), 'uberon:0000955');
verifyEqual(testCase, did2.schema.curieSpelling('UBERON:0000955', ix), 'UBERON:0000955');
ix = did2.schema.curiePrefixIndex(jsondecode( ...
    '{"prefixes": {"uberon": {"uri_base": "x"}}}'));
verifyEqual(testCase, did2.schema.curieKey('UBERON:0000955', ix), 'uberon:0000955');
verifyEqual(testCase, did2.schema.curieSpelling('uberon:0000955', ix), 'uberon:0000955');
end

% ===================== reading: curieKey ===================================

function testAPrefixIsReadByKeySpellingOrSynonymIgnoringCase(testCase)
ix = testCase.TestData.index;
for c = {'PMID:123', 'pmid:123', 'pubmed:123', 'PubMed:123', 'MEDLINE:123'}
    verifyEqual(testCase, did2.schema.curieKey(c{1}, ix), 'pubmed:123', c{1});
end
for c = {'NCIT:C175887', 'ncit:C175887', 'NCIt:C175887'}
    verifyEqual(testCase, did2.schema.curieKey(c{1}, ix), 'ncit:C175887', c{1});
end
verifyEqual(testCase, did2.schema.curieKey('NCBIT:6239', ix), 'ncbitaxon:6239');
verifyEqual(testCase, did2.schema.curieKey('pubchem.compound:2244', ix), ...
    'pubchem_compound:2244');
verifyEqual(testCase, did2.schema.curieKey('PubChem:2244', ix), 'pubchem_compound:2244');
end

function testTheLocalIdKeepsItsCase(testCase)
ix = testCase.TestData.index;
verifyNotEqual(testCase, did2.schema.curieKey('NCIT:C175887', ix), ...
    did2.schema.curieKey('NCIT:c175887', ix));
end

function testAnOldPrefixIsReadByRewrite(testCase)
% plan sec. 3a (ii): `WBStrain:<digits>` is `WormBase:WBStrain<digits>`, and
% EDAM's `format:1929` is `EDAM:format_1929` (Q5).
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieKey('WBStrain:00004246', ix), ...
    did2.schema.curieKey('WormBase:WBStrain00004246', ix));
verifyEqual(testCase, did2.schema.curieKey('wormbase:WBStrain00004246', ix), ...
    'wormbase:WBStrain00004246');
verifyEqual(testCase, did2.schema.curieKey('format:1929', ix), ...
    did2.schema.curieKey('EDAM:format_1929', ix));
end

function testCellosaurusAndAddgeneAreReadAsRRIDs(testCase)
% Q3: a Cellosaurus line is cited `RRID:CVCL_0030`, an Addgene plasmid
% `RRID:Addgene_12345`.
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieKey('cellosaurus:0030', ix), 'rrid:CVCL_0030');
verifyEqual(testCase, did2.schema.curieKey('RRID:CVCL_0030', ix), 'rrid:CVCL_0030');
verifyEqual(testCase, did2.schema.curieKey('addgene:12345', ix), 'rrid:Addgene_12345');
end

function testAnUnknownPrefixIsComparedIgnoringCase(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieKey('ZZZ:1', ix), 'zzz:1');
verifyEqual(testCase, did2.schema.curieKey('zzz:1', ix), 'zzz:1');
end

function testTextThatIsNotACurieIsReturnedAsIs(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieKey('  brain region ', ix), 'brain region');
verifyEqual(testCase, did2.schema.curieKey('', ix), '');
end

% ===================== writing: curieSpelling ==============================

function testAWriterEmitsTheSpelling(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieSpelling('pubmed:123', ix), 'PMID:123');
verifyEqual(testCase, did2.schema.curieSpelling('pmc:PMC1', ix), 'PMCID:PMC1');
verifyEqual(testCase, did2.schema.curieSpelling('orcid:0000-0002-1825-0097', ix), ...
    'ORCID:0000-0002-1825-0097');
verifyEqual(testCase, did2.schema.curieSpelling('ror:05qwgg493', ix), 'ROR:05qwgg493');
verifyEqual(testCase, did2.schema.curieSpelling('DOI:10.1234/abc', ix), 'doi:10.1234/abc');
verifyEqual(testCase, did2.schema.curieSpelling('rrid:WB-STRAIN:WBStrain00004246', ix), ...
    'RRID:WB-STRAIN:WBStrain00004246');
verifyEqual(testCase, did2.schema.curieSpelling('ncbitaxon:6239', ix), 'NCBITaxon:6239');
verifyEqual(testCase, did2.schema.curieSpelling('NCBIT:6239', ix), 'NCBITaxon:6239');
end

function testAWriterRewritesTheOldForms(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieSpelling('WBStrain:00004246', ix), ...
    'WormBase:WBStrain00004246');
verifyEqual(testCase, did2.schema.curieSpelling('wormbase:WBStrain00004246', ix), ...
    'WormBase:WBStrain00004246');
verifyEqual(testCase, did2.schema.curieSpelling('format:1929', ix), 'EDAM:format_1929');
verifyEqual(testCase, did2.schema.curieSpelling('cellosaurus:0030', ix), 'RRID:CVCL_0030');
verifyEqual(testCase, did2.schema.curieSpelling('addgene:12345', ix), 'RRID:Addgene_12345');
end

function testAWriterDoesNotInventASpelling(testCase)
ix = testCase.TestData.index;
verifyEqual(testCase, did2.schema.curieSpelling('ZZZ:1', ix), 'ZZZ:1');
verifyEqual(testCase, did2.schema.curieSpelling('zzz:1', ix), 'zzz:1');
end

% ===================== helpers =============================================

function s = registryJSON()
% A cut of DID-schema's V_eta CURIE_lookups_meta.json, in its shape.
s = ['{"prefixes": {' ...
     '"pubmed": {"spelling": "PMID", "synonyms": ["MEDLINE", "PMID", "PubMed", "PubMed ID", "pmid"]},' ...
     '"pmc": {"spelling": "PMCID", "synonyms": ["PMC", "PMCID"]},' ...
     '"orcid": {"spelling": "ORCID", "synonyms": ["ORCID", "ORCiD"]},' ...
     '"ror": {"spelling": "ROR", "synonyms": []},' ...
     '"doi": {"spelling": "doi", "synonyms": []},' ...
     '"rrid": {"spelling": "RRID", "synonyms": []},' ...
     '"ncit": {"spelling": "NCIT", "synonyms": ["NCI", "NCIT", "NCIt"]},' ...
     '"ncbitaxon": {"spelling": "NCBITaxon", "synonyms": ["NCBITaxon", "taxonomy", "NCBIT"]},' ...
     '"wormbase": {"spelling": "WormBase", "synonyms": ["WB", "wb", "wormbase"],' ...
     '  "legacy_rewrite": {"legacy_prefix": "WBStrain", "id_prefix": "WBStrain"}},' ...
     '"edam": {"spelling": "EDAM", "synonyms": [],' ...
     '  "legacy_rewrite": {"legacy_prefix": "format", "id_prefix": "format_"}},' ...
     '"cellosaurus": {"spelling": "RRID", "synonyms": ["CVCL"],' ...
     '  "written_as": {"prefix": "rrid", "id_prefix": "CVCL_"}},' ...
     '"addgene": {"spelling": "RRID", "synonyms": [],' ...
     '  "written_as": {"prefix": "rrid", "id_prefix": "Addgene_"}},' ...
     '"pubchem.compound": {"spelling": "PubChem", "synonyms": ["CID", "Pubchem"]}' ...
     '}}'];
end
