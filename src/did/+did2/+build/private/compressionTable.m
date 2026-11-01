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
%                       PROPOSED (not decided): the names are this table's;
%                       the registry rows are did-schema's to add.
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
%   here as a synonym. Blosc and the setting variables are EMPTY terms waiting
%   for approval; until they are registered they are written as labels.
%   T.settings rows {key, variable name}: a codec setting's key as the source
%   writes it (numcodecs.Blosc's keys, NDI makePyramid.m codecParamsJSON) and
%   the `variable` of the parameter that holds it. A key not in the table is
%   written with the key itself as the variable's name (a label), so nothing
%   is lost. PROPOSED (not decided), as above.

t.codecs = { ...
    'gzip',       'gzip',  ''; ...
    'lzw',        'LZW',   ''; ...
    'blosc-zstd', 'Blosc', 'zstd'};
t.compressors = { ...
    'zstd',       'Zstandard'};
t.settings = { ...
    'cname',     'inner compressor'; ...
    'clevel',    'compression level'; ...
    'shuffle',   'shuffle'; ...
    'blocksize', 'block size'};
end
