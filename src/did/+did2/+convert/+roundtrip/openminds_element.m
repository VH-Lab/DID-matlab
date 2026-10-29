function [v1, spec] = openminds_element(bodies)
%OPENMINDS_ELEMENT Rebuild a v1 `openminds_element` from the term assertion
%   did2.convert.migrators_j.openminds_element converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds_element(BODIES). BODIES is
%   the one `assertion` about the element (its `element_id` edge becomes the
%   assertion's entity_id); private/openmindsInverse says what is rebuilt and
%   what is not. Unlike openminds_subject, the migrator converts EVERY
%   openminds_element, whether or not it states an `openminds_id`, and writes
%   the id nowhere; no decision covers that id or the other openMINDS fields
%   for an element, so the round trip reports each one v1 states.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.openminds_element.

arguments
    bodies cell
end

[v1, spec] = openmindsInverse(bodies, 'openminds_element', 'element_id');
end
