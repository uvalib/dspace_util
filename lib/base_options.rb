# lib/base_options.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Common command line options.

require 'common'
require 'logging'

require 'optparse'
require 'singleton'

# =============================================================================
# :section: Methods
# =============================================================================

def option = BaseOptions.instance

# =============================================================================
# :section: Class
# =============================================================================

# Generic options applicable to any application.
#
class BaseOptions

  include Singleton

  DEBUG = false

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :quiet, :verbose, :debug

  # Create a new BaseOptions instance.
  #
  # @param [Array<String>, nil] argv  Command line arguments (default: ARGV).
  #
  def initialize(argv = nil)
    @argv = argv ? Array.wrap(argv) : ARGV.dup
    initialize_options
    @args = new_parser.parse!(@argv.dup)
    finalize_options
    validate_options or exit(false)
    show_help if help_exit
  end

  # The original command line arguments.
  #
  # @return [Array<String>]
  #
  attr_reader :argv

  # The remaining non-option command line arguments.
  #
  # @return [Array<String>]
  #
  attr_reader :args

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # The parser for command-line options.
  #
  # @return [OptionParser]
  #
  attr_reader :parser

  # Indicate whether "--help" has been given on the command line.
  #
  # @return [Boolean]
  #
  attr_reader :help_exit

  # Narrative text describing the program.
  #
  # @return [String]
  #
  def description = ''

  # Help text preceding the list of options.
  #
  # @return [String]
  #
  def leading_help = ''

  # Help text following the list of options.
  #
  # @return [String]
  #
  def trailing_help = description

  # Set initial option attributes before parsing.
  #
  # @return [void]
  #
  def initialize_options
    @debug   = false
    @quiet   = false
    @verbose = nil
  end

  # Create an option parser for the option attributes of this class.
  #
  # @return [OptionParser]
  #
  def new_parser(&blk)
    @parser = OptionParser.new do |p|
      p.banner += "\n#{leading_help}\n" if leading_help.present?
      blk&.call(p)
      p.on('-q', '--[no-]quiet',   'Suppress console output')   { @quiet     = _1 }
      p.on('-v', '--[no-]verbose', 'Verbose console output')    { @verbose   = _1 }
      p.on('-d', '--[no-]debug',   'Diagnostic console output') { @debug     = _1 }
      p.on('-h', '--help',         'Show this help message')    { @help_exit = true }
      p.separator "\n#{trailing_help}" if trailing_help.present?
    end
  end

  # Resolve option attributes after parsing.
  #
  # @return [void]
  #
  def finalize_options
    @verbose = debug if @verbose.nil?
    @verbose = false if quiet
  end

  # Indicate whether provided options are acceptable.
  #
  # @return [Boolean]
  #
  # @yield Generate one or more error messages for problems.
  # @yieldreturn [Array<String>, String, nil] Error message(s) to display.
  #
  def validate_options
    !block_given? || Array.wrap(yield).compact.each { error(_1) }.blank?
  end

  # Output program usage help and then exit.
  #
  # @return [void]
  #
  def show_help
    puts parser.to_s.gsub(/ {11}(\S)/, '    \1')
    show_help_debug if DEBUG || debug
    exit
  end

  # Display final option settings for diagnostics.
  #
  # @return [void]
  #
  def show_help_debug
    output_line "HELP: RUBY_VERSION  = #{RUBY_VERSION.inspect}"
    output_line "HELP: $0            = #{$0.inspect}"
    output_line "HELP: ARGV          = #{argv.inspect}"
    output_line "HELP: debug         = #{debug.inspect}"
    output_line "HELP: quiet         = #{quiet.inspect}"
    output_line "HELP: verbose       = #{verbose.inspect}"
  end

end
