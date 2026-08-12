function v2Body = jDemoFold(preBody, isMock, sourceClass)
%JDEMOFOLD Fold a did_v1 demo document into the V_eta `demo` class, id-preserved.
%   Shared by the two migrators of the 3 -> 1 demo collapse (team, 2026-08-06,
%   recorded at did-schema `tools/build_v_eta.py:1817-1864`):
%
%       did_v1 demoNDI      -> demo, is_mock FALSE
%       did_v1 demoNDIMock  -> demo, is_mock TRUE
%       did_v1 mock         -> ceases to exist (no document can carry it alone;
%                              see the two migrators' headers for the measurement)
%
%   V2BODY = jDemoFold(PREBODY, ISMOCK, SOURCECLASS) renames the class, builds the
%   one `demo` block, and removes the did_v1 blocks the fold consumes.
%   SOURCECLASS is the did_v1 class name, used only in error messages so a
%   quarantine reason names the document that produced it.
%
%   1 -> 1 WITH `base` UNTOUCHED, so `base.id` is preserved. Every fold in this
%   project that changed a document id created dangling references; the calculator
%   dissolution cost 11,448 orphans on the Soph corpus.
%
%   ---------------------------------------------------------------------
%   WHAT ARRIVES HERE, AND WHY THE BLOCK NAMES ARE SNAKE_CASE
%   ---------------------------------------------------------------------
%   did2.convert.universalRenames runs first and snake_cases the class name and
%   every top-level property block key in lockstep. Its acronym-aware rule
%   (universalRenames.m:515-561) resolves the two NDI spellings as:
%
%       demoNDI      -> demo_ndi        ('N' after a lowercase opens a boundary;
%                                        'D' and 'I' continue the acronym)
%       demoNDIMock  -> demo_ndi_mock   ('M' has an uppercase predecessor and a
%                                        lowercase successor, so the acronym ends)
%       mock         -> mock            (already lowercase)
%
%   and NDI materialises SUPERCLASS property blocks into the document body
%   (ndi.document.readblankdefinition, step 3, `+ndi/document.m:1063-1100`), so a
%   did_v1 `demoNDIMock` body carries THREE of them: `demoNDIMock` (empty -- the
%   class declares no fields), `mock` (`ismock`) and `demoNDI` (`value`).
%   `ensureClassBlocks` drops only EMPTY non-contributing blocks, so the two
%   populated ones must be consumed here or the strict top-level check rejects
%   the document (`did2:validation:undeclaredBlock`).
%
%   ---------------------------------------------------------------------
%   `value` IS TYPED FROM THE WRITER, AND AN UNMAPPABLE ONE IS REFUSED
%   ---------------------------------------------------------------------
%   The did_v1 template declares `"value": ""` -- a char. Every writer sets a
%   NUMBER, which is why the signed target types it `double`:
%
%     DENOMINATOR: 1002 .m file(s) on NDI origin/main; 12 name demoNDI
%       +ndi/+calc/+example/simple.m:100,120   ndi.query('demoNDI.value',
%                                              'exact_number', 5 / 10, '')
%       +ndi/+calc/+example/simple.m:105,125   mock_doc_struct.demoNDI.value = 5 / 10
%       +ndi/+test/+database/test_ndi_document.m:33-35   newdocument(..., 5)
%       tests/.../buildSession.m:135 (+ the NDRIntan and NDRAxon twins)
%                                              doc_props.demoNDI.value = docNumber
%       tests/.../DocumentWriteTest.m:47, TestFindFuid.m:27, testDiff.m,
%       diffTest.m                             1, 5, 10, 20 -- numbers throughout
%
%   V_eta's `demo.value` is `double`, `mustBeScalar: true`, `mustBeNonEmpty:
%   false`. So there are exactly three cases and only one of them is a judgement:
%
%     numeric scalar  ->  carried as double.
%     EMPTY ('' or [])->  the field is OMITTED. That is the template's own
%                         untouched default, i.e. "no value was set", and
%                         `mustBeNonEmpty: false` makes an absent field valid.
%                         Carrying '' would fail the numeric type check and
%                         writing 0 would invent a measurement; omitting says
%                         exactly what the source said, which is nothing.
%     anything else   ->  ERROR. A guarded PASSTHROUGH IS NOT AVAILABLE HERE:
%                         did-schema deletes `demo_ndi`, `demo_ndi_mock` and
%                         `mock` from the built set (build_v_eta.py:1864-1867), so
%                         a passed-through document has no schema to validate
%                         against and quarantines with `missingClass` -- the
%                         image_stack shape, priced at 4,563 quarantines. An error
%                         quarantines it too, but with a reason that names the
%                         field and the shape, which is the difference between a
%                         report and a silence.
%
%   The same refusal covers any field the fold does not know: `demo` declares
%   `value` and `is_mock` and nothing else, so an unrecognised did_v1 field has
%   nowhere to go and must be reported rather than dropped.
%
%   UNVERIFIED: there is no MATLAB in the authoring environment. CI is the first
%   execution of this function.
arguments
    preBody (1,1) struct
    isMock (1,1) logical
    sourceClass (1,:) char
end

demoBlock = struct();

% ---- value, from the did_v1 `demoNDI` block (inherited by demoNDIMock) ----
src = getBlock(preBody, 'demo_ndi');
refuseUnknownFields(src, {'value'}, 'demo_ndi', sourceClass);
if isfield(src, 'value')
    v = src.value;
    if isnumeric(v) && isscalar(v)
        demoBlock.value = double(v);
    elseif ~isempty(v)
        error('did2:convert:demoUnmappableValue', ...
            ['%s carries a `value` that V_eta''s `demo.value` (double, ' ...
             'mustBeScalar) cannot hold: class %s, size %s. The did_v1 template ' ...
             'declares char and every writer sets a numeric scalar; a shape ' ...
             'outside both is reported rather than coerced.'], ...
            sourceClass, class(v), mat2str(size(v)));
    end
    % empty -> omitted; see the header. mustBeNonEmpty is false on this field.
end

% ---- is_mock ----
% For the mock arm the FLAG IS THE CLASS: `demoNDIMock` declares no fields of its
% own, and its whole content is "I am a mock demo". The did_v1 `mock` block is
% still READ rather than assumed, so a stored value wins over the class name --
% nothing in NDI ever writes `ismock` (0 hits for the token in 1002 .m files), so
% in practice this is the template's own 1.
% For the plain arm FALSE is written explicitly. It is not an invention: it is the
% value did-schema declares as `demo.is_mock`'s `default_value`, and writing it
% keeps the flag queryable on every migrated document rather than only on half of
% them.
demoBlock.is_mock = isMock;
if isMock
    % `demoNDIMock` declares NO fields -- its template property block is `{}` --
    % so anything at all on it is unmapped and is reported rather than dropped.
    refuseUnknownFields(getBlock(preBody, 'demo_ndi_mock'), {}, ...
        'demo_ndi_mock', sourceClass);
    mockBlock = getBlock(preBody, 'mock');
    refuseUnknownFields(mockBlock, {'ismock'}, 'mock', sourceClass);
    if isfield(mockBlock, 'ismock') && ~isempty(mockBlock.ismock)
        raw = mockBlock.ismock;
        if ~(islogical(raw) || isnumeric(raw)) || ~isscalar(raw)
            error('did2:convert:demoUnmappableIsMock', ...
                ['%s carries a `mock.ismock` that is not a logical/numeric ' ...
                 'scalar: class %s, size %s.'], ...
                sourceClass, class(raw), mat2str(size(raw)));
        end
        demoBlock.is_mock = logical(raw);
    end
end

% ---- the rename, and the consumed blocks ----
v2Body = preBody;
v2Body.document_class.class_name = 'demo';
v2Body.demo = demoBlock;
% `demo_ndi_mock` is the concrete block of the mock class and carries no fields;
% it is listed so the removal does not depend on ensureClassBlocks' empty-block
% sweep, which is a silent no-op when the schema cache cannot resolve the class.
consumed = {'demo_ndi', 'demo_ndi_mock', 'mock'};
for k = 1:numel(consumed)
    if isfield(v2Body, consumed{k})
        v2Body = rmfield(v2Body, consumed{k});
    end
end
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)) ...
        && isscalar(bodyStruct.(name))
    b = bodyStruct.(name);
end
end

function refuseUnknownFields(block, known, blockName, sourceClass)
%REFUSEUNKNOWNFIELDS Report a field the fold has no destination for.
%   `demo` declares exactly `value` and `is_mock`. Anything else in a consumed
%   block would be DROPPED by this fold, and a passthrough is not an available
%   fallback (the did_v1 classes are deleted from the built set), so the honest
%   move is to name it and stop.
if ~isstruct(block); return; end
fns = fieldnames(block);
if isempty(known)
    % Spelled out rather than left to ismember with an empty second argument:
    % `demo_ndi_mock` passes no known names at all, and this branch is the one
    % that runs for it.
    extra = fns;
else
    extra = fns(~ismember(fns, known));
end
if isempty(extra); return; end
% reshape rather than a transpose: `extra'` next to a char literal is legal but
% reads as an unbalanced quote, and there is no MATLAB here to settle it.
extraList = strjoin(reshape(extra, 1, []), ', ');
error('did2:convert:demoUnknownField', ...
    ['%s carries field(s) `%s` on its `%s` block, which the demo fold has no ' ...
     'destination for (V_eta `demo` declares only `value` and `is_mock`). ' ...
     'Reported rather than dropped: the did_v1 demo classes are deleted from ' ...
     'the built schema set, so there is no passthrough to fall back to.'], ...
    sourceClass, extraList, blockName);
end
