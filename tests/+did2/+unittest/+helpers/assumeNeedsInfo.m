function assumeNeedsInfo(testCase)
%ASSUMENEEDSINFO Skip (assumption failure) a test that needs the loaded schema
%   to declare `base.needs_info`.
%
%   [missing facts are needs info] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): a converted probe_geometry writes its
%   coordinate system with two `needs_info` entries, and did2.build refuses
%   'NeedsInfo' on a schema whose base declares no `needs_info`
%   (did2:build:needsInfoNotDeclared). did-schema declares it after DID-matlab
%   #295 (siblings first); until that reaches the did-schema ref a workflow
%   reads (main, or a same-name branch), a test of the converted shape is
%   NOT RUN, and says so, rather than failing on the schema it was given.
%
%   did2.unittest.helpers.assumeNeedsInfo(testCase)
if ~did2.unittest.helpers.schemaDeclares('base', {'needs_info'})
    assumeFail(testCase, sprintf(['NOT RUN: the loaded schema (%s) declares no ' ...
        'base.needs_info, which a converted probe_geometry''s coordinate ' ...
        'system needs ([missing facts are needs info])'], ...
        char(did2.schema.cache.shared().schemaPath)));
end
end
