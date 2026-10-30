#!/usr/bin/env python3
"""Both did-schema layouts read the same: tools/assemble_schema_set.py and
tools/did_schema_names.py.

did-schema moves to family folders (Decided by Jess Haley, 2026-10-30
[schema folders by family], did-schema `V_eta_go_forward_class_audit.md`):
classes recursively under `schemas/did_v2/`, the registries in
`schemas/registry/`, the tool-written files in `schemas/generated/`, and the
`V_eta_*.json` data files renamed `did_v2_*.json`. Siblings read both layouts
first. Each test builds the SAME content in the old layout and in the new one
in a temp directory, and checks that:

  1. the CI assembly copies the same class files and the same registries from
     both (and the flat folder it writes holds every class exactly once);
  2. the old layout's assembly is what the old `cp stable/*.json draft/*.json`
     copied;
  3. a class name held twice anywhere in the tree, or a registry held in two
     folders, FAILS rather than one copy silently winning;
  4. an empty tree FAILS (no tidy zero);
  5. did_schema_names finds a data file by basename at any depth under
     `schemas/`, new prefix first, in a working tree and in a git commit, and
     raises on two files with one basename.

Run: python3 tools/test_schema_layouts.py     (or: python3 -m pytest)
"""

import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import assemble_schema_set as asm  # noqa: E402
import did_schema_names as dsn  # noqa: E402

# class name -> (old tier, new family folder; '' is the top level)
CLASSES = {
    "base": ("stable", ""),
    "entity": ("stable", ""),
    "assertion": ("stable", ""),
    "mass": ("stable", "value"),
    "term": ("stable", "value"),
    "tuning_curve_calculation": ("stable", "calculation"),
    "sampled_body": ("stable", "data_body"),
    "clock_type": ("draft", "time_reference"),
    "genomic_interval": ("draft", "value"),
    "old_thing": ("deprecated", "retiring"),
}
# registry/meta file -> new folder (old: did_v2/stable/)
META = {
    "CURIE_lookups_meta.json": "registry",
    "binding_registry_meta.json": "registry",
    "ndi_reserved_keys.json": "registry",
    "did_schema_meta.json": "registry",
    "term_registry_meta.json": "generated",
    "class_disposition_meta.json": "generated",
    "quantity_list_meta.json": "generated",
}
# schemas/V_eta_<base> (old, top level) -> new folder, renamed did_v2_<base>
DATA = {
    "term_registry.json": "registry",
    "carry_register.json": "registry",
    "openminds_crosswalk.json": "registry",
    "coverage_ledger.json": "generated",
    "decisions.json": "generated",
}


def _write(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        json.dump(obj, fh)


def build(root, layout):
    """A did-schema checkout at `root` in `layout` ('old' or 'new')."""
    s = os.path.join(root, "schemas")
    for name, (tier, family) in CLASSES.items():
        sub = tier if layout == "old" else family
        _write(os.path.join(s, "did_v2", sub, name + ".json"),
               {"classname": name})
    for name, folder in META.items():
        where = os.path.join(s, "did_v2", "stable") if layout == "old" \
            else os.path.join(s, folder)
        _write(os.path.join(where, name), {"file": name})
    for base, folder in DATA.items():
        if layout == "old":
            _write(os.path.join(s, "V_eta_" + base), {"file": base})
        else:
            _write(os.path.join(s, folder, "did_v2_" + base), {"file": base})
    gen = os.path.join(s, "did_v2") if layout == "old" else os.path.join(s, "generated")
    _write(os.path.join(gen, "index.json"), {"classes": sorted(CLASSES)})
    if layout == "old":
        _write(os.path.join(s, "did_v2", "topics.json"), {})
    return s


@contextlib.contextmanager
def tmp():
    d = tempfile.mkdtemp()
    try:
        yield d
    finally:
        shutil.rmtree(d)


def assemble(schemas, dest):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = asm.main([schemas, dest])
    return code, out.getvalue()


def stems(dest):
    return {f[:-5] for f in os.listdir(dest) if f.endswith(".json")}


def test_both_layouts_assemble_the_same_classes_and_registries():
    with tmp() as d:
        got = {}
        for layout in ("old", "new"):
            schemas = build(os.path.join(d, layout), layout)
            dest = os.path.join(d, layout + "-flat")
            code, out = assemble(schemas, dest)
            assert code == 0, out
            assert out.startswith("DENOMINATOR: %d class file(s)" % len(CLASSES)), out
            got[layout] = stems(dest)
        classes = {s for s in got["new"] if asm.is_class_name(s)}
        assert classes == set(CLASSES), classes
        assert {s for s in got["old"] if asm.is_class_name(s)} == classes
        meta = {m[:-5] for m in META}
        assert meta <= got["old"] and meta <= got["new"], got
        # The new layout also carries the authored registry files; they are not
        # classes, so the cache never loads them as one.
        extra = got["new"] - got["old"]
        assert extra == {"did_v2_" + b[:-5] for b, f in DATA.items()
                         if f == "registry"}, extra
        assert not any(asm.is_class_name(s) for s in extra), extra
        assert "index" not in got["new"] and "topics" not in got["old"]


def test_the_old_layout_matches_the_old_cp():
    with tmp() as d:
        schemas = build(os.path.join(d, "old"), "old")
        dest = os.path.join(d, "flat")
        assert assemble(schemas, dest)[0] == 0
        expected = set()
        for tier in ("stable", "draft", "deprecated"):
            expected |= {f[:-5] for f in os.listdir(os.path.join(schemas, "did_v2", tier))}
        assert stems(dest) == expected, stems(dest) ^ expected


def test_a_class_held_twice_fails():
    with tmp() as d:
        schemas = build(os.path.join(d, "new"), "new")
        _write(os.path.join(schemas, "did_v2", "value", "entity.json"), {})
        code, out = assemble(schemas, os.path.join(d, "flat"))
        assert code == 1 and "two files named entity.json" in out, out


def test_a_registry_held_in_two_folders_fails():
    with tmp() as d:
        schemas = build(os.path.join(d, "new"), "new")
        _write(os.path.join(schemas, "generated", "binding_registry_meta.json"), {})
        code, out = assemble(schemas, os.path.join(d, "flat"))
        assert code == 1 and "binding_registry_meta.json" in out, out


def test_an_empty_tree_fails():
    with tmp() as d:
        os.makedirs(os.path.join(d, "schemas", "did_v2"))
        code, out = assemble(os.path.join(d, "schemas"), os.path.join(d, "flat"))
        assert code == 1 and "DENOMINATOR: 0 class file(s)" in out, out


def test_data_files_are_found_by_basename_in_both_layouts():
    with tmp() as d:
        for layout in ("old", "new"):
            root = os.path.join(d, layout)
            build(root, layout)
            for base, folder in DATA.items():
                path = dsn.find_schema_file(root, base)
                want = os.path.join(root, "schemas", "V_eta_" + base) \
                    if layout == "old" else \
                    os.path.join(root, "schemas", folder, "did_v2_" + base)
                assert path == want, (layout, base, path)
        assert dsn.find_schema_file(os.path.join(d, "new"), "nothing.json") is None


def test_the_new_name_wins_and_a_duplicate_raises():
    with tmp() as d:
        root = os.path.join(d, "r")
        build(root, "old")
        _write(os.path.join(root, "schemas", "generated", "did_v2_coverage_ledger.json"), {})
        assert dsn.find_schema_file(root, "coverage_ledger.json").endswith(
            os.path.join("generated", "did_v2_coverage_ledger.json"))
        _write(os.path.join(root, "schemas", "did_v2_coverage_ledger.json"), {})
        try:
            dsn.find_schema_file(root, "coverage_ledger.json")
        except dsn.DuplicateSchemaFile as err:
            assert "2 files named did_v2_coverage_ledger.json" in str(err), err
        else:
            raise AssertionError("two did_v2_coverage_ledger.json did not raise")


def test_git_show_finds_a_moved_file_in_a_commit():
    if shutil.which("git") is None:
        print("NOT CHECKED: no git")
        return
    with tmp() as d:
        for layout in ("old", "new"):
            root = os.path.join(d, layout)
            build(root, layout)
            env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t",
                       GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
            for cmd in (["init", "-q"], ["add", "-A"], ["commit", "-qm", "x"]):
                subprocess.run(["git", "-C", root] + cmd, check=True, env=env)
            proc, git_path, _ = dsn.git_show_schema_file(root, "coverage_ledger.json")
            assert proc.returncode == 0, proc.stderr
            assert json.loads(proc.stdout) == {"file": "coverage_ledger.json"}
            want = "schemas/V_eta_coverage_ledger.json" if layout == "old" \
                else "schemas/generated/did_v2_coverage_ledger.json"
            assert git_path == want, git_path


if __name__ == "__main__":
    failures = 0
    tests = [(n, f) for n, f in sorted(globals().items())
             if n.startswith("test_") and callable(f)]
    for name, fn in tests:
        try:
            fn()
            print("ok   %s" % name)
        except Exception as err:  # noqa: BLE001
            failures += 1
            print("FAIL %s\n  %s: %s" % (name, type(err).__name__, err))
    print("\n%d test(s), %d failure(s)" % (len(tests), failures))
    sys.exit(1 if failures else 0)
