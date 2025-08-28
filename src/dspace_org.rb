# src/dspace_org.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace OrgUnit entities.

require 'common'
require 'logging'
require 'dspace'
require 'entity_options'
require 'entity_listing'

# =============================================================================
# :section: Classes
# =============================================================================

class OrgUnitListing < EntityListing
  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'OrgUnit' => :name}
  end
end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace OrgUnits.
#
# @param [Array<String>] org          All OrgUnits if empty.
# @param [String, nil]   scope        Limit to the given collection.
# @param [Hash]          opt          Passed to OrgUnitListing.
#
def lookup_orgs(*org, scope: option.scope, **opt)
  results = Dspace.lookup_orgs(*org, scope: scope)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :name   if option.name
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
