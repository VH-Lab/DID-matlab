# DID Schema

## Schema outline

```
classname: "classname"
superclasses: {
"","",""
}

depends_on: {
  name1,uid1;
  name2,uid2;
  name3,uid3;
}

file: {
  name1,location;
  name2,location;
  name3,location;
}

| fieldname1 | type | default_value | size, range parameters | queryable |
| fieldname2 | type | default_value | size, range parameters | queryable |
structure "structurename1" {
| fieldname1 | type | default_value | size, range parameters | queryable |
| fieldname2 | type | default_value | size, range parameters | queryable |
}
structure "structurename2" {
| fieldname1 | type | default_value | size, range parameters | queryable |
| fieldname2 | type | default_value | size, range parameters | queryable |
}

```

## Rules

\# indicates that the rest of the line is a comment.

fieldnames and structure names can be any alphanumeric character but can only have a at most two '__' characters in a row. It may not begin with a number but must begin with a letter.

`type` can be:

| type name | description | parameter string details |
| --- | --- | --- | 
| structure  | Begins a structure inside curly braces { } | (no parameter string)
| integer | Integer (single value) | should be MINVALUE, MAXVALUE, NANOKAY, where NANOKAY is 1 if NaN values are okay |
| double | Double precision value | MINVALUE, MAXVALUE, NANOKAY, where NANOKAY is 1 if NaN values are okay |
| matrix | Double precision matrix | ROWS, COLUMNS (the number of rows and the number of columns in the matrix |
| timestamp | A timestamp in UTC | no parameters |
| char | A character array | length |
| did_uid   | A DID UID | no parameters |

`superclasses` lists the superclasses by the locations of their schema files.

`depends_on` lists the database documents that this document depends on; if any of the documents that this document depends on
are deleted, then this document is deleted, too. Each `depends_on` field has a name as well as the UID of the document that
satisfies that dependency.

`file` is a list of file names (alphanumeric characters and '_' only) that are associated with the document. The location of the
file is provided as well; this could be a full path filename on disk, a path relative to the database location, or some other
reference. It is never opened directly by the user, it is opened with `did.database.openbinaryfile()`.

## Example document schema

```
classname: "ndi_document"
schema: "$MYPATHNAME/ndi_document.schema"
class_version: 1
superclasses: { # no superclasses
}

depends_on: {  # no depends-on
}

#| fieldname   | type      | default_value                     | parameters             | queryable |
#| ----------- | --------- | --------------------------------- | ---------------------- | --------- |
 | id          | did_uid   | 41268a59896f1419_40b33bf4c53bb4dd |                        |    1      |
 | seesion_id  | did_uid   | 41268a5989e22f71_c0d0f3fc2c926c85 |                        |    1      |
 | name        | char      | ""                                | 255                    |    1      | 
 | datestamp   | timestamp | "2018-12-05T18:36:47.241Z"        |                        |    1      |
```

This code should internally produce the equivalent of the following structure (here represented in JSON):

```
{
	"document_class": {
		"definition":						"$MYPATHNAME\/ndi_document.schema",
		"class_name":						"ndi_document",
		"property_list_name":					"ndi_document",
		"class_version":					1,
		"superclasses": [ ]
	},
	"ndi_document": {
		"id":							"41268a59896f1419_40b33bf4c53bb4dd",
		"session_id":						"41268a5989e22f71_c0d0f3fc2c926c85",
		"name":							"",
		"datestamp":						"2018-12-05T18:36:47.241Z",
	}
}

```


Functions needed:

```
DIDschema2JSON
DIDschema2Sqlinfo (Column names)
Struct2SqlInfo (input: struct, output: col_names, col_values)
```

