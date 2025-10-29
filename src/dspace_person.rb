# src/dspace_person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace Person entities.

require 'common'
require 'logging'
require 'dspace'
require 'entity_options'
require 'entity_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of Person entities in tabular form.
#
class PersonListing < EntityListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Name' => :name}
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of the given DSpace Persons.
#
# @param [Array<String>] person       All Persons if empty.
# @param [String, nil]   scope        Limit to the given collection.
# @param [Boolean]       no_show      If false show page progress.
# @param [Hash]          opt          Passed to PersonListing.
#
def lookup_persons(*person, scope: option.scope, no_show: true, **opt)
  results = Dspace.lookup_persons(*person, scope: scope, no_show: no_show)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :name   if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  PersonListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_persons(*option.args)
end
