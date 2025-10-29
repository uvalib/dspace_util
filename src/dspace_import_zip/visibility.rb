# src/dspace_import_zip/visibility.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating LibraOpen visibility to DSpace authorization.

require 'common'
require 'logging'

# =============================================================================
# :section: Constants
# =============================================================================

# A mapping of LibraOpen visibility to the equivalent DSpace group.
#
# @type [Hash{Symbol=>String}]
#
ACCESS = {
  authenticated:  'Authenticated Users',
  restricted:     'Submitter Only',
}.freeze

# =============================================================================
# :section: Methods
# =============================================================================

# The DSpace group allowed access based on the given "visibility" data value.
#
# @param [ExportItem, Hash, Symbol, String] value   Libra value source.
#
# @return [String, nil]
#
def get_access_group(value)
  value = parse_json(value.visibility) if value.is_a?(ExportItem)
  value = value[:visibility]           if value.is_a?(Hash)
  # noinspection RubyMismatchedReturnType
  case value
    when Symbol then ACCESS[value]
    when String then ACCESS.find { (_1.to_s == value) || (_2 == value) }&.last
  end
end
