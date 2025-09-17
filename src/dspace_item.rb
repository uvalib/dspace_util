# src/dspace_item.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace items of any type.

require 'common'
require 'logging'
require 'dspace'
require 'entity_options'
require 'entity_listing'

# =============================================================================
# :section: Classes
# =============================================================================

class ItemListing < EntityListing
end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace items.
#
# @param [Array<String>] name         All items if empty.
# @param [String, nil]   scope        Limit to the given collection.
# @param [Boolean]       no_show      If false show page progress.
# @param [Hash]          opt          Passed to ItemListing.
#
def lookup_items(*name, scope: option.scope, no_show: true, **opt)
  results = Dspace.lookup_items(*name, scope: scope, no_show: no_show)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :name   if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  ItemListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_items(*option.args)
end
