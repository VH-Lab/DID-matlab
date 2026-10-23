function [datumType, sourceDatumType, byteOrder] = jDatumType(raw)
%JDATUMTYPE Normalise a MATLAB class name to the 14-value datum vocabulary.
%
%   [T, SRC] = jDatumType(RAW) maps the source's own spelling RAW onto the
%   bound `datum_type` enum, and returns the source spelling in SRC when it
%   differs. SRC is '' when RAW is already canonical, which is what
%   `subject_statement.source_datum_type` documents as "OMITTED when identical".
%   BYTEORDER is set only for an NGFF typestring (below); '' otherwise.
%
%   THE MAP IS THE SIGNED PLAN'S, verbatim (V_eta_data_body_model_plan.md, "The
%   datum_type normalisation map"), read from NDI's own writer:
%
%     +ndi/+fun/+data/mat2ngrid.m:38-44
%         ngrid.data_type = class(x);          % MATLAB class name
%         if islogical(x); ngrid.data_type = 'ubit1'; end
%
%       int8 int16 int32 int64        identical  -> source omitted
%       uint8 uint16 uint32 uint64    identical  -> source omitted
%       double  -> float64                       -> source 'double'
%       single  -> float32                       -> source 'single'
%       logical -> bool                          -> source 'logical'
%       ubit1   -> bool                          -> source 'ubit1'
%
%   WHY `source_datum_type` IS KEPT AT ALL: the map is NOT INVERTIBLE. `bool`
%   maps back to `logical` OR `ubit1`, and `char` has no canonical at all. The
%   source spelling is what makes the normalisation AUDITABLE -- the corpus can
%   be queried afterwards to check every `float64` came from a real `double`
%   rather than from a default.
%
%   AN UNRECOGNISED TYPE YIELDS '' AND KEEPS ITS SOURCE SPELLING, rather than
%   guessing. `datum_type` is optional in the schema, so an empty one is a legal
%   "not stated"; inventing a canonical for `char` -- which the plan records as
%   an OPEN DECISION, not a mapping (open item 6, still open) -- would be this
%   repository's documented failure mode of turning an unknown into a reassuring
%   claim. The source spelling still reaches the document, so nothing is lost
%   and the gap is visible in the corpus rather than hidden behind a default.
%
%   NOTE `image_stack.m` carries `firstNonEmpty(dataType, 'uint16')`, so a
%   silent default is not hypothetical there; that is its own defect and is not
%   papered over here.
arguments
    raw % a dtype as text (or a MATLAB class name); char() below
end

datumType = '';
sourceDatumType = '';
byteOrder = '';
raw = char(raw);
if isempty(raw); return; end

% NGFF / Zarr v2 TYPESTRINGS ('<u2', '>f4', '|u1'), added 2026-10-14 for the
% lightsheet migrators. The OME-Zarr path of NDI's lightsheet writer stamps the
% store's own `.zarray` dtype verbatim: ndi.fun.doc.lightsheet.fromOMEZarr ->
% ndr.format.omezarr.listPyramids (readZArrayMeta: `dtype = char(meta.dtype)`)
% -> makePyramid.m `'dtype', char(firstLevel.dtype)`. The SmartSPIM path
% (fromSPIM.m: `dtype = char(spim.dtype)`) stamps a MATLAB class name instead,
% which the map below already handles. A typestring is three facts -- byte
% order, kind, element size -- and the canonical name carries two, so the
% third comes back as BYTEORDER: 'little' for '<', 'big' for '>', '' for '|'
% (byte order not applicable: one-byte types). The source spelling is kept in
% SRC, as for every other non-canonical spelling. A typestring this map does
% not know ('<M8[ns]', '|S12', '<u3') yields '' -- not mapped, not defaulted.
tok = regexp(raw, '^([<>|])([uifcb])(\d+)$', 'tokens', 'once');
if ~isempty(tok)
    sourceDatumType = raw;
    switch tok{1}
        case '<'; byteOrder = 'little';
        case '>'; byteOrder = 'big';
        otherwise; byteOrder = '';
    end
    nbytes = str2double(tok{3});
    switch tok{2}
        case 'u'
            if any(nbytes == [1 2 4 8]); datumType = sprintf('uint%d', 8 * nbytes); end
        case 'i'
            if any(nbytes == [1 2 4 8]); datumType = sprintf('int%d', 8 * nbytes); end
        case 'f'
            if any(nbytes == [2 4 8]); datumType = sprintf('float%d', 8 * nbytes); end
        case 'c'
            if any(nbytes == [8 16]); datumType = sprintf('complex%d', 8 * nbytes); end
        case 'b'
            if nbytes == 1; datumType = 'bool'; end
    end
    return;
end

canonical = { ...
    'int8', 'int16', 'int32', 'int64', ...
    'uint8', 'uint16', 'uint32', 'uint64', ...
    'float16', 'float32', 'float64', ...
    'complex64', 'complex128', 'bool'};

if any(strcmp(raw, canonical))
    datumType = raw;            % already canonical -> source omitted
    return;
end

switch raw
    case 'double';  datumType = 'float64';
    case 'single';  datumType = 'float32';
    case 'logical'; datumType = 'bool';
    case 'ubit1';   datumType = 'bool';
    otherwise
        % `char`, and anything else a writer invents. NOT mapped, NOT defaulted.
        datumType = '';
end
sourceDatumType = raw;
end
