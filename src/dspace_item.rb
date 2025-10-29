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

# Display of generic DSpace items in tabular form.
#
class ItemListing < EntityListing
end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace items.
#
# @param [Array<String>] name         All items if empty.
# @param [String, nil]   scope        Limit to given collection (option.scope)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to ItemListing.
#
def lookup_items(*name, scope: nil, fast: nil, **opt)
  scope   = option.scope if scope.nil?
  fast    = option.fast  if fast.nil?
  results = Dspace.items(*name, scope: scope, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
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
