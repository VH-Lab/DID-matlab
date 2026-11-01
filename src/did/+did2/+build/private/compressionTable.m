function t = compressionTable()
%COMPRESSIONTABLE How a codec's source spelling and its settings map onto the
%   `data_body.compression` block {term, parameters}.
%
%   [compression block and empty levels] (1) (Decided by Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md; did-schema issue
%   #137): `compression` becomes a {term, parameters} block, the shape
%   `method` uses -- the codec as a term, its settings (e.g. Blosc's inner
%   compressor, level, shuffle, block size) as parameters.
%
%   THE ONE TABLE did2.build.compression (writing) and
%   did2.build.compressionCodec (reading) share, so the two are inverses.
%
%   T.codecs   rows {spelling, term name, inner compressor}:
%     spelling          the codec as a source spells it ('gzip' on NDI's
%                       ingested bodies, 'lzw' on a v1 image, 'blosc-zstd' on
%                       a v1 lightsheetZarrLevel)
%     term name         the name of the term `compression.term` holds. It is
%                       looked up in the term registry (by name, then by the
%                       registry rows' `synonyms`), so the registered node and
%                       label are written once did-schema registers it.
%     inner compressor  for a Blosc spelling, the inner compressor the
%                       spelling itself names ('blosc-zstd' -> 'zstd'); it is
%                       written as the `inner compressor` parameter, so the
%                       term is the codec alone (T19: a term as general as its
%                       meaning allows; the document carries the rest).
%   T.compressors rows {spelling, term name}: an inner compressor as a source
%   spells it (numcodecs.Blosc's `cname`) and the name of the term the
%   `inner compressor` parameter holds, looked up in the term registry as a
%   codec is. Only the inner compressor a codec row names ('zstd') has a row;
%   any other `cname` is written as a term with its own spelling as the name.
%   The codec and inner-compressor terms are existing ones: [compression terms
%   registered] (Decided by Jess Haley, 2026-11-01, did-schema
%   did_v2_go_forward_class_audit.md; docs/V2_PLAN.md L4): gzip
%   EDAM:format_3989 "GZIP format", LZW wikidata:Q2681 "Lempel-Ziv-Welch",
%   zstd wikidata:Q26737171 "Zstandard", each registered with the spelling
%   here as a synonym. Blosc and the four setting variables are the EMPTY
%   terms approved in [compression term definitions approved] (Decided by
%   Jess Haley, 2026-11-01; empty-ontology #35): EMPTY:0000426 Blosc,
%   EMPTY:0000427 compression level, EMPTY:0000428 compression block size,
%   EMPTY:0000429 shuffle filter, EMPTY:0000430 inner compressor. The names
%   below are those labels, so the registry resolves each to its node; until
%   did-schema registers a row, the name is written as a label.
%   T.settings rows {key, variable name}: a codec setting's key as the source
%   writes it (numcodecs.Blosc's keys, NDI makePyramid.m codecParamsJSON) and
%   the `variable` of the parameter that holds it. The writer uses the FIRST
%   row for a key; the reader maps every row's name back to its key, so the
%   later rows are names read only: 'shuffle' and 'block size', the names
%   this table wrote before the labels were approved. A key not in the table
%   is written with the key itself as the variable's name (a label), so
%   nothing is lost. The shuffle filter's setting (none, byte or bit; 0, 1, 2
%   in numcodecs) is written as the source gives it, not as a term
%   ([compression term definitions approved]: "plain text for the setting").

t.codecs = { ...
    'gzip',       'gzip',  ''; ...
    'lzw',        'LZW',   ''; ...
    'blosc-zstd', 'Blosc', 'zstd'};
t.compressors = { ...
    'zstd',       'Zstandard'};
% the last two rows are read only: the names written before the labels were
% approved
t.settings = { ...
    'cname',     'inner compressor'; ...
    'clevel',    'compression level'; ...
    'shuffle',   'shuffle filter'; ...
    'blocksize', 'compression block size'; ...
    'shuffle',   'shuffle'; ...
    'blocksize', 'block size'};
end
