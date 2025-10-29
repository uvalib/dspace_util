# DSpace Utilities

This repository contains utilities meant to be run on a developer workstation
to support the setup and maintenance of the DSpace instance holding the latest
version of the UVALIB open access repository.

Additionally, the "remote" directory contains utilities meant to be run from a
developer account on the DSpace host itself.

DSpace import requires a user account on the DSpace host with administrator
privileges.

## LibraOpen Export / DSpace Import

Code here supports the activity of transferring items from LibraOpen to DSpace,
in particular `dspace_import` which can perform the full end-to-end transfer.

The import process creates DSpace _entities_ rather than simply DSpace "items";
this includes:

* **Publication** entities corresponding to exported LibraOpen submissions.

* **Person** entities for each author listed in the LibraOpen submissions.

* **OrgUnit** entities for each department/institution associated with an
author or other contributor.

Because large quantities of data may be transferred, a local directory with
sufficiently large storage capacity should be set aside for the purpose of
gathering exports from LibraOpen and converting them to DSpace imports.
Programs here assume this directory can be found at the location defined as
\$COMMON_ROOT in `dspace_values`, along with the \$EXPORT_DIR and \$IMPORT_DIR
subdirectory names.

### Caveats

Ideally, all import entries could be bundled up into a single zip file which
could be passed to the `dspace import` script.
When this is the case then any new Person or OrgUnit entities that must be
created can be referenced relative to their import subdirectory within the
zip file.

However, there appear to be practical limitations to the number of items that
DSpace can successfully ingest at one time.
The ["Batch Metadata Editing"][CSV] page, regarding CSV imports, suggests
limiting batches to 1000 items.
Since this seems to apply to SAF imports as well, this guideline has been
embedded into `dspace_import_zip` logic so that attempting to import more than
1000 entities will result in the generation of multiple zip files which must
be imported in separate runs.

This approach presents a problem when Persons and/or OrgUnits have to be
created:
Relationships between entities cannot be referenced relative to the import zip
file because the same Person or OrgUnit may be required by item imports in two
or more zip files in the set.

The only safe strategy is to force all OrgUnit imports to be created first so
that the UUIDs of the newly-created OrgUnit entities can be used to create
relationships with Person imports.
Then all Person imports must be created next so that the UUIDs of the
newly-created Person entities can be used to create relationships with
Publication imports.

In-depth documentation of DSpace entities is sparse;
some insight into the implementation can be gleaned from the
["GitHub issue comments"][GIT].

### Steps

The `dspace_import` program orchestrates several steps implemented by other
programs implemented here in order to affect a transfer of LibraOpen data to
DSpace.

* First, `dspace_libra_export` acquires LibraOpen export into the \$COMMON_ROOT
  subdirectory referenced by \$EXPORT_DIR.

* Next, `dspace_import_zip` transforms \$EXPORT_DIR item subdirectories into
  DSpace import items within the \$COMMON_ROOT subdirectory referenced by
  \$IMPORT_DIR and then into one or more zip files whose names are prefixed
  with \$IMPORT_DIR.

* Finally, for each zip file `remote/bin/dspace_import`, running on the DSpace
  host, is invoked to run the DSpace command-line import.

### Phases

If there are a 1000 or less OrgUnits, Persons, and Publications to be imported
then the entire import can fit into a single zip file.
If this is the case, then a single run of `dspace_import` can be used to
perform the entire transfer.

If this is not the case, then imports will need to occur in three distinct
phases of running `dspace_import`.

Each subsequent run of `dspace_import` will rerun the `dspace_import_zip` and
remote `dspace_import` steps.
The `dspace_libra_export` step is skipped as long as the previously-downloaded
LibraOpen export directory is intact.

#### 1. Create OrgUnits

The initial run of `dspace_import` will determine all of the OrgUnits required
and cause them to be created in DSpace.

If you know that a phased approach is required, it is better to perform this
phase as `dspace_import --phase 1`.
This avoids spending time fetching the list of current Person entities which
will not be of any use in this phase.

Confirm that the OrgUnits have been created before going on to the next phase.
At this point, OrgUnit lookups in the next phase should be able to express
Person relationships to OrgUnits in terms of their UUIDs.

#### 2. Create Persons

Run `dspace_import --phase 2` to import Person entities not yet in DSpace.
The import process will perform relationship linkages to all of the OrgUnits
associated with those Persons.

Confirm that the Persons have been created before going on to the next phase.
At this point, Person lookups in the next phase should be able to express
Publication relationships to Persons in terms of their UUIDs.

#### 3. Create Publications

Run `dspace_import --phase 3` to create Publication entities in DSpace for each
of the exported items.
The import process will perform relationship linkages to all of the Persons
associated with those Publications.

### Failure Recovery

For a number of reasons, often because of problems encountered in the DSpace
command line application itself, a batch import may fail.
This can lead to a situation in which one or more sets of items from a multiple
zip file import have been successfully submitted and the remainder have not.

DSpace import is not idempotent -- attempting to resubmit a
previously-submitted entity will simply result in a duplicate entity.
So, steps must be taken to avoid importing the previously-imported entities.

The strategy is to make use of the map files that "dspace import" creates which
list each import subdirectory alongside the handle of the DSpace item created
for it.
These map files can be copied from the DSpace host back to the development
machine and supplied as arguments to indicate which imports should _not_ be
included in the next run.

For example, say that you have 2500 exports to submit, and have already gone
through the phases to create OrgUnits and Persons associated with them.
The third and final import phase causes three zip files to be submitted, and 
the first two 1000-item zip files have been successfully processed to create
Publication entities, but the final 500-item zip file fails.

In this case, copy the records of the successful submissions to the project's
temporary directory with:

```bash
bin/dspace_cp_from import/dspace-import-1.map import/dspace-import-2.map ./tmp
```

Then make use of them to re-process exports to generate a single zip file which
will cause the rest of the items to be imported:

```bash
bin/dspace_import --retry --phase 3 --skip tmp/dspace-import-1.map --skip tmp/dspace-import-2.map
```

This will regenerate the local import directory to contain only the non-skipped
items, resulting in a zip file through which only the remaining
(previously-failed) items are imported into DSpace.

## Developer Desktop Utilities

Scripts from the "bin" directory are meant to be run on a developer
workstation.

Note that all scripts assume that AWS Command Line utilities have been
installed and are available in the current \$PATH.

All of the scripts except `dspace_libra_export` accept a deployment option to
specify the target DSpace host:

* Staging host:    "--staging"    or "--deployment=staging"
* Production host: "--production" or "--deployment=production"

The default deployment is "production".

<!---------------------------------------------------------------------------->

### `.values`

This is an optional script that can be created to provide local default values.
In particular, the default deployment can be set there with the line

```bash
[[ "$DSPACE_DEPLOYMENT" ]] || export DSPACE_DEPLOYMENT='staging'
```

<!---------------------------------------------------------------------------->

### `dspace_values`

This provides common definitions for all of the scripts, including default
values for environment variables.
(It "sourced" by the scripts and is not intended to be executed directly.)

All defaults can be overridden locally within an optional `bin/.values` script,
particularly for sensitive information that should not be pushed to GitHub
along with this project's source code.

<!---------------------------------------------------------------------------->

### `dspace_sh`

Run a command on the DSpace host.

With no command argument, this opens an interactive shell on the remote system.

#### Options

All flags are passed to the `ssh` program except for the following:

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_cp`

Copy files to or from the DSpace host.

The last argument indicates the direction:
* If it begins with ":" or "scp:" then it is interpreted as the remote
    destination directory and all prior arguments are interpreted as local
    source files and/or directories.
* If it is "." or "..", or begins with "./", "../" then it is interpreted as
    the local destination directory and all prior arguments are interpreted as
    remote source files and/or directories.

#### Options

All flags are passed to the `scp` program except for the following:

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --to

Copy to the DSpace host.

All arguments are interpreted as local source files and/or directories which
will be copied to the home directory of the remote account.

The script `dspace_cp_to` executes `dspace_cp --to`.

##### --from

Copy from the DSpace host.

All arguments are interpreted as remote source files and/or directories
relative to the home directory of the remote account which will be copied to
the local current working directory.

The script `dspace_cp_from` executes `dspace_cp --from`.

<!---------------------------------------------------------------------------->

### `dspace_org`

Get information about DSpace OrgUnit entities in tabular form.

Each argument may be a department name or an OrgUnit handle.
With no arguments, all OrgUnits are listed.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --scope

Limit search to the indicated collection.

##### --fast

Used saved data if possible.

<!---------------------------------------------------------------------------->

### `dspace_person`

Get information about DSpace Person entities in tabular form.

Each name argument may be a computing ID, a last name, a first and last name
surrounded by quotes, or a "last, first" name in bibliographic order.
With no arguments, all Persons are listed.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --scope

Limit search to the indicated collection.

##### --fast

Used saved data if possible.

<!---------------------------------------------------------------------------->

### `dspace_publication`

Get information about DSpace Publication entities in tabular form.

Each name argument may be "author:AUTHOR_NAME", "title:TITLE_TEXT", or a
handle.
(A string without a prefix is assumed to be TITLE_TEXT.)
With no arguments, all Publications are listed.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --scope

Limit search to the indicated collection.

##### --fast

Used saved data if possible.

<!---------------------------------------------------------------------------->

### `dspace_collection`

Get information about DSpace collections in tabular form.

This does not currently take arguments.
With no arguments, all collections are listed.

### `dspace_delete`

Remove DSpace items by name or collection.

Items may be provided as handle value(s) on the command line, provided through
a "--mapfile", or specified by a "--collection".
Note that the collection will have its constituent items removed but the
collection itself will need to be removed through the DSpace UI.

### `dspace_lookup`

Get JSON details of a DSpace item.

The item may be a collection, however DSpace only returns metadata about the
collection itself and does not provide a way to get the items associated with
the collection.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_solr`

Open the DSpace Solr admin page on a local browser, creating an ssh tunnel if
necessary.

The tunnel will persist in the background after the command is done.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_solr_export`

Retrieve DSpace Solr search records.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_update_home`

A convenience script for copying the files of "remote/bin" to the user's DSpace
home ~/bin directory.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_restart`

Restart DSpace with updated configuration from either
[production/ansible/config/dspace](https://github.com/uvalib/terraform-infrastructure/dspace.library.virginia.edu/production/ansible/config/dspace)
or
[staging/ansible/config/dspace](https://github.com/uvalib/terraform-infrastructure/dspace.library.virginia.edu/staging/ansible/config/dspace)
from the local copy of terraform-infrastructure on the developer workstation.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_retheme`

Restart DSpace UI with updated configuration from
https://github.com/uvalib/dspace_theme
.
(Both "staging" and "production" have the same UI configuration.)

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

<!---------------------------------------------------------------------------->

### `dspace_import`

This script performs
`bin/dspace_libra_export` to acquire exports from LibraOpen,
`bin/dspace_import_zip` to generate import zip file(s),
copies the zip file(s) to the remote system,
and then runs a copy of `remote/bin/dspace_import` on the remote system to
import items into DSpace.

Note that, because this script requires support on the DSpace host side,
it will run `dspace_update_home` for you in order to ensure that the remote
side is up-to-date.

#### Options

All options are passed to the local `bin/dspace_import_zip` script except for
the following:

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --retry

While normally the script guards against overwriting an existing import
directory or import zip files(s),
using this option allows them to be removed before proceeding.
This can be used as an alternative to manually clearing out these intermediate
files before running the script.

##### --force

While normally the script makes use of the contents of an existing LibraOpen
export directory, using this option forces the acquiring of fresh LibraOpen
exports.

##### --start DATE

Passed to `bin/dspace_libra_export`.

This option will cause LibraOpen exports to be acquired which were created on
or after the given date.
This only applies if the export directory is empty or does not exist;
otherwise this option has no effect unless the "--force" option is supplied in
order to force a new export/import sequence.

##### --eperson

Passed to `remote/bin/dspace_import`.

Entities are normally created with "dc.description.provenance" indicating that
it was submitted by "Import Owner (libra@virginia.edu)".
If there was a compelling use-case for indicating a different submitting user,
this would be the option to use to cause that to happen.

##### --collection

Passed to `remote/bin/dspace_import`.

This should probably not be used since imported entities are generated with a
"collections" file which specifies the appropriate collection depending on the
nature of the entity (Publication, Person, or OrgUnit).
Due to the way that the DSpace command line works, specifying a collection will
mean that _all_ imported entities will be placed into that collection
(which is probably not desirable for OrgUnit and Person entities).

<!---------------------------------------------------------------------------->

### `dspace_import_zip`

This is a program for generating a zip file containing a hierarchy import items
adhering to ["DSpace Simple Archive Format"][SAF] from a local directory
hierarchy of export items from LibraOpen in the \$EXPORT_DIR directory.

Normally, the program creates a single zip file "\$IMPORT_DIR.zip" unless
--batch-size or --batch-count is given.
In these cases, one or more zip files are created named "\$IMPORT_DIR-nnn.zip"
where "nnn" is a zero-filled number.
(Run `bin/dspace_import_zip --help` for all options.)

The resulting zip file(s) can be copied to DSpace for use with the remote
dspace_import script to bulk submit the items to DSpace.

#### Options

##### --production | --staging

Indicate the target DSpace host.
(The default is taken from the DSPACE_DEPLOYMENT environment variable.)

##### --record RECORDS

List of records to extract.

##### --skip RECORDS

List of records to ignore.

##### --phase N

Import phase to perform.

##### --max-records N

Only process N exports.

##### --batch-count N

Split output into N zip files.

##### --batch-size N

Make zip files of size N.

##### --fast

Use saved org and person data where possible.

##### --no-fetch

Avoid acquiring data which would prevent import because the intended import
already appears to have happened.

NOTE: This is a questionable feature and may be removed or revamped.

#### Prerequisites

The program assumes that the Ruby version indicated by ".ruby-version" is
installed via `rvm` with a gemset named by ".ruby-gemset".

<!---------------------------------------------------------------------------->

### `dspace_libra_export`

This script generates "libra-open-export" in the current directory by 
executing Ansible playbooks which run `rake libraoc:export:export_works`.

Note that the intermediate destination is a shared resource also used by the
LibraOpen APTrust bagger.
If that task is currently running this script should **not** be run at the same
time.

This script does not accept a deployment option since it does not directly
involve any DSpace instance.

#### Options

##### --force

Replace the target output directory.

##### --common DIR_PATH

Root directory of the output directory.

##### --export DIR_NAME

Name of the output directory.

##### --start DATE

Get LibraOpen exports created on or after the given date.

#### Prerequisites

This script requires

* ccrypt
* terraform
* ansible-playbook

These are expected to be installed on the local workstation and available in
the current \$PATH.

<!---------------------------------------------------------------------------->

## DSpace Host Utilities

Scripts from the "remote/bin" directory are meant to be copied to the
developer's account directory on the DSpace host in "\$HOME/bin"
(which can be accomplished with `dspace_update_home`).

### `dspace`

Run a DSpace command as user "dspace".

### `dspace_export`

Export DSpace item records.

### `dspace_solr_export`

Retrieve DSpace Solr search records.

### `dspace_import`

Takes a zip file (generated via `dspace_import_zip` on the local development
machine) and submits the items to DSpace in bulk.

The DSpace import process is rather slow and happens in several phases:
* First, items are extracted from the zip file into a subdirectory created
    under `/opt/dspace/imports/importSAF`.
* This expanded data is used to create data for each item.
* Items are submitted to the Solr index.
* Finally, the items will appear in the DSpace UI in the target collection.

Imported items will only appear in DSpace if all phases are completed.
Failure of any item will result in failure of all items to be submitted.

Although there is no stated limit on the size of valid bulk submissions,
there can be problems with submitting a large number of items, and those
problems may not necessarily result in log errors to help identify the problem.

The ["Batch Metadata Editing"][CSV] page, regarding CSV imports, suggests
limiting batches to 1000 items.
While this may or may not apply to SAF imports, it might be wise to break
large bulk submissions into batches.

This command can be run manually on the DSpace host, however it may be
preferable to run the entire end-to-end LibraOpen-export-to-DSpace-import
process from the local development machine through the `dspace_import` command.

<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF --------- LINK -------------------------- TOOLTIP ------------------------>
[GIT]:        https://github.com/DSpace/DSpace/pull/3322
[CSV]:        https://wiki.lyrasis.org/display/DSDOC8x/Batch+Metadata+Editing
[SAF]:        https://wiki.lyrasis.org/display/DSDOC8x/Importing+and+Exporting+Items+via+Simple+Archive+Format
