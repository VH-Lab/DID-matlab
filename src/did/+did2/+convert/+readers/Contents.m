% +readers  Raw-body readers for legacy did_v1 databases.
%
%   The +readers subpackage exposes pure-read entry points that pull
%   the raw document JSON bodies out of the two v1 DID database
%   storage formats. Neither reader instantiates the corresponding
%   did.database subclass (those classes run their own validation and
%   maintain on-disk cache folders); both return a cellstr of JSON
%   strings suitable for piping into did2.convert.v1_to_v2.
%
%   Files
%     sqliteV1     - opens a v1 did.implementations.sqlitedb file via
%                    mksqlite and returns the `docs.json_code` column
%                    as a cellstr of raw JSON bodies.
%     dumbJsonV1   - walks a v1 did.implementations.matlabdumbjsondb
%                    directory (Object_id_*_v#####.json files) and
%                    returns the JSON contents as a cellstr, keeping
%                    only the latest version per document id.
%
%   See also: did2.convert.fromV1Database, did2.convert.v1_to_v2,
%             docs/v2/PLAN.md §9.6.
