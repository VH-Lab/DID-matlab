Corpus failure fixtures.

Each folder <NAME>/ holds v1 documents that tools/extract_failure_fixtures.py
lifted out of a corpus run's report: the documents that quarantined,
fragmented, orphaned or left a required edge empty, plus every document they
reference (depends_on, transitively) in the same session, plus that session's
`session` document. <NAME>.manifest.json beside the folder records which run,
which report rows and which ids, including any id that could not be mapped to
a v1 document.

did2.unittest.testFailureFixtures runs every folder here through the same
driver as the corpus tests (runCorpusDiscovery) on the quick gate and asserts
0 quarantine, 0 fragments, 0 empty required edges and 0 orphans. A folder is
committed to reproduce a failure in minutes; it is deleted, or kept as a
regression fixture, once the fix lands.

The manifests are kept OUTSIDE the folders because the driver reads every
*.json in a folder as a v1 document.
