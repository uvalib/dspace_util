# src/dspace_import_zip.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Conversion of LibraOpen exports to a zip file of DSpace imports.
#
# In order to actually cause the imports to be made, the resulting zip file
# must be copied to DSpace and installed using `remote/bin/dspace_import`:
#
#   bin/dspace_cp_to dspace-import.zip
#   bin/dspace_sh bin/dspace_import dspace-import.zip
#
# (Assuming "remote/bin/*" has been copied to "~/bin" on the DSpace system.)

require_relative 'dspace_import_zip/options'
require_relative 'dspace_import_zip/import_dir'
require_relative 'dspace_import_zip/import_zip'

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  make_import_dir and make_import_zip
end
