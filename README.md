# DSpace utilities

This repository contains utilities meant to be run on a developer workstation
to support the setup and maintenance of the DSpace instance hosting the latest
version of the UVALIB open access repository.

Additionally, the "remote" directory contains utilities meant to be run from a
developer account on the DSpace instance itself.

DSpace import requires a user account on the DSpace instance with administrator
privileges.

## Libra Export / DSpace Import

Code here supports the activity of transferring items from LibraOpen to DSpace,
in particular `dspace_import` which performs the full end-to-end transfer.

Because large quantities of data may be transferred, a local directory with
sufficiently large storage capacity should be set aside for the purpose of
gathering exports from LibraOpen and converting them to DSpace imports.
Programs here assume this directory can be found at the location defined as
$COMMON_ROOT in `dspace_values`, along with the $EXPORT_DIR and $IMPORT_DIR
subdirectory names.

The `dspace_libra_export` program acquires LibraOpen export into the
$COMMON_ROOT subdirectory referenced by $EXPORT_DIR.

The `dspace_import_zip` program transforms $EXPORT_DIR item subdirectories into
DSpace import items within the $COMMON_ROOT subdirectory referenced by
$IMPORT_DIR and then into one or more zip files whose names are prefixed with
$IMPORT_DIR.

The `dspace_import` program will acquire export from LibraOpen via
`dspace_libra_export` unless exports already exist in $EXPORT_DIR.
It then runs `dspace_import_zip`, transfers the resulting zip files to the user
account on the remote DSpace system, and runs the remote `dspace_import` on
them to import the zipped items into DSpace.

## Developer desktop utilities

Scripts from the "bin" directory are meant to be run on a developer
workstation.

Note that all scripts assume that AWS Command Line utilities have been
installed and are available in the current $PATH.

### dspace_sh

Run a command on the DSpace instance.

With no command argument, this opens an interactive shell on the remote system.

### dspace_cp

Copy files to or from the DSpace instance.

The last argument indicates the direction:
* If it begins with ":" or "scp:" then it is interpreted as the remote
    destination directory and all prior arguments are interpreted as local
    source files and/or directories.
* If it is "." or "..", or begins with "./", "../" then it is interpreted as
    the local destination directory and all prior arguments are interpreted as
    remote source files and/or directories.

For the variant `dspace_cp_to` all arguments are interpreted as local source
files and/or directories which will be copied to the home directory of the
remote account.

For the variant `dspace_cp_from` all arguments are interpreted as remote source
files and/or directories relative to the home directory of the remote account
which will be copied to the local current working directory.

### dspace_lookup

Get JSON details of a DSpace item.

The item may be a collection, however DSpace only returns metadata about the
collection itself and does not provide a way to get the items associated with
the collection.

### dspace_solr

Open the DSpace Solr admin page on a local browser, creating an ssh tunnel if
necessary.

The tunnel will persist in the background after the command is done.

### dspace_solr_export

Retrieve DSpace Solr search records.

### dspace_update_home

A convenience script for copying the files of "remote/bin" to the user's DSpace
home ~/bin directory.

### dspace_import

This script performs
`bin/dspace_libra_export` to acquire exports from LibraOpen,
`bin/dspace_import_zip` to generate import zip file(s),
copies the zip file(s) to the remote system,
and then runs `remote/bin/dspace_import` to import items into DSpace.

All options are passed to the local `bin/dspace_import_zip` script except:
* "--start date" is passed to `bin/dspace_libra_export`
* "--eperson" and "--collection" are passed to `remote/bin/dspace_import`.

#### Prerequisites

Remote utilities are expected to be installed in your DSpace account.
(See `dspace_update_home`.)

### dspace_import_zip

This is a program for generating a zip file containing a hierarchy import items
adhering to ["DSpace Simple Archive Format"][SAF] from a local directory
hierarchy of export items from Libra Open in the $EXPORT_DIR directory.

Normally, the program creates a single zip file "\$IMPORT_DIR.zip" unless
--batch-size or --batch-count is given.
In these cases, one or more zip files are created named "\$IMPORT_DIR-nnn.zip"
where "nnn" is a zero-filled number.
(Run `bin/dspace_import_zip --help` for all options.)

The resulting zip file(s) can be copied to DSpace for use with the remote
dspace_import script to bulk submit the items to DSpace.

#### Prerequisites

The program assumes that the Ruby version indicated by ".ruby-version" is
installed via `rvm` with a gemset named by ".ruby-gemset".

### dspace_libra_export

This script generates "libra-open-export" in the current directory by 
executing Ansible playbooks which run `rake libraoc:export:export_works`.

Note that the intermediate destination is a shared resource also used by the
Libra Open APTrust bagger.
If that task is currently running this script should **not** be run at the same
time.

#### Prerequisites

This script requires

* ccrypt
* terraform
* ansible-playbook

These are expected to be installed on the local workstation and available in
the current $PATH.

## DSpace instance utilities

Scripts from the "remote/bin" directory are meant to be copied to the
developer's account directory on the DSpace instance in "\$HOME/bin"
(which can be accomplished with `dspace_update_home`).

### dspace

Run a DSpace command.

### dspace_restart

Restart DSpace with updated configuration from
https://github.com/uvalib/dspace_config

Because the GitHub repository is automated to deploy after a push,
this script should not be necessary normally.

### dspace_retheme

Restart DSpace UI with updated configuration from
https://github.com/uvalib/dspace_theme

Because the GitHub repository is automated to deploy after a push,
this script should not be necessary normally.

### dspace_export

Export DSpace item records.

### dspace_solr_export

Retrieve DSpace Solr search records.

### dspace_import

Takes a zip file (generated by `bin/dspace_import_zip`) and bulk submits the
items to DSpace.

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


<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF --------- LINK -------------------------- TOOLTIP ------------------------>
[CSV]:        https://wiki.lyrasis.org/display/DSDOC8x/Batch+Metadata+Editing
[SAF]:        https://wiki.lyrasis.org/display/DSDOC8x/Importing+and+Exporting+Items+via+Simple+Archive+Format
