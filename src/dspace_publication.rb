# src/dspace_publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace Publication entities.

require 'common'
require 'logging'
require 'dspace'
require 'item_options'
require 'item_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of Publication entities in tabular form.
#
class PublicationListing < ItemListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Title' => :title }
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace Publications.
#
# @param [Array<String>] item         All Publications if empty.
# @param [String, nil]   scope        Limit to given collection (option.scope)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to PublicationListing.
#
def lookup_publications(*item, scope: nil, fast: nil, **opt)
  scope   = option.scope if scope.nil?
  fast    = option.fast  if fast.nil?
  results = Dspace.publications(*item, scope: scope, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  PublicationListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  lookup_publications(*option.args)
end
