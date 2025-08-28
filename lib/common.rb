# lib/common.rb
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

# Maximum number of items to create at once.
#
# @type [Integer]
#
BATCH_SIZE = 1000

# The value of `option.phase` when only creating OrgUnit entities.
#
# @type [Integer]
#
NO_PHASE = 0

# The value of `option.phase` when only creating OrgUnit entities.
#
# @type [Integer]
#
ORG_UNIT_PHASE = 1

# The value of `option.phase` when only creating Person entities.
#
# @type [Integer]
#
PERSON_PHASE = ORG_UNIT_PHASE.next

# The value of `option.phase` when only creating Person entities.
#
# @type [Integer]
#
PUBLICATION_PHASE = PERSON_PHASE.next

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

# Name prefix for LibraOpen export subdirectories under `export_root`.
#
# @type [String]
#
EXPORT_PREFIX = 'export-'

# Name prefix for Publication import subdirectories under `import_root`.
#
# @type [String]
#
IMPORT_PREFIX = 'import-'

# Name prefix for Person import subdirectories under `import_root`.
#
# @type [String]
#
PERSON_PREFIX = 'person-'

# Name prefix for OrgUnit import subdirectories under `import_root`.
#
# @type [String]
#
ORG_PREFIX = 'org-'

# =============================================================================
# :section: Methods
# =============================================================================

# Create a hash from a JSON file.
#
# @param [String, nil] file           Path to file.
#
# @return [Hash{Symbol=>*}]
#
def parse_json(file)
  return {} if (file = file&.strip).blank?
  # noinspection RubyMismatchedArgumentType
  JSON.load_file(file, symbolize_names: true)
end

# Used within a base class function definition to indicate that it must be
# defined by the subclass.
#
def to_be_overridden
  raise "#{caller[0]} TO BE OVERRIDDEN BY THE SUBCLASS"
end
