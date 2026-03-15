# DID Symmetry Make Artifacts

This folder contains MATLAB unit tests whose purpose is to generate standard DID artifacts for symmetry testing with other DID language ports (e.g., Python).

## Rules for `makeArtifacts` tests:

1. **Artifact Location**: Tests must store their generated artifacts in the system's temporary directory (`tempdir`).
2. **Directory Structure**: Inside the temporary directory, artifacts must be placed in a specific nested folder structure:
   `DID/symmetryTest/matlabArtifacts/<namespace>/<class_name>/<test_name>/`

   - `<namespace>`: The last part of the MATLAB package namespace. For example, for a test located at `tests/+did/+symmetry/+makeArtifacts/+database`, the namespace is `database`.
   - `<class_name>`: The name of the test class (e.g., `buildDatabase`).
   - `<test_name>`: The specific name of the test method being executed (e.g., `testBuildDatabaseArtifacts`).

3. **Persistent Teardown**: The generated artifacts and the underlying DID database must persist in the temporary directory so that the Python test suite can read them. To achieve this, you must explicitly override any superclass test teardown methods to do nothing.

4. **Artifact Contents**: Each test should produce:
   - The SQLite database file itself.
   - One JSON audit file per branch, containing all documents in that branch. Each file should be named `branch_<branchName>.json` and placed in a `jsonBranches` subdirectory.
   - A `metadata.json` file describing the database structure (branch hierarchy, document counts, etc.).

5. **Deterministic Seeds**: Tests should use `rng('default')` so that the random document/branch generation is reproducible across runs.

## Example:
For a test class `buildDatabase.m` in `tests/+did/+symmetry/+makeArtifacts/+database` with a test method `testBuildDatabaseArtifacts`, the artifacts should be saved to:
`[tempdir(), 'DID/symmetryTest/matlabArtifacts/database/buildDatabase/testBuildDatabaseArtifacts/']`
