function names = rawV1Classes()
%RAWV1CLASSES The v1 classes whose migrator reads the RAW v1 document.
%
%   NAMES = did2.convert.rawV1Classes() is a cellstr of v1 class names (the
%   v1 spelling, document_class.class_name exactly as v1 writes it).
%   did2.convert.v1_to_v2 hands a document of one of these classes to its
%   +migrators_j migrator UNCHANGED: no did2.convert.universalRenames, no
%   superclass migrators. Every other class runs exactly as before.
%
%   WHY. Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): a migrator reads v1 exactly as v1 defines
%   it (the NDI template and writer at the locked `main`), writes V2 only
%   through the builder, and accounts for every v1 field; the shared reads are
%   helpers (did2.convert.v1read.*), not a pass that rewrites the document.
%   Migrators switch ONE AT A TIME, each with a check that every v1 field is
%   accounted for; universalRenames is deleted once the last one has switched.
%   The check is the round trip of [migration reliability practices] (a):
%   did2.convert.roundtrip.check.
%
%   ADDING A CLASS HERE requires, in the same commit:
%     - its migrator +migrators_j/<class>.m reads the raw v1 shape (the
%       did2.convert.v1read helpers for depends_on / base / app / stamp);
%     - its inverse +roundtrip/<class>.m, and a round-trip test on the NDI
%       writer shape (tests/+did2/+unittest/testRawV1RoundTrip.m);
%     - the class has no superclass migrator whose work the raw migrator now
%       has to do itself (+migrators/<superclass>.m, +migrators_j/+super/).
%   testRawV1RoundTrip checks the first two for every name listed.
%
%   THE LIST, and why each is here:
%     subject        first family switched (phase 2 of docs/V2_PLAN.md in
%     subject_group  did-schema): two classes, superclass `base` only, no
%                    `app` block, no superclass migrator, and NDI writers
%                    small enough to state every field (ndi.subject,
%                    +NDIMaker/subjectMaker; +babu/import for subject_group).
%
%   See also did2.convert.v1_to_v2, did2.convert.roundtrip.check.

names = {'subject', 'subject_group'};
end
