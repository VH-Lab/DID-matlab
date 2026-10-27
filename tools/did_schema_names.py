"""did-schema files read by name: the new `did_v2_*` name first, then `V_eta_*`.

did-schema renames its registers and data files in `schemas/` from `V_eta_*`
to `did_v2_*` (Decided by Jess Haley, 2026-10-26 [markdown cleanup and rename],
did-schema `V_eta_go_forward_class_audit.md`, part (6)): "Siblings first:
DID-matlab and NDI-matlab code that reads a renamed file accepts both names
before the old ones go." Every tool here that reads one of those files asks
this module for the path, so the rename in did-schema breaks nothing, and a
did-schema checkout from before the rename still reads.

The order is the rule: the `did_v2_*` name wins when both are present.
"""

import os
import subprocess

NEW_PREFIX = "did_v2_"
OLD_PREFIX = "V_eta_"


def schema_rels(base):
    """`schemas/<prefix><base>` for each name, new first (os.path.join form)."""
    return [os.path.join("schemas", NEW_PREFIX + base),
            os.path.join("schemas", OLD_PREFIX + base)]


def schema_git_paths(base):
    """The same paths as git spells them (forward slashes), new first."""
    return ["schemas/" + NEW_PREFIX + base, "schemas/" + OLD_PREFIX + base]


def find_schema_file(root, base):
    """The path under `root` of the first name that exists, or None."""
    if not root:
        return None
    for rel in schema_rels(base):
        path = os.path.join(root, rel)
        if os.path.isfile(path):
            return path
    return None


def schema_file(root, base):
    """The path to read: the first name that exists, else the new name.

    Falling back to the new name (not None) keeps a caller's "does not exist"
    message pointing at the name did-schema now writes."""
    found = find_schema_file(root, base)
    return found if found else os.path.join(root, schema_rels(base)[0])


def git_show_schema_file(repo, base, rev="HEAD", timeout=60):
    """`git show <rev>:<path>` for the first name the commit holds.

    Returns (completed_process, git_path, cmd) for the first name that reads,
    else for the LAST name tried, so the caller reports git's own error.
    Raises what subprocess.run raises (OSError, TimeoutExpired)."""
    proc = git_path = cmd = None
    for git_path in schema_git_paths(base):
        cmd = ["git", "-C", repo, "show", rev + ":" + git_path]
        proc = subprocess.run(cmd, timeout=timeout, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        if proc.returncode == 0:
            break
    return proc, git_path, cmd
