# src/dspace_import_zip/options.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Command line options for dspace_import_zip.

require 'common'
require 'logging'
require 'base_options'

# =============================================================================
# :section: Methods
# =============================================================================

def get_options = @option = Options.new
def option      = @option || get_options

# =============================================================================
# :section: Class
# =============================================================================

# Options applicable to the dspace_import_zip application.
#
class Options < BaseOptions

  DEBUG = false

  COMMON_ROOT = ENV['COMMON_ROOT'].presence || "#{ENV['PWD']}/tmp"
  COMMON_DIR  = File.directory?(COMMON_ROOT) ? COMMON_ROOT : ENV['PWD']
  EXPORT_DIR  = ENV['EXPORT_DIR'].presence  || 'libra-export'
  IMPORT_DIR  = ENV['IMPORT_DIR'].presence  || 'dspace-import'

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :phase, :export_root, :import_root, :common_root
  attr_accessor :batch_count, :batch_size, :max_records
  attr_accessor :select, :reject, :fast

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
    @select      = []
    @reject      = []
    @phase       = NO_PHASE
    @common_root = COMMON_DIR
    @export_root = EXPORT_DIR
    @import_root = IMPORT_DIR
  end

  # Create an option parser for the option attributes of this class.
  #
  # @return [OptionParser]
  #
  def new_parser(&blk)
    super do |p|
      p.on('-r', '--record RECORDS',         'List of records to extract')                              { @select      += list(_1) }
      p.on('-s', '--skip RECORDS',           'List of records to ignore')                               { @reject      += list(_1) }
      p.on('-c', '--common DIRECTORY',       "Common root for export and import dirs (#{COMMON_DIR})")  { @common_root  = _1 }
      p.on('-e', '--export DIRECTORY',       "Existing source dir (def: '#{EXPORT_DIR}')")              { @export_root  = _1 }
      p.on('-i', '--import DIRECTORY',       "Destination dir to be created (def: '#{IMPORT_DIR}')")    { @import_root  = _1 }
      p.on('-m', '--max-records N', Integer, 'Only process N exports')                                  { @max_records  = _1 }
      p.on('-b', '--batch-count N', Integer, 'Split output into N zip files')                           { @batch_count  = _1 }
      p.on('-z', '--batch-size N',  Integer, 'Make zip files of size N')                                { @batch_size   = _1 }
      p.on('-p', '--phase N',       Integer, 'Execution phase')                                         { @phase        = _1 }
      p.on('-f', '--[no-]fast',              'Use saved org and person data')                           { @fast         = _1 }
      blk&.call(p)
    end
  end

  # Resolve option attributes after parsing.
  #
  # @return [void]
  #
  def finalize_options
    super
    @select.uniq!
    @reject.uniq!
    @phase       = @phase.to_i
    @batch_size  = @batch_size.to_i
    @batch_count = @batch_count.to_i
    @max_records = @max_records.to_i
    @export_root = set_subdir(@export_root, @common_root)
    @import_root = set_subdir(@import_root, File.dirname(@export_root))
  end

  # Indicate whether provided options are acceptable.
  #
  # @return [Boolean]
  #
  def validate_options
    super or return false
    message =
      if @phase.negative? || (@phase > PUBLICATION_PHASE)
        "--phase must be in the range (0..#{PUBLICATION_PHASE})"
      elsif @batch_size > BATCH_SIZE
        "--batch-size #{@batch_size} is greater than #{BATCH_SIZE}"
      end
    error(message) if message
    message.nil?
  end

  # Display final option settings for diagnostics.
  #
  # @return [void]
  #
  def show_help_debug
    output_line "HELP: reject        = #{reject.inspect}"
    output_line "HELP: select        = #{select.inspect}"
    super
    output_line "HELP: common_root   = #{common_root.inspect}"
    output_line "HELP: export_root   = #{export_root.inspect}"
    output_line "HELP: import_root   = #{import_root.inspect}"
    output_line "HELP: batch_count   = #{batch_count.inspect}"
    output_line "HELP: batch_size    = #{batch_size.inspect}"
    output_line "HELP: max           = #{max_records.inspect}"
    output_line "HELP: fast          = #{fast.inspect}"
    output_line "HELP: phase         = #{phase.inspect}"
  end

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Split `arg` into an array of LibraOpen record identification numbers.
  # If `arg` is a file name, form the array from each line of the file.
  #
  # @param [String, Array] arg
  #
  # @return [Array<String>]
  #
  def list(arg)
    case
      when arg.blank?            then items = []
      when arg.is_a?(Array)      then items = arg.map(&:to_s)
      when File.exist?(arg.to_s) then items = File.readlines(arg.to_s)
      else                            items = arg.to_s.split(/[,;|\s]/)
    end
    items.map { |item|
      item = item.strip
      item.sub!(/ .*$/, '') # In case this is a line from a mapfile.
      File.basename(item, '.*')
          .downcase
          .delete_prefix(EXPORT_PREFIX)
          .delete_prefix(IMPORT_PREFIX)
    }.compact_blank
  end

  # Return the full path to the given `subdir`.
  #
  # @param [String] subdir
  # @param [String] base
  #
  # @return [String]
  # @return [nil]                     If `subdir` is nil or empty.
  #
  def set_subdir(subdir, base)
    subdir = subdir&.strip&.presence or return
    if Pathname.new(subdir).absolute?
      subdir
    elsif File.directory?(subdir)
      File.expand_path(subdir)
    else
      File.expand_path(subdir, base)
    end
  end

end
