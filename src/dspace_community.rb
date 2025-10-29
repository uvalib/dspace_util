# src/dspace_community.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get information about DSpace communities and sub-communities.

require 'common'
require 'logging'
require 'dspace'
require 'table_options'
require 'table_listing'

# =============================================================================
# :section: Classes
# =============================================================================

# Display of communities in tabular form.
#
class CommunityListing < TableListing

  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Community' => :title }
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Generate an output table of DSpace communities.
#
# @param [Array<String>] _community   Currently unused.
# @param [Boolean, nil]  full         Show community name as path (option.full)
# @param [Boolean, nil]  fast         Used saved data if possible (option.fast)
# @param [Hash]          opt          Passed to CommunityListing.
#
def lookup_communities(*_community, full: nil, fast: nil, **opt)
  full    = option.full if full.nil?
  fast    = option.fast if fast.nil?
  results = Dspace.communities(full: full, fast: fast, no_mark: true)
  columns = []
  columns << :uuid   if option.uuid
  columns << :handle if option.handle
  columns << :title  if option.name
  opt[:only] = [*opt[:only], *columns].uniq if columns.present?
  CommunityListing.new(**opt).output(results)
end

# =============================================================================
# :section: Main program.
# =============================================================================

if $0 == __FILE__
  get_options
  lookup_communities(*option.args)
end
