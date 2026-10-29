function [v1, spec] = openminds_element(bodies)
%OPENMINDS_ELEMENT Rebuild a v1 `openminds_element` from the term assertion
%   did2.convert.migrators_j.openminds_element converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds_element(BODIES). BODIES is
%   the one `assertion` about the element (its `element_id` edge becomes the
%   assertion's entity_id); private/openmindsInverse says what is rebuilt and
%   what is not. A document stating an `openminds_id` or a
%   `fields.description` is carried whole as v1 by the migrator (carry-128,
%   [openMINDS element leftovers carried], Jess Haley, 2026-10-29), stamped
%   did_v1, and never reaches this inverse (did2.convert.roundtrip.check
%   compares the carry itself). The other openMINDS fields v1 states (a
%   definition, a synonym, ...) are reported.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.openminds_element.

arguments
    bodies cell
end

[v1, spec] = openmindsInverse(bodies, 'openminds_element', 'element_id');
end
