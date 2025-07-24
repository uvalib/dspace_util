# src/dspace_import_zip/common.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Common definitions for dspace_import_zip.

require 'active_support'
require 'active_support/core_ext'
require 'fileutils'
require 'json'

# =============================================================================
# :section: Constants
# =============================================================================

# Indicate whether DOIs should be included as "dc.identifier.doi".
#
# This is the old LibraOpen DOI which will eventually be mapped to the new
# DSpace item.
#
# @type [Boolean]
#
DOI = true

# Indicate whether DOIs should appear as "dc.identifier.uri" in addition to
# "dc.identifier.doi".
#
# This will make the old LibraOpen DOI appear as a link on DSpace item show
# pages under the "URI" section.
#
# @type [Boolean]
#
DOI_URI = DOI

# Directory name prefix for subdirectories under `#export_root`.
#
# @type [String]
#
EXPORT_PREFIX = 'export-'

# Directory name prefix for subdirectories under `#import_root`.
#
# @type [String]
#
IMPORT_PREFIX = 'import-'

# =============================================================================
# :section: Methods
# =============================================================================

# Create a hash from a JSON file.
#
# @param [String, nil] file           Path to file
#
# @return [Hash{Symbol=>*}]
#
def parse_json(file)
  return {} if (file = file&.strip).blank?
  # noinspection RubyMismatchedArgumentType
  JSON.load_file(file, symbolize_names: true)
end