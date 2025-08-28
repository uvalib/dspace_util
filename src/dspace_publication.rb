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
# @param [Array<String>] publication  All Publications if empty.
# @param [String, nil]   scope        Limit to the given collection.
# @param [Hash]          opt          Passed to PublicationListing.
#
def lookup_publications(*publication, scope: option.scope, **opt)
  results = Dspace.lookup_publications(*publication, scope: scope)
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
