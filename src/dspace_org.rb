# src/dspace_org.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace OrgUnit entities.

require 'common'
require 'logging'
require 'dspace'
require 'item_options'
require 'item_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of OrgUnit entities in tabular form.
#
class OrgUnitListing < ItemListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'OrgUnit' => :title }
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace OrgUnits.
#
# @param [Array<String>] org          All OrgUnits if empty.
# @param [String, nil]   scope        Limit to given collection (option.scope)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to OrgUnitListing.
#
def lookup_orgs(*org, scope: nil, fast: nil, **opt)
  scope   = option.scope if scope.nil?
  fast    = option.fast  if fast.nil?
  results = Dspace.orgs(*org, scope: scope, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  OrgUnitListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_orgs(*option.args)
end
