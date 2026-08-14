function tests = testJsonRoundTrip
% testJsonRoundTrip - a written document must be readable, and re-validate.
%
%   Run with:
%       results = runtests('did2.unittest.testJsonRoundTrip');
%
%   NOTHING IN EITHER REPOSITORY ASSERTED THIS BEFORE 2026-08-14, and the
%   gap is why a migration could report `quarantined: 0` and leave seven
%   documents that could not be read back. Validation ran on the
%   IN-MEMORY body, on the way in, and never on what came out. Every
%   corpus figure the project quotes -- the 633,432-document run included
%   -- was measured the same way.
%
%   HOW IT SURFACED. A real session, re-opened:
%
%       documents seen   : 41
%       quarantined      : 7
%          software: Field "entity.global_identifier" must be a struct.
%          acquisition_system: Field "entity.global_identifier" must be a struct.
%
%   Those 41 came OUT of the database that had just been written with
%   `quarantined: 0`.
%
%   THE CAUSE IS DECODE, NOT ENCODE. A writer with no identifiers to
%   report emits a 0x0 struct array deliberately (jSoftware.m:120,
%   "present-and-empty rather than absent-and-guessed-at"). `jsonencode`
%   renders that `[]`, which is a faithful record of "zero elements" --
%   the subfield names were never document data. `jsondecode` then has to
%   pick a MATLAB type for `[]` and picks `double`, because JSON cannot
%   say "empty array OF OBJECTS" and nothing was consulting the schema.
%
%   THE TESTS ARE ORDERED SMALLEST-FIRST ON PURPOSE. The first two pin
%   MATLAB's own behaviour, so that if a future release makes `jsondecode`
%   correct without a schema, the failure says so rather than looking like
%   a regression in our code.
%
%   See also: did2.schema.cache/rehydrate, did2.document/fromJSON.

tests = functiontests(localfunctions);
end

% ===================== the premise ==========================================

function testAnEmptyStructArrayDoesNotSurviveJsonAlone(testCase)
% THE WHOLE DEFECT IN ONE LINE.
gids = struct('scheme', {}, 'value', {});
verifyTrue(testCase, isstruct(gids), ...
    'Precondition: the writer idiom really is a struct array.');
verifyEqual(testCase, numel(gids), 0);

roundTripped = jsondecode(jsonencode(gids));
verifyFalse(testCase, isstruct(roundTripped), ...
    ['jsondecode(jsonencode(<0x0 struct array>)) is now a struct. ' ...
     'MATLAB changed; did2.schema.cache.rehydrate''s empty branch can ' ...
     'be retired.']);
end

function testARaggedObjectArrayDecodesAsACell(testCase)
% THE ONE THAT HAS NOT BITTEN YET. `subject_statement.conditions` holds
% entries carrying `count` OR `quantity`, never both -- so as soon as the
% data_body tier starts writing them, this is the shape that comes back.
% Pinned now, while it is cheap.
decoded = jsondecode('[{"a":1},{"b":2}]');
verifyTrue(testCase, iscell(decoded), ...
    ['A JSON array of objects with differing keys no longer decodes to ' ...
     'a cell. rehydrate''s ragged branch may be retirable.']);
end

% ===================== the repair ===========================================

function testRehydrateRestoresAnEmptyStructArrayField(testCase)
cache = localCache(testCase);
s = localSoftwareBody(testCase, cache, '');
s.entity.global_identifier = [];          % what jsondecode hands back

out = cache.rehydrate(s);

verifyTrue(testCase, isstruct(out.entity.global_identifier), sprintf( ...
    ['rehydrate left entity.global_identifier a %s. That is the exact ' ...
     'shape that made seven documents unreadable.'], ...
    class(out.entity.global_identifier)));
verifyEqual(testCase, numel(out.entity.global_identifier), 0, ...
    'An empty field must rehydrate to ZERO elements, not one blank one.');
verifyEqual(testCase, sort(fieldnames(out.entity.global_identifier)), ...
    {'scheme'; 'value'}, ...
    'The declared subfield names come from the schema, not from the data.');
end

function testRehydrateRestoresARaggedArrayToAStructArray(testCase)
cache = localCache(testCase);
s = localSoftwareBody(testCase, cache, '');
s.entity.global_identifier = { struct('scheme', 'URL'), ...
                               struct('value',  'x') };

out = cache.rehydrate(s);

g = out.entity.global_identifier;
verifyTrue(testCase, isstruct(g), sprintf( ...
    'A ragged array stayed a %s after rehydrate.', class(g)));
verifyEqual(testCase, numel(g), 2);
verifyEqual(testCase, g(1).scheme, 'URL');
verifyEmpty(testCase, g(1).value, ...
    'A key absent from one JSON object must fill as [], not vanish.');
verifyEmpty(testCase, g(2).scheme);
verifyEqual(testCase, g(2).value, 'x');
end

function testRehydrateLeavesAPopulatedFieldAlone(testCase)
% The repair must be a no-op on documents that were already fine.
cache = localCache(testCase);
s = localSoftwareBody(testCase, cache, 'https://example.org/tool');

out = cache.rehydrate(s);

verifyEqual(testCase, numel(out.entity.global_identifier), 1);
verifyEqual(testCase, out.entity.global_identifier(1).scheme, 'URL');
verifyEqual(testCase, out.entity.global_identifier(1).value, ...
    'https://example.org/tool');
end

function testRehydrateDoesNotInventAnAbsentField(testCase)
% ABSENT AND EMPTY ARE DIFFERENT FACTS and this repair must not merge
% them. `mustBeNonEmpty` and `undeclaredField` own that question; a
% rehydrator that helpfully materialised missing fields would answer it
% silently and wrongly.
cache = localCache(testCase);
s = localSoftwareBody(testCase, cache, '');
s.entity = rmfield(s.entity, 'global_identifier');

out = cache.rehydrate(s);

verifyFalse(testCase, isfield(out.entity, 'global_identifier'), ...
    'rehydrate materialised a field the document did not carry.');
end

function testRehydrateLeavesARealTypeErrorForTheValidator(testCase)
% A NON-EMPTY wrong-typed value must survive to be reported. Coercing it
% would turn a type error into a silent reshape -- the failure mode this
% repair exists to remove, reintroduced by the repair.
cache = localCache(testCase);
s = localSoftwareBody(testCase, cache, '');
s.entity.global_identifier = 42;

out = cache.rehydrate(s);

verifyEqual(testCase, out.entity.global_identifier, 42, ...
    'rehydrate silently reshaped a value that is genuinely wrong.');
end

function testRehydrateIsANoOpForAnUnknownClass(testCase)
% Reading must not be gated on a schema being present: validation is where
% "no such class" belongs, and it already raises there.
cache = localCache(testCase);
s = struct('document_class', ...
    struct('class_name', 'no_such_class_anywhere', 'class_version', '1.0.0'), ...
    'depends_on', [], ...
    'no_such_class_anywhere', struct('x', []));

out = cache.rehydrate(s);
verifyEqual(testCase, out.no_such_class_anywhere.x, []);
end

% ===================== the property that matters ============================

function testWrittenDocumentSurvivesAFullDatabaseRoundTrip(testCase)
% THE TEST THAT SHOULD HAVE EXISTED. Write -> sqlite -> read -> validate.
% Everything above is a unit; this is the actual claim.
localAssumeMksqlite(testCase);
cache = localCache(testCase);

dbFile = [tempname '.sqlite'];
fileCleanup = onCleanup(@() localDelete(dbFile)); %#ok<NASGU>

db = did2.database.sqlitedb(dbFile, 'SchemaCache', cache);
dbCleanup = onCleanup(@() localClose(db)); %#ok<NASGU>

doc = did2.document(localSoftwareBody(testCase, cache, ''));
db.add(doc, 'Validate', true);

readBack = db.get(doc.get('base.id'));

% DENOMINATOR first, and unconditionally.
log(testCase, sprintf( ...
    'DENOMINATOR: 1 document written and read back, class "%s"', ...
    readBack.className()));

gids = readBack.get('entity.global_identifier');
verifyTrue(testCase, isstruct(gids), sprintf( ...
    ['A document that validated on write came back with ' ...
     'entity.global_identifier as a %s. That is the defect verbatim.'], ...
    class(gids)));

% AND IT MUST RE-VALIDATE. `isstruct` passing is necessary and not
% sufficient: the original failure was raised BY the validator, so the
% validator is what has to agree. Caught rather than left to propagate so
% the diagnostic carries the validator's own message.
revalidated = true;
why = '';
try
    readBack.validate('SchemaCache', cache);
catch err
    revalidated = false;
    why = err.message;
end
verifyTrue(testCase, revalidated, sprintf( ...
    'The round-tripped document does not re-validate: %s', why));
end

% ===================== helpers ==============================================

function s = localSoftwareBody(testCase, cache, url)
% The SCAFFOLD comes from the schema (`blank` gets the class chain and the
% block layout right, which a hand-written body cannot be trusted to do);
% the FIELD UNDER TEST comes from the writer. That split matters: the
% ground-truth rule is that the writer is the truth, and the defect is
% specifically about the writer's 0x0-struct-array idiom.
try
    doc = did2.document.blank('software', 'SchemaCache', cache);
catch err
    assumeFail(testCase, sprintf( ...
        'Cannot build a blank `software` document here: %s', err.message));
end
s = doc.toStruct();

s.base.id = did.ido.unique_id();
s.base.session_id = '';
s.base.name = 'round-trip-fixture';
% THE CREATION-TIME FIELD IS MID-RENAME ACROSS TWO REPOSITORIES, so it is
% written to whichever name the SCHEMA produced rather than to a literal.
% `base.datestamp` -> `base.creation_timestamp` is signed and implemented
% DID-side (v1_to_v2/renameOutboundBaseFields strips the old key from every
% V_eta body; sqlitedb/requireCreationTimestamp accepts either), while the
% did-schema half is not built yet. Hard-coding either spelling would make
% this test fail on the day the other one lands -- and fail for a reason
% that has nothing to do with what it is testing.
for stamp = {'creation_timestamp', 'datestamp'}
    if isfield(s.base, stamp{1})
        s.base.(stamp{1}) = '2024-01-01T00:00:00.000Z';
    end
end

gids = struct('scheme', {}, 'value', {});   % jSoftware.m:120, verbatim
if ~isempty(url)
    gids(end+1) = struct('scheme', 'URL', 'value', url);
end
s.entity.global_identifier = gids;

s.software.name = 'round-trip-fixture';
end

function c = localCache(testCase)
p = getenv('DID_SCHEMA_PATH');
if isempty(p) || ~isfile(fullfile(p, 'software.json'))
    % ASSUMPTION FAILURE, NOT A TEST FAILURE. "no assembled V_eta schema
    % set here" and "the round trip is broken" are different findings and
    % must not print alike.
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not point at an assembled V_eta schema ' ...
         'set (no software.json beside it), so the round trip cannot ' ...
         'be checked here.']);
end
% setSchemaPath, not shared(p): `shared` only honours its argument when no
% singleton exists yet, so a cache built earlier in the session would keep
% its old path and this test would silently check the wrong schema set.
% That is the same stale-singleton trap the V_eta walkthrough hit.
did2.schema.cache.setSchemaPath(p);
c = did2.schema.cache.shared();
end

function localAssumeMksqlite(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, 'mksqlite is not on the path.');
end
end

function localClose(db)
try
    db.close();
catch
    % already closed
end
end

function localDelete(f)
if isfile(f)
    delete(f);
end
end
