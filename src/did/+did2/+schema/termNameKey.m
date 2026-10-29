function key = termNameKey(name)
%TERMNAMEKEY The form in which a term's name is looked up in the term registry.
%
%   KEY = did2.schema.termNameKey(NAME) is NAME lowercased, with spaces,
%   underscores and hyphens removed: 'path name', 'Path_Name' and 'Pathname'
%   all give 'pathname'. [term names match ignoring spacing] (Jess Haley,
%   2026-10-29, did-schema V_eta_go_forward_class_audit.md): a registry term
%   is found by its name this way, as relation and entity-type handles are
%   (did2.build.vocabulary). did-schema's check_term_registry refuses two
%   registered names with the same key.
%
%   This is how a term is FOUND. The name a document stores is still the
%   registered one, exactly (did2.schema.termRegistered).
%
%   See also did2.schema.termIndex, did2.build.vocabulary.

arguments
    name {mustBeText}
end

key = lower(regexprep(char(name), '[\s_\-]', ''));
end
