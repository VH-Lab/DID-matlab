# `ndi_document.json`, every vintage, VERBATIM FROM NDI's OWN HISTORY

These five files are `ndi_common/database_documents/ndi_document.json` as NDI
actually shipped it, byte for byte, at the five commits that changed it. They
are NOT hand-written, and they are NOT derived from any DID-side schema.

That distinction is the reason the directory exists. This repository has been
bitten repeatedly by fixtures built from a docstring, an assumed shape or our
own schema instead of from the writer — `distance_metadata`'s ~2078 quarantines
came from a migrator written against a nested `endpoints` block that no real
document has, and its unit test passed because the fixture was built from the
same assumption as the code. A test written from the same premise as the code
cannot catch the code. So the vintage classifier in
`did2.convert.universalRenames` is tested against these bytes.

## How they were obtained

    $ cd NDI-matlab
    $ git log --all --oneline --follow -- ndi_common/database_documents/ndi_document.json
    9783809c2 database document definitions all changed          <- DELETED here
    6529ce7bf added document2markdown to make ndi_document documentation
    0d5749926 added field to ndi_document classes (property_list_name) ...
    f6d4e0ec6 Update ndi_document.json
    e8c02831d changed experiment to session
    f4f9d9450 many changes to documents, everything is certainly broken right now
    5d0b66d8f change "reference"/"identifier" to "id"
    4f1a2b801 changed NSD to NDI; tested many things but still might little errors
    7b080dca1 todo: test adding documents to database and read/write binary files ...
    f45bcc82c so many renames and moving
    830fb373b totally redid nsd_document

    $ for c in 4f1a2b801 5d0b66d8f f4f9d9450 e8c02831d 6529ce7bf; do
          git show $c:ndi_common/database_documents/ndi_document.json > $c.json
      done

## What each one is

| file | date | block field set | identity after a wholesale move into `base` |
|---|---|---|---|
| `4f1a2b801.json` | 2019-05-05 | `experiment_unique_reference`, `document_unique_reference`, `name`, `type`, `datestamp`, `database_version` | **NEITHER** `id` nor `session_id` |
| `5d0b66d8f.json` | 2019-11-04 | `experiment_id`, `document_id`, `name`, `type`, `datestamp`, `database_version` | **NEITHER** |
| `f4f9d9450.json` | 2019-12-16 | `experiment_id`, `id`, `name`, `type`, `datestamp`, `database_version` | `id` lands; `session_id` does **not** |
| `e8c02831d.json` | 2020-05-19 | `session_id`, `id`, `name`, `type`, `datestamp`, `database_version` | **BOTH land — the move is SOUND** |
| `6529ce7bf.json` | 2020-12-01 | *(same six names, `id` and `session_id` swapped in the JSON)* | **BOTH land** |

## The two things that are easy to get wrong here

**FOUR shapes, not five.** `6529ce7bf` renames nothing: it reorders `id` and
`session_id` inside the block. As a FIELD SET it is the 2020-05-19 vintage, and
it is checked in precisely so a test can prove the classifier is insensitive to
field order. Any classifier that keyed on position would split one vintage in
two.

**Two consecutive pairs differ by ONE field name.** `experiment_id` vs
`session_id` separates 2019-12 from 2020-05; `document_id` vs `id` separates
2019-11 from 2019-12. So no single-field test can name a vintage, which is why
the classifier compares sorted field sets.

`f6d4e0ec6` and `0d5749926` are not checked in: both add `property_list_name`
to the `document_class` block and leave the `ndi_document` block untouched, so
neither changes the field set this classifier reads. `830fb373b`, `f45bcc82c`
and `7b080dca1` predate the NSD→NDI rename; their block key is `nsd_document`,
which cannot reach the `ndi_document` arm at all.

`9783809c2` (2023-04-13) DELETES `ndi_document.json` and ADDS `base.json`:

    {
        "base": {
            "id": "", "session_id": "", "name": "", "datestamp": ""
        }
    }

Four fields — no `type`, no `database_version`. That is why even the sound
2020-vintage move still arrives with two undeclared fields.
