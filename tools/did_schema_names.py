"""did-schema files read by name: the new `did_v2_*` name first, then `V_eta_*`.

did-schema renames its registers and data files in `schemas/` from `V_eta_*`
to `did_v2_*` (Decided by Jess Haley, 2026-10-26 [markdown cleanup and rename],
did-schema `V_eta_go_forward_class_audit.md`, part (6)): "Siblings first:
DID-matlab and NDI-matlab code that reads a renamed file accepts both names
before the old ones go." Every tool here that reads one of those files asks
this module for the path, so the rename in did-schema breaks nothing, and a
did-schema checkout from before the rename still reads.

The order is the rule: the `did_v2_*` name wins when both are present.

FOUND BY BASENAME, ANYWHERE UNDER `schemas/`. did-schema moves these files out
of the top of `schemas/` into `schemas/registry/` (authored) and
`schemas/generated/` (tool-written) (Decided by Jess Haley, 2026-10-30
[schema folders by family], did-schema `V_eta_go_forward_class_audit.md`;
"siblings first"). The exact folders are not final, so a file is found by its
basename wherever it sits under `schemas/`, in either layout. Two files with
one basename are an error (`DuplicateSchemaFile`), never a silent pick.
"""

import os
import subprocess

NEW_PREFIX = "did_v2_"
OLD_PREFIX = "V_eta_"


class DuplicateSchemaFile(ValueError):
    """Two files under did-schema's `schemas/` share a basename looked up."""


def schema_basenames(base):
    """The two basenames of one file, new first."""
    return [NEW_PREFIX + base, OLD_PREFIX + base]


def find_by_basename(schemas_dir, name):
    """Every file named `name` under `schemas_dir`, recursively (hidden folders
    skipped), sorted."""
    hits = []
    if not os.path.isdir(schemas_dir):
        return hits
    for folder, dirs, files in os.walk(schemas_dir):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        if name in files:
            hits.append(os.path.join(folder, name))
    return sorted(hits)


def unique_by_basename(paths, name, where):
    """The one path in `paths`, None for none, DuplicateSchemaFile for two."""
    if len(paths) > 1:
        raise DuplicateSchemaFile(
            "%d files named %s under %s: %s. A did-schema file is read by its "
            "basename, so the name must be unique ([schema folders by family])."
            % (len(paths), name, where, ", ".join(paths)))
    return paths[0] if paths else None


def schema_rels(base):
    """`schemas/<prefix><base>` for each name, new first (os.path.join form)."""
    return [os.path.join("schemas", NEW_PREFIX + base),
            os.path.join("schemas", OLD_PREFIX + base)]


def schema_git_paths(base):
    """The same paths as git spells them (forward slashes), new first."""
    return ["schemas/" + NEW_PREFIX + base, "schemas/" + OLD_PREFIX + base]


def find_schema_file(root, base):
    """The path under `root/schemas` (any depth) of the first basename that
    exists, new name first, or None. Raises DuplicateSchemaFile when two files
    carry the basename that would be read."""
    if not root:
        return None
    schemas_dir = os.path.join(root, "schemas")
    for name in schema_basenames(base):
        found = unique_by_basename(find_by_basename(schemas_dir, name), name,
                                   schemas_dir)
        if found:
            return found
    return None


def schema_file(root, base):
    """The path to read: the first name that exists, else the new name.

    Falling back to the new name (not None) keeps a caller's "does not exist"
    message pointing at the name did-schema now writes."""
    found = find_schema_file(root, base)
    return found if found else os.path.join(root, schema_rels(base)[0])


def git_show_schema_file(repo, base, rev="HEAD", timeout=60):
    """`git show <rev>:<path>` for the first name the commit holds.

    The commit's `schemas/` tree is listed and each basename (new first) is
    looked up at any depth, as find_schema_file does on disk. Returns
    (completed_process, git_path, cmd) for the first name that reads, else for
    the LAST name tried at its old top-level path, so the caller reports git's
    own error. Raises what subprocess.run raises (OSError, TimeoutExpired), and
    DuplicateSchemaFile when the commit holds two files with that basename."""
    listing = subprocess.run(
        ["git", "-C", repo, "ls-tree", "-r", "--name-only", rev, "--",
         "schemas"], timeout=timeout, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)
    held = []
    if listing.returncode == 0:
        held = listing.stdout.decode("utf-8", "replace").splitlines()
    candidates = []
    for name in schema_basenames(base):
        hit = unique_by_basename(
            sorted(p for p in held if p.rsplit("/", 1)[-1] == name), name,
            "%s:schemas" % rev)
        if hit:
            candidates.append(hit)
    candidates += [p for p in schema_git_paths(base) if p not in candidates]
    proc = git_path = cmd = None
    for git_path in candidates:
        cmd = ["git", "-C", repo, "show", rev + ":" + git_path]
        proc = subprocess.run(cmd, timeout=timeout, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        if proc.returncode == 0:
            break
    return proc, git_path, cmd
