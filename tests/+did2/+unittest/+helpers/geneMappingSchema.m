function p = geneMappingSchema(testCase, src)
%GENEMAPPINGSCHEMA A temporary copy of the schema set SRC that declares what a
%   converted gene-list mapping writes.
%
%   P = did2.unittest.helpers.geneMappingSchema(TESTCASE, SRC) copies the
%   schema set at SRC flat into a temporary folder (removed at TESTCASE's
%   teardown) and returns its path. Siblings first: until did-schema declares
%   it, the copy adds, as text, data.json's covariate `index`, after `key`
%   (Jess Haley, 2026-11-01, did-schema did_v2_go_forward_class_audit.md [key
%   covariate index]). What SRC already declares is left as it is.
%   undirected_relation's `relatum_id` ([undirected ends are relata],
%   [undirected relation widened]) is not added here: did-schema declares it,
%   and the code no longer reads or writes the old `entity_id`.
%
%   See also did2.convert.migrators_j.gene_list_mapping.

tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
p = tmp;

f = fullfile(tmp, 'data.json');
txt = fileread(f);
if isempty(strfind(txt, '"name": "index"'))
    k = strfind(txt, '"name": "key"');
    assert(isscalar(k), 'geneMappingSchema: data.json declares %d `key` fields; expected 1.', numel(k));
    c = strfind(txt(k:end), '"constraints"');
    pos = k + c(1) - 1;
    brace = find(txt(pos:end) == '}', 2);   % the constraints object, then the field
    at = pos + brace(2) - 1;
    def = ['{"name": "index", "type": "integer", "blank_value": [], "default_value": [], ' ...
        '"mustBeNonEmpty": false, "mustBeScalar": false, "mustNotHaveNaN": false, ' ...
        '"queryable": true, "ontology": null, ' ...
        '"documentation": "test copy: [key covariate index].", "constraints": {}}'];
    writeText(f, [txt(1:at) ', ' def txt(at+1:end)]);
end
end

function writeText(f, txt)
fid = fopen(f, 'w');
fwrite(fid, txt);
fclose(fid);
end
