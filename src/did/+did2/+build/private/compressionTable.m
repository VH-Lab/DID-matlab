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
%   T.settings rows {key, variable name}: a codec setting's key as the source
%   writes it (numcodecs.Blosc's keys, NDI makePyramid.m codecParamsJSON) and
%   the `variable` of the parameter that holds it. A key not in the table is
%   written with the key itself as the variable's name (a label), so nothing
%   is lost. PROPOSED (not decided), as above.

t.codecs = { ...
    'gzip',       'gzip',  ''; ...
    'lzw',        'LZW',   ''; ...
    'blosc-zstd', 'Blosc', 'zstd'};
t.settings = { ...
    'cname',     'inner compressor'; ...
    'clevel',    'compression level'; ...
    'shuffle',   'shuffle'; ...
    'blocksize', 'block size'};
end
