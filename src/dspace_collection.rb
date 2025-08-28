# src/dspace_collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace collections.

require 'common'
require 'logging'
require 'dspace'
require 'table_options'
require 'table_listing'

# =============================================================================
# :section: Classes
# =============================================================================

class CollectionListing < TableListing
  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Collection' => :name}
  end
end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace collections.
#
# @param [Array<String>] _collection  Currently unused.
# @param [Hash]          opt          Passed to CollectionListing.
#
def lookup_collections(*_collection, **opt)
  results = Dspace.collections
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :name   if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  CollectionListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_collections(*option.args)
end
