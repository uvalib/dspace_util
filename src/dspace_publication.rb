# src/dspace_publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace Publication entities.

require 'common'
require 'logging'
require 'dspace'
require 'entity_options'
require 'entity_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of Publication entities in tabular form.
#
class PublicationListing < EntityListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Title' => :name}
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace Publications.
#
# @param [Array<String>] item         All Publications if empty.
# @param [String, nil]   scope        Limit to the given collection.
# @param [Boolean]       no_show      If false show page progress.
# @param [Hash]          opt          Passed to PublicationListing.
#
def lookup_publications(*item, scope: option.scope, no_show: true, **opt)
  results = Dspace.lookup_publications(*item, scope: scope, no_show: no_show)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :name   if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  PublicationListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_publications(*option.args)
end
