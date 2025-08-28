# src/dspace_import_zip/collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get existing collections from the DSpace instance.

require 'common'
require 'dspace'

# =============================================================================
# :section: Methods
# =============================================================================

# The mapping of DSpace collection to handle.
#
# @return [Hash{String=>Hash{Symbol=>*}}]
#
def collection
  @collection ||= Dspace.collections(result_key: :name)
end

# The handle of the collection named by `ENV[var]`.
#
# @param [String] var
#
# @return [String, nil]
#
def collection_handle(var)
  var  = var.to_s.upcase
  name = ENV[var]         or raise("Missing ENV[#{var}]")
  coll = collection[name] or raise("Missing collection #{name.inspect}")
  coll[:handle].presence
end
