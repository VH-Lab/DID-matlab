# did_document_subject (did.document class)

## Class definition

**Class name**: [did_document_subject](did_document_subject.md)<br>
**Superclasses**: [base](base.md)

**Definition**: [$DIDDOCUMENT_EX1/did_document_subject.json](did_document_subject.json)<br>
**Schema for validation**: [#DIDSCHEMA_EX1/did_document_subject_schema.json](did_document_subject_schema.json)<br>
**Property_list_name**: `subject`<br>
**Class_version**: `1`<br>

## [did_document_subject](did_document_subject.md) fields:

Accessed by `subject.field` where *field* is one of the field names below

| field | default value | data type | description
| -- | -- | -- | --| 
|local_identifier| - | A globally unique identifier that is meaningful to a local group | The identifier is usually constructed by concatenating a local identifier with the name of the group, such as `mouse123@vhlab.org`|
|description| "" | character string (ASCII) | A character string that is free for the user to choose |

## [base](base.md) fields:

Accessed by `base.field` where *field* is one of the field names below

| field | default value | data type | description
| -- | -- | -- | --| 
|id| - | DID ID string | The globally unique identifier of this document
|session_id| - | DID ID string | The globally unique identifier of any data session that produced this document
|name| "" | character array (ASCII) | A user-specified name, free for users/developers to use as they like
|datestamp| (current time) | ISO-8601 date string, time zone must be UTC leap seconds | Time of document creation
| document_version | - | character array (ASCII) | Version of this document in the database


