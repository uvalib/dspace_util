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

# Display of collections in tabular form.
#
class CollectionListing < TableListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Type' => :entity_type, 'Collection' => :title }
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace collections.
#
# @param [Array<String>] _collection  Currently unused.
# @param [Boolean, nil]  full         Show collection as path (option.full)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to CollectionListing.
#
def lookup_collections(*_collection, full: nil, fast: nil, **opt)
  full    = option.full if full.nil?
  fast    = option.fast if fast.nil?
  results = Dspace.collections(full: full, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  CollectionListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  lookup_collections(*option.args)
end
