# DID-matlab: Data Interface Database
[![codecov](https://codecov.io/gh/VH-Lab/DID-matlab/branch/main_v080_refactor/graph/badge.svg?token=K6D3LWXUGJ)](https://codecov.io/gh/VH-Lab/DID-matlab)

The purpose of this package is to provide an interface to database implementations that provide:

1. Database "documents" that have a JSON-based metadata portion and binary portions
2. The ability to build these JSON-based metadata portions from user-specified class descriptions (with subclasses and superclasses)
3. The ability to switch among various database implementations (such as Postgres, MongoDB, sqlite, a custom system, or new systems) without changing the API.
4. The ability to enforce a schema on the metadata portion of the documents
5. The ability to search document metadata fields without needing compiled object code for each document type

Later, we will add:

6. The ability to provide version control with commits

This is a rebuild of a database that was built for the Neuroscience Data Interface and we are just getting it off the ground. For now, the only thing that works is:

```
did.test.test_did_document()
```

## Installation

Options:

- [DID-matlab](https://github.com/VH-Lab/DID-matlab) is installed automatically with the [NDI-matlab installer](https://github.com/VH-Lab/NDI-matlab/wiki/Installation-Guide) or with the [vhlab_vhtools intaller](https://github.com/VH-Lab/vhlab_vhtools/wiki/Installation). Installing either will install [DID-matlab](https://github.com/VH-Lab/DID-matlab) and set it up. 
- You can also install manually with git.
    1. In a terminal (not in the Matlab command line), change to the directory where you want to install [DID-matlab](https://github.com/VH-Lab/DID-matlab). Usually this is Documents/MATLAB from the home directory (e.g., on a Mac, at `/Users/username/Documents/Matlab`).
    2. Running the following command: `git clone http://github.com/VH-Lab/DID-matlab` .
    3. Make sure to add DID-matlab to your path on the Matlab command line: `addpath(genpath([PATHNAME_TO_DIDMATLAB]))`.

Test your installation by running `did.test.test_did_document()` on the command line.
