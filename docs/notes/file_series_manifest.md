# File series manifest, format version 1

A **file series** is a `name_#` entry in a document's `file_list` whose members
are indexed by a manifest rather than by one `file_info` struct each. The
manifest is a single binary file belonging to the document.

See VH-Lab/DID-matlab#173 for why this exists. In short: a tiled image pyramid
level is ~28,000 files, and one `file_info` struct per member is ~8-11 MB of
JSON in a document blob that is returned whole on every read.

## Layout

All integers are **little-endian**. Offsets and member indices are
**zero-based**.

| offset | field | type | count | notes |
|---|---|---|---|---|
| 0 | `magic` | char | 8 | `DIDFSER1` |
| 8 | `format_version` | uint32 | 1 | 1 |
| 12 | `flags` | uint32 | 1 | bit 0: source names present |
| 16 | `count` | uint32 | 1 | number of member slots, `N` |
| 20 | `uid_width` | uint32 | 1 | bytes per uid record |
| 24 | `reserved` | uint32 | 2 | zero |
| 32 | `uids` | char | `N * uid_width` | member `i` at `32 + i*uid_width` |

Then, **only when `flags` bit 0 is set**:

| field | type | count | notes |
|---|---|---|---|
| `name_offset` | uint32 | `N + 1` | zero-based, into `name_bytes` |
| `name_bytes` | uint8 | `name_offset(N)` | UTF-8, concatenated, unterminated |

The source name of member `i` is `name_bytes(name_offset(i) : name_offset(i+1))`
in zero-based half-open terms. An empty range means that member has no recorded
name.

## Why uids are fixed-width text, not packed

`did.ido.unique_id` returns `num2hex(serialDate) '_' num2hex(rand)` — exactly 33
characters, which would pack losslessly into 16 bytes. **That packing is not
safe in general.** A uid is only *minted* by `unique_id`; a document read from
JSON written elsewhere may carry any string `did.file.isSafeUid` accepts, and
16-byte packing would silently corrupt it.

So uids are stored as fixed-width text at the width the header declares, and a
uid wider than `uid_width` is an **error at write time** rather than a silent
truncation. Current uids give `uid_width = 33`, so 28,000 members cost 924 KB —
against ~8-11 MB of JSON for the same members, and read only on demand.

`uid_width` being a header field rather than a constant is deliberate, following
the `data_type_*` discipline of the spatial gene pyramid: a packed encoding can
be added later as a new `flags` bit without a format-version bump.

## Absent members

A series is sparse: not every index exists. A zarr level never writes a chunk
that is entirely fill value, and the pyramid is built to match.

An absent member's uid record is **all NUL bytes**. `isSafeUid` rejects NUL, so
no real uid can collide with the sentinel. Absent members are the reason the uid
array is dense-with-sentinel rather than a list of pairs: for a chunk grid where
most members exist, dense is both smaller and O(1) to index.

## Source names, and what is deliberately not stored

The optional name section holds each member's source path **relative to the
series' `source_root`**, which lives on the document, not here.

Absolute paths are not stored. A full path leaks an individual's directory
layout as soon as a document is shared, and 28,000 embedded copies of a home
directory is the worst shape for that; keeping the root in one document field
means a sharer redacts one string instead of scrubbing the manifest. It is also
smaller — relative names cost roughly a sixth of absolute ones.

A bare basename would not do either: a zarr chunk lives at `<store>/0/0.1.2.3`,
so the name alone loses which level it came from. Relative names keep the
subfolder structure that makes them meaningful.
