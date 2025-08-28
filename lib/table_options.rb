# lib/table_options.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Command line options for a listing program.

require 'common'
require 'logging'
require 'base_options'

# =============================================================================
# :section: Methods
# =============================================================================

def get_options = @option = TableOptions.new
def option      = @option || get_options

# =============================================================================
# :section: Class
# =============================================================================

class TableOptions < BaseOptions

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :uuid, :handle, :name

  # ===========================================================================
  # :section: BaseOptions overrides
  # ===========================================================================

  # Create an option parser for the option attributes of this class.
  #
  # @return [OptionParser]
  #
  def new_parser(&blk)
    super do |p|
      p.on('--uuid',   'Output only UUIDs')   { @uuid   = true }
      p.on('--handle', 'Output only handles') { @handle = true }
      p.on('--name',   'Output only names')   { @name   = true }
      blk&.call(p)
    end
  end

  # Display final option settings for diagnostics.
  #
  # @return [void]
  #
  def show_help_debug
    super
    output_line "HELP: uuid          = #{uuid.inspect}"
    output_line "HELP: handle        = #{handle.inspect}"
    output_line "HELP: name          = #{name.inspect}"
  end

end
