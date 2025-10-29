# lib/entity_options.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Command line options for a listing program.

require 'common'
require 'logging'
require 'table_options'

# =============================================================================
# :section: Methods
# =============================================================================

def get_options = @option = EntityOptions.new
def option      = @option || get_options

# =============================================================================
# :section: Class
# =============================================================================

# Options applicable to applications which output information about DSpace
# entities in tabular form.
#
class EntityOptions < TableOptions

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :scope

  # ===========================================================================
  # :section: BaseOptions overrides
  # ===========================================================================

  protected

  # Create an option parser for the option attributes of this class.
  #
  # @return [OptionParser]
  #
  def new_parser
    super do |p|
      p.on('--scope COLL', 'Limit to COLL collection') { @scope = _1 }
    end
  end

  # Display final option settings for diagnostics.
  #
  # @return [void]
  #
  def show_help_debug
    super
    output_line "HELP: scope         = #{scope.inspect}"
  end

end
