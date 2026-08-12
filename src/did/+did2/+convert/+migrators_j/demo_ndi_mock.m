function v2Body = demo_ndi_mock(preBody)
%DEMO_NDI_MOCK Brainstorm-J migrator: did_v1 `demoNDIMock` -> the V_eta `demo`
%   class, 1 -> 1 with base.id PRESERVED, the INHERITED `demoNDI.value` carried
%   and `is_mock` TRUE. The other half of the 3 -> 1 demo collapse signed by the
%   team on 2026-08-06 (did-schema `tools/build_v_eta.py:1817-1867`); the fold
%   itself is in private/jDemoFold.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   THE WRITER, AND WHY THE VALUE ARRIVES ON THE PARENT'S BLOCK
%   ---------------------------------------------------------------------
%   `demoNDIMock` declares ZERO fields of its own -- its template's property block
%   is literally `{}` -- and subclasses BOTH `mock` and `demoNDI`. The production
%   writer passes a `demoNDI` block into a `demoNDIMock` document for exactly that
%   reason, `+ndi/+calc/+example/simple.m:105-113` (and :120-134 for the second):
%
%       mock_doc1_struct.demoNDI.value = 5;
%       mock_doc1 = ndi.document('demoNDIMock', 'demoNDI', ...
%                       mock_doc1_struct.demoNDI) + ...
%                       ndi_calculator_obj.session.newdocument();
%       fname1 = [ndi_calculator_obj.session.path() filesep 'test1_dummy.txt'];
%       vlt.file.str2text(fname1, 'dummy content');
%       mock_doc1 = mock_doc1.add_file('filename1.ext', fname1);
%       ndi_calculator_obj.session.database_add(mock_doc1);
%
%   Note the last line: these are ADDED TO A LIVE SESSION, which is why the flag
%   matters at all -- `is_mock` is the only marker separating self-test artefacts
%   from real data in the migrated database. `numberOfSelfTests` is 2, so a
%   session that has ever self-tested this calculator holds two of them.
%
%   NDI materialises superclass property blocks into the body
%   (`+ndi/document.m:1063-1100`), so the migrated body carries `demo_ndi_mock`
%   (empty), `mock` (`ismock`) and `demo_ndi` (`value`). jDemoFold consumes all
%   three; see its header for the snake_case derivation of the two NDI spellings.
%
%   ---------------------------------------------------------------------
%   `mock` NEEDS NO MIGRATOR, AND THIS IS THE MEASUREMENT
%   ---------------------------------------------------------------------
%   `mock` is a SUPERCLASS. It is deleted from the built V_eta set alongside the
%   other two, so if a bare `mock` document could exist it would pass through and
%   quarantine with `missingClass`. It cannot exist -- checked as a bare class
%   name across every construction idiom rather than one call shape, and checked
%   case-insensitively:
%
%     DENOMINATOR: 1002 .m file(s) on NDI origin/main
%       ndi.document('mock' / newdocument('mock' / 'isa','mock'   0 hit(s)
%       the token `ismock`, in any case                           0 hit(s)
%       the quoted literal 'mock', in any case                   13 hit(s)
%
%   The zero is therefore a MEASUREMENT and not a property of the query: the same
%   sweep returns 13 lines, and every one of them is something else -- a
%   `subject.local_identifier` substring (`+ndi/+mock/+fun/clear.m:16`), an email
%   prefix (`subject_stimulator_neuron.m:36`), a path segment (`ctest.m:262`), an
%   epochfiles name (`analogEventTest.m`), and openMINDS object names
%   (`testSubjectMaker.m`). None names a document class. No migrator is written
%   for a class whose documents cannot exist.
%
%   Whether mock-ness should have been a marker other classes could carry is an
%   OPEN QUESTION the signed decision records ("if mock documents are ever to be
%   carried-and-flagged rather than refused at migration, the flag belongs on
%   `base`, not on a parallel hierarchy"). It is not decided here.
%
%   UNVERIFIED: there is no MATLAB in the authoring environment. CI is the first
%   execution of every line here.

arguments
    preBody (1,1) struct
end

% is_mock TRUE -- and jDemoFold still READS `mock.ismock` when the body carries
% it, so a stored value wins over the class name.
v2Body = jDemoFold(preBody, true, 'demo_ndi_mock');
end
