# DID Schema

## Schema outline

```
classname: "classname"
superclasses: {
"","",""
}

depends_on: {
  name1,value1;
  name2,value2;
  name3,value3;
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
| char | A charcter array | length |
| did_uid   | A DID UID | no parameters |

## Example document schema

```
classname: "ndi_document"
schema: "$MYPATHNAME/ndi_document.schema"
class_version: 1
superclasses: { # no superclasses
}

depends_on: {  # no depends-on
}

| id | did_uid | 12345 | 
| session_id | did_uid | 12345 |
| name | char | "" | 255 |
| datestamp | timestamp | "2018-12-05T18:36:47.241Z" | 
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
		"id":							"12345",
		"session_id":						"12345",
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

