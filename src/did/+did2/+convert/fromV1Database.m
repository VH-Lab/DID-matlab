function result = fromV1Database(srcPath, dstPath, options)
%FROMV1DATABASE did_v1 database -> V_eta database, per-document pass only.
%
%   RESULT = did2.convert.fromV1Database(SRCPATH, DSTPATH) reads every
%   document body out of the v1 source at SRCPATH, runs it through
%   did2.convert.v1_to_v2 at TargetVersion 'V_eta', and inserts the
%   successful did2.document instances into a fresh did2.database.sqlitedb
%   at DSTPATH.
%
%   THIS IS PASS 1 ONLY. The batch post-passes (epochMint,
%   resolveSessionAnchors, ...) and the NDI second pass that complete a
%   V_eta migration need the whole document set and run in
%   ndi.migrate.local, which is the way to migrate an NDI dataset. Until
%   2026-10-23 this function took v1_to_v2's default target 'V_delta',
%   which no longer exists (Jess Haley, 2026-10-23; DID-matlab #224).
%
%   SRCPATH may be either:
%     - a file (e.g. *.sqlite) - read via did2.convert.readers.sqliteV1
%       as a did.implementations.sqlitedb file.
%     - a directory             - read via did2.convert.readers.dumbJsonV1
%       as a did.implementations.matlabdumbjsondb tree.
%
%   Quarantine entries produced by v1_to_v2 are written as a JSON array
%   to <DSTPATH>.quarantine.json. The function returns the same result
%   struct v1_to_v2 returns: `migrated`, `quarantine`, `summary`.
%
%   Options (name-value):
%     Validate     (1,1 logical, default true)  - validate each migrated
%                  document against its V_eta schema.
%     SchemaCache  (default [])                 - override the shared
%                  did2.schema.cache singleton (test plumbing).
%     Verbose      (1,1 logical, default false) - print the v1_to_v2
%                  end-of-run summary.
%     Overwrite    (1,1 logical, default false) - refuse to overwrite
%                  an existing DSTPATH unless true. The quarantine file
%                  is treated symmetrically.
%
%   Errors:
%     did2:convert:badSourcePath  - SRCPATH is neither a file nor a
%                                   directory.
%     did2:convert:overwriteRefused - DSTPATH (or its quarantine
%                                   sidecar) already exists and
%                                   Overwrite was not requested.
%
%   See also: did2.convert.v1_to_v2,
%             did2.convert.readers.sqliteV1,
%             did2.convert.readers.dumbJsonV1,
%             did2.database.sqlitedb.

arguments
    srcPath (1,:) char
    dstPath (1,:) char
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.Verbose (1,1) logical = false
    options.Overwrite (1,1) logical = false
end

quarantineFile = [dstPath '.quarantine.json'];

if ~options.Overwrite
    if isfile(dstPath)
        error('did2:convert:overwriteRefused', ...
            ['Destination "%s" already exists. Pass Overwrite=true ' ...
             'to replace it.'], dstPath);
    end
    if isfile(quarantineFile)
        error('did2:convert:overwriteRefused', ...
            ['Quarantine sidecar "%s" already exists. Pass ' ...
             'Overwrite=true to replace it.'], quarantineFile);
    end
end

if options.Overwrite
    if isfile(dstPath)
        delete(dstPath);
    end
    if isfile(quarantineFile)
        delete(quarantineFile);
    end
end

if isfile(srcPath)
    bodies = did2.convert.readers.sqliteV1(srcPath);
elseif isfolder(srcPath)
    bodies = did2.convert.readers.dumbJsonV1(srcPath);
else
    error('did2:convert:badSourcePath', ...
        ['Source "%s" is neither a file nor a directory; ' ...
         'cannot infer reader.'], srcPath);
end

result = did2.convert.v1_to_v2(bodies, ...
    'TargetVersion', 'V_eta', ...
    'Validate', options.Validate, ...
    'SchemaCache', options.SchemaCache, ...
    'Verbose', options.Verbose);

db = did2.database.sqlitedb(dstPath, 'SchemaCache', options.SchemaCache);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
if ~isempty(result.migrated)
    db.add(result.migrated, 'Validate', options.Validate);
end

if ~isempty(result.quarantine)
    writeQuarantineFile(quarantineFile, result.quarantine);
end
end

function writeQuarantineFile(quarantineFile, quarantineStructArray)
text = jsonencode(quarantineStructArray);
fid = fopen(quarantineFile, 'w');
if fid < 0
    error('did2:convert:readerFailed', ...
        'Failed to open quarantine file "%s" for writing.', quarantineFile);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text, 'char');
end
