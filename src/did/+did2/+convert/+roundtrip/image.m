function [v1, spec] = image(bodies)
%IMAGE Rebuild a v1 `image` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.image(BODIES). V1 is the image in NDI's
%   v1 shape (data/image.json + data/imageStack_parameters.json + base.json at
%   the locked NDI-matlab `main`; no writer at that commit constructs one).
%   BODIES is one of:
%
%   PASSED THROUGH (pass 1): one `image` document, the migrator's passthrough
%   of the raw v1 source (an image with no subject): the document itself, with
%   v1_to_v2's outbound renames undone (passthroughInverse).
%
%   CONVERTED (did2.convert.migrators_j.image, which hands the raw v1 document
%   to migrators_j.image_stack): the `observation` (value kind intensity, id
%   preserved), its `sampled_body` and its session anchor, read back by
%   did2.convert.roundtrip.imageStack, which an `image` shares except for:
%     depends_on                         document_id '', imageCollection_id ''
%                                        (an image naming either is carried,
%                                        carry-067 / carry-153) and subject_id,
%                                        the observation's entity_id, in the
%                                        order NDI's template merge gives them
%                                        (sorted: document_id,
%                                        imageCollection_id, subject_id)
%     image.label                        the observation's notes ([image label
%                                        goes to the observation's notes])
%     image.format                       the body's format: its registry name
%                                        in lower case when it has a node
%                                        ('tiff' from EDAM:format_3591), else
%                                        the name as v1 wrote it
%     image.compression                  the body's compression
%   No `imageStack` block: a v1 `image` has none.
%
%   WHY. Decided by Jess Haley, 2026-10-30 [image raw round trip and
%   single-read keys] (did-schema V_eta_go_forward_class_audit.md, G42): "a
%   raw-v1 round trip is built for `image` when `image` moves to the raw-v1
%   path, carrying the label back and rebuilding `format` 'tiff' from
%   EDAM:format_3591". The migrator writes a format NAME the term registry
%   holds with the registry's node and label, ignoring case ([migrator writes
%   the registry spelling], Jess Haley, 2026-10-26), so the v1 name is the
%   label in any case, or the node itself: spec.same compares it that way.
%
%   See also did2.convert.roundtrip.check, did2.convert.roundtrip.imageStack,
%            did2.convert.migrators_j.image.

arguments
    bodies cell
end

CLASS = 'image';
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    [v1, spec] = passthroughInverse(bodies, CLASS);
    return;
end

[v1, spec] = did2.convert.roundtrip.imageStack(bodies);
if ~isfield(v1, 'imageStack')
    return;     % imageStack named what it could not place
end
stack = v1.imageStack;
v1 = rmfield(v1, 'imageStack');
v1.document_class = struct('class_name', CLASS);
subjectId = '';
for k = 1:numel(v1.depends_on)
    if strcmp(v1.depends_on(k).name, 'subject_id')
        subjectId = v1.depends_on(k).value;
    end
end
v1.depends_on = struct('name', {'document_id', 'imageCollection_id', 'subject_id'}, ...
    'value', {'', '', subjectId});

% the body imageStack placed (it names the observation as its owner)
body = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'sampled_body') ...
            && any(strcmp(v1.base.id, edgeIds(bodies{k}, 'owner_id')))
        body = bodies{k};
        break;
    end
end

img = struct();
img.label = stack.label;
[fnode, fname] = termParts(getIn(body, 'data_body', 'format'));
img.format = fname;
if ~isempty(fnode)
    if isempty(fname)
        img.format = fnode;
    else
        img.format = lower(fname);
    end
end
% `compression` in either shape: the codec name (char), or the {term,
% parameters} block ([compression block and empty levels] (1), Jess Haley,
% 2026-10-26), read back to the image's spelling ('lzw') by
% did2.build.compressionCodec, the inverse of did2.build.compression
img.compression = did2.build.compressionCodec(getIn(body, 'data_body', 'compression'));
v1.image = img;

% the stack's formatOntology comparison does not apply; the image's format does
if isfield(spec, 'same') && ~isempty(spec.same)
    spec.same = spec.same(~strcmp({spec.same.path}, 'imageStack.formatOntology'));
end
if ~isempty(fnode)
    spec.same(end+1) = struct('path', 'image.format', ...
        'fn', @(a, ~) sameFormat(a, fnode, fname), ...
        'why', ['the migrator writes a registered format name with the ' ...
        'registry''s node and label, ignoring case ([migrator writes the ' ...
        'registry spelling], Jess Haley, 2026-10-26); a CURIE''s prefix case is ' ...
        'notation ([spelling is notation]); [image raw round trip and ' ...
        'single-read keys] (Jess Haley, 2026-10-30)']);
end
end

% ===================== helpers =========================================

function tf = sameFormat(v1Value, node, name)
% the v1 `format` names the body's format: the registry label in any case, or
% the node (a CURIE, its prefix case aside)
tf = false;
if ~(ischar(v1Value) || (isstring(v1Value) && isscalar(v1Value)))
    return;
end
v = strtrim(char(v1Value));
tf = (~isempty(name) && strcmpi(v, name)) || sameCurie(v, node);
end
