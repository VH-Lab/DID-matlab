# Q: What should be part of DID document core fields, and what should be JSON-style parameter data?

**Core fields**:

| Property | description | datatype | comments | 
| --- | --- | --- | --- |
| `base.id` | A globally unique identifier for the document | `did_id string` | Once made, this never changes; even if version is updated. |
| `base.session_id` | A globally unique identifier for the experimental session | `did_id string` |  Once made, this never changes; even if version is updated. |
| `base.name` | A string name for the user | ASCII string | Does not need to be unique. The id, session_id, and version confer uniqueness. (Some subtypes may have conditions for name uniqueness; for example, daq_systems must have a unique name. But this is not a database-level requirement.)|
| `base.datestamp` | Time of document creation or modification (that is, it is updated when version is updated) | ISO-8601 date string, time zone must be UTC leap seconds | Human readable. | 
| `base.version` | Version of database document | `did_id string` | This probably needs to be an `did_id string` to help with merging branches where 2 users have modified the same database entry (otherwise, might have two copies of "n+1" that need to be dealt with); `did_id string`s sort by time alphabetically, so the time would be a means of differentiating them | 
| `depends_on` | Lists all documents that this document "depends_on" | An array of structures with entries `name` and `ID` and `version` | Name is an internal reference for programs using the documents. "ID" and "version" uniquely identify the document that is depended on | 
| `class.definition` | JSON_definition_location of the definition for this document | | |
| `class.validation` | JSON_schema_location of the schema validation for this document | | |
| `class.name` | Name of this document class | | 
| `class.property_list_name` | String that describes the Property list that is provided by this class | JSON property name string |
| `class.schema_version` | Version of this class definition (schema) | Version number | 
| `class.superclasses`| Array of definition and versions of superclasses | An array of structures with entries `definition` and `schema_version` | Contains the NDI_definition strings and schema versions of all superclasses|
| `properties` | JSON string with the other properties of the document | JSON string | Must have field class.property_list_name for this class and all super classes |


## Document construction:

Documents are built from instructions in JSON files. Consider the following pair of files:

```
{
	"document_class": {
		"definition":						"$DIDDOCUMENTPATH\/base_document.json",
		"validation":						"$DIDSCHEMAPATH\/base_document_schema.json",
		"class_name":						"base_document",
		"property_list_name":					"base_document",
		"class_version":					1,
		"superclasses": [ ]
	},
	"base_document": {
		"id":                            			"",
		"session_id":						"",
		"name":							"",
		"type":							"",
		"datestamp":						"2018-12-05T18:36:47.241Z",
	}
}
```

and

```
{
	"document_class": {
		"definition":						"$NDIDOCUMENTPATH\/ndi_document_app.json",
		"validation":						"$NDISCHEMAPATH\/ndi_document_app_schema.json",
		"class_name":						"ndi_document_app",
		"property_list_name":					"app",
		"class_version":					1,
		"superclasses": [
			{ "definition":					"$NDIDOCUMENTPATH\/base_document.json" }
		]
        },
	"app": {
		"name":							"",
		"version":						"",
		"url":							"",
		"os":							"",
		"os_version":						"",
		"interpreter":						"",
		"interpreter_version":					""
	}
}
```

## Representation of documents in Matlab / Python / other languages

When loaded from the database, the DID_DOCUMENT object should have a property (structure or dictionary or struct) with the following fields:

```
document_properties.
   base.
      id: '412685ecea57f3f1_3fc78a4a58138ac0'
      session_id: '4126855fc3f91b22_3fe305de4e869235'
      name: 'manually_selected t00012'
      type: ''
      datestamp: '2020-09-04T14:59:05.478Z'
      database_version: 1
   class.
      definition: '$NDIDOCUMENTPATH/ndi_document_app.json'
      validation: '$NDISCHEMAPATH/ndi_document_app.json'
      class_name: 'ndi_document_app'
      property_list_name: 'spike_extraction_parameters'
      class_version: 1
      superclasses(1).definition: '$DIDDOCUMENTPATH/did_document.json'
      superclasses(1).version: 1
   depends_on.  % 0x1 structure
      name: <no entry>
      id: <no entry>
      version: <no entry>
   app.
      name: 'ndi_app_spikeextractor'
      version: '6330a4f35cdce37b5b200d2b5c7cbea25ae356a9'
      url: 'https://github.com/VH-Lab/NDI-matlab'
      os: 'MACI64'
      os_version: '10.14.6'
      interpreter: 'MATLAB'
      interpreter_version: '9.8'  
```

## did_id string

The `did_id string` is an ID constructed out of two 64-bit numbers expressed in hexidecimal with a '_' in between. It is built as

```
serial_date_number = convertTo(datetime('now','TimeZone','UTCLeapSeconds'),'datenum');
random_number = rand + randi([-32727 32727],1);
id = [num2hex(serial_date_number) '_' num2hex(random_number)];
```

 in Matlab. Serial date is the date from January 0, 0000, in UTC leap time. The integer part of the number is the number of days, while the fractional part is the fractional number of days elapsed.

## Core Functions

### Adding documents

- The database itself takes `DID_document` objects as inputs. `DID_document` classes can be created by JSON string that encodes the property structure of the database. The `DID_document` object class can take the `base`, `class`, and `depends_on` structures as defined by its API (JSON or alternate inputs).

### Removing documents

_add text here_

### Searching

_add text here about `ndi_query` or `did_query`_

### Committing

_add text here_

## Database Meta-behavior:

- One has one database open for "writing" at a time, where documents can be added or removed and databases committed. But the database can have additional databases connected for searches to propagate across the list to find all matches. 
- Each database has a "commit" number; this can be "none" before committing starts or a unique identifier of a specific commit (`did_id`) or "latest". The current commit number and the tables of all pasts commits (commit number with ids and version numbers) must be stored in the database.
- If a document is deleted, its dependencies must be deleted, too. Once a database is "crystallized / committed", then deleting the document just removes it and all its dependent-documents from the current changes. (They won't show up in searches or document requests.)

## Discussion:

- **Cross-database reference**: How to do it best? Referencing isn't the problem, but resolving links is.
- **When do we validate?**: On adding to the database? At another step, such as adding to an archive-level database?
- **Dependencies**: How to handle situation where a document that another document depends on is updated to a new version? Probably: it just won't exist in the new commit.
- **User-created documents**: If a user creates a document class and make a permissive validator, is there any concern that he/she could fill a database with something dangerous? Clearly, they could fill their own database with garbage, but could they fill other people's databases with garbage? I can't think of a way that they could. An archive could require that the document type and schema be part of a particular distribution.
