# src/dspace_person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace Person entities.

require 'common'
require 'logging'
require 'dspace'
require 'item_options'
require 'item_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of Person entities in tabular form.
#
class PersonListing < ItemListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Name' => :title }
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of the given DSpace Persons.
#
# @param [Array<String>] person       All Persons if empty.
# @param [String, nil]   scope        Limit to given collection (option.scope)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to PersonListing.
#
def lookup_persons(*person, scope: nil, fast: nil, **opt)
  scope   = option.scope if scope.nil?
  fast    = option.fast  if fast.nil?
  results = Dspace.persons(*person, scope: scope, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  PersonListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  lookup_persons(*option.args)
end
