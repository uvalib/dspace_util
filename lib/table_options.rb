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

def option = TableOptions.instance

# =============================================================================
# :section: Class
# =============================================================================

# Options applicable to applications which output information in tabular form.
#
class TableOptions < BaseOptions

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :uuid, :handle, :name, :full, :fast, :data

  # ===========================================================================
  # :section: BaseOptions overrides
  # ===========================================================================

  protected

  # Set initial option attributes before parsing.
  #
  # @return [void]
  #
  def initialize_options
    super
    @full = false
    @fast = false
    @data = false
  end

  # Create an option parser for the option attributes of this class.
  #
  # @return [OptionParser]
  #
  def new_parser(&blk)
    super do |p|
      p.on('--uuid',      'Output only UUIDs')           { @uuid   = true }
      p.on('--handle',    'Output only handles')         { @handle = true }
      p.on('--name',      'Output only names')           { @name   = true }
      p.on('--[no-]full', 'Show full community path')    { @full   = _1 }
      p.on('--[no-]fast', 'Used saved data if possible') { @fast   = _1 }
      p.on('--[no-]data', 'Output for data processing')  { @data   = _1 }
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
    output_line "HELP: full          = #{full.inspect}"
    output_line "HELP: fast          = #{fast.inspect}"
    output_line "HELP: data          = #{data.inspect}"
  end

end
