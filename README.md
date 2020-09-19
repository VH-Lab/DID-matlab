# DID-matlab
Data Interface Database

The purpose of this package is to provide an interface to database implementations that provides:

1. Documents that have a JSON-based metadata portion and binary portions
2. The ability to switch among various database implementations (such as Postgres, MongoDB, sqlite, a custom system, or new systems) without changing the API.
3. The ability to enforce a schema on the metadata portion of the documents
4. The ability to search document metadata fields without needing compiled object code for each document type
5. The ability to build JSON-based metadata objects from user-specified class descriptions (with subclasses and superclasses)

Later, we will add:

6. The ability to provide version control with commits




We are just getting started. For now, the only thing that works is:

```
did.test.test_did_document()
```
