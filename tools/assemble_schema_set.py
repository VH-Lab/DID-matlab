#!/usr/bin/env python3
"""Assemble did-schema's V2 schema set into ONE flat folder for DID_SCHEMA_PATH.

    python3 tools/assemble_schema_set.py <did-schema>/schemas <dest>

The CI workflows load the schema set from one flat folder (did2.schema.cache
reads DID_SCHEMA_PATH). did-schema is changing its layout (Decided by Jess
Haley, 2026-10-30 [schema folders by family], did-schema
`V_eta_go_forward_class_audit.md`): `schemas/did_v2/` holds class files only,
in family subfolders (`value/`, `calculation/`, `data_body/`,
`time_reference/`, `retiring/`, core classes at the top); the non-class JSON
moves to `schemas/registry/` (authored) and `schemas/generated/` (written by
tools). Siblings first: this reads BOTH layouts.

  CLASS FILES   every *.json under the set folder (`schemas/did_v2`, else
                `schemas/V_eta`), at any depth, except folders named
                `registry` or `generated`, hidden folders, and non-class names
                (is_class_name). The old tiers (stable/, draft/, deprecated/)
                are just subfolders here.
  REGISTRY      every `*_meta.json` and `ndi_reserved_keys.json` anywhere under
                `schemas/` (today: did_v2/stable/; next: registry/ and
                generated/), and every *.json under `schemas/registry/`.

Everything is copied FLAT into <dest>. Two files with one basename are an
error: class names are unique across the tree, and a registry is read by its
basename (did2.schema.cache.registryFileIn applies the same rule).

Prints its denominator first; exits 1 when no class file was found.
"""

import os
import shutil
import sys

EXCLUDED_DIRS = ("registry", "generated")
NON_CLASS_NAMES = ("index", "topics", "ndi_reserved_keys")
NON_CLASS_PREFIXES = ("did_v2_", "V_eta_")


def is_class_name(stem):
    """Is `<stem>.json` a class file? Mirrors did2.schema.cache.isClassFileName."""
    return not (stem.endswith("_meta") or stem in NON_CLASS_NAMES
                or stem.startswith(NON_CLASS_PREFIXES))


def is_registry_name(name):
    return name.endswith("_meta.json") or name == "ndi_reserved_keys.json"


def set_dir(schemas):
    for name in ("did_v2", "V_eta"):
        d = os.path.join(schemas, name)
        if os.path.isdir(d):
            return d
    return None


def walk_json(root, skip_dirs=()):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs
                         if not d.startswith(".") and d not in skip_dirs)
        for f in sorted(files):
            if f.endswith(".json"):
                yield os.path.join(folder, f)


def class_files(schemas):
    sd = set_dir(schemas)
    if sd is None:
        return None, []
    out = [p for p in walk_json(sd, EXCLUDED_DIRS)
           if is_class_name(os.path.basename(p)[:-5])]
    return sd, out


def registry_files(schemas):
    out = [p for p in walk_json(schemas) if is_registry_name(os.path.basename(p))]
    reg = os.path.join(schemas, "registry")
    if os.path.isdir(reg):
        out += [p for p in walk_json(reg) if p not in out]
    return sorted(out)


def plan(schemas):
    """(set_dir, {basename: source}) or raise ValueError on a duplicate."""
    sd, classes = class_files(schemas)
    regs = registry_files(schemas)
    chosen = {}
    for src in classes + regs:
        name = os.path.basename(src)
        if name in chosen and chosen[name] != src:
            raise ValueError("two files named %s: %s and %s (class and registry "
                             "names must be unique across did-schema's schemas/ "
                             "tree)" % (name, chosen[name], src))
        chosen[name] = src
    return sd, classes, regs, chosen


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__)
        return 2
    schemas, dest = argv
    try:
        sd, classes, regs, chosen = plan(schemas)
    except ValueError as err:
        print("::error::%s" % err)
        return 1
    folders = sorted({os.path.relpath(os.path.dirname(p), schemas) for p in classes})
    print("DENOMINATOR: %d class file(s) from %d folder(s) under %s (%s), "
          "%d registry file(s)" % (len(classes), len(folders), schemas,
                                   ", ".join(folders) or "none", len(regs)))
    if not classes:
        print("::error::no class files found under %s (looked for did_v2/, then "
              "V_eta/, recursively)" % schemas)
        return 1
    os.makedirs(dest, exist_ok=True)
    for name, src in sorted(chosen.items()):
        shutil.copyfile(src, os.path.join(dest, name))
    print("copied %d file(s) into %s (schema set %s)" % (len(chosen), dest, sd))
    return 0


if __name__ == "__main__":
    sys.exit(main())
