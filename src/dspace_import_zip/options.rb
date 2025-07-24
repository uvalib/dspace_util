# src/dspace_import_zip/options.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Command line options for dspace_import_zip.

require_relative 'common'

require 'optparse'

# =============================================================================
# :section: Methods
# =============================================================================

def get_options = @option = Options.new(ARGV)
def option      = @option || get_options
def export_root = option.export_root
def import_root = option.import_root
def records     = option.records
def max_records = option.max_records
def batch_count = option.batch_count
def batch_size  = option.batch_size
def silent      = option.silent
def verbose     = option.verbose
def debugging   = option.debugging

# =============================================================================
# :section: Class
# =============================================================================

class Options

  DEBUG = false

  COMMON_ROOT = ENV['COMMON_ROOT'].presence || "#{ENV['PWD']}/tmp"
  COMMON_DIR  = File.directory?(COMMON_ROOT) ? COMMON_ROOT : ENV['PWD']
  EXPORT_DIR  = ENV['EXPORT_DIR'].presence  || 'libra-export'
  IMPORT_DIR  = ENV['IMPORT_DIR'].presence  || 'dspace-import'

  C_DESC = "Common root for export and import dirs (#{COMMON_DIR})"
  E_DESC = "Existing source dir (def: '#{EXPORT_DIR}')"
  I_DESC = "Destination dir to be created (def: '#{IMPORT_DIR}')"
  R_DESC = 'List of records to extract'
  M_DESC = 'Only process N exports'
  B_DESC = 'Split output into N zip files'
  Z_DESC = 'Make zip files of size N'
  S_DESC = 'Suppress console output'
  V_DESC = 'Verbose console output'
  D_DESC = 'Debug console output'
  H_DESC = 'Show this help message'

  DESCRIPTION   = ''
  LEADING_HELP  = ''
  TRAILING_HELP = DESCRIPTION

  # ===========================================================================
  # :section: Properties
  # ===========================================================================

  attr_accessor :common_root, :export_root, :import_root
  attr_accessor :batch_count, :batch_size
  attr_accessor :records, :max_records
  attr_accessor :silent, :verbose, :debugging

  # Create a new instance.
  #
  # @param [Array<String>] args       Command line arguments.
  #
  def initialize(args)
    @common_root = COMMON_DIR
    @export_root = EXPORT_DIR
    @import_root = IMPORT_DIR
    help_exit    = false

    parser = OptionParser.new do |p|
      p.banner += "\n#{LEADING_HELP}\n" if LEADING_HELP.present?
      p.on('-c', '--common DIRECTORY',       C_DESC) { @common_root  = _1 }
      p.on('-e', '--export DIRECTORY',       E_DESC) { @export_root  = _1 }
      p.on('-i', '--import DIRECTORY',       I_DESC) { @import_root  = _1 }
      p.on('-r', '--record RECORDS',         R_DESC) { @records      = list(_1) }
      p.on('-m', '--max-records N', Integer, M_DESC) { @max_records  = _1 }
      p.on('-b', '--batch-count N', Integer, B_DESC) { @batch_count  = _1 }
      p.on('-z', '--batch-size N',  Integer, Z_DESC) { @batch_size   = _1 }
      p.on('-s', '--[no-]silent',            S_DESC) { @silent       = _1 }
      p.on('-v', '--[no-]verbose',           V_DESC) { @verbose      = _1 }
      p.on('-d', '--[no-]debug',             D_DESC) { @debugging    = _1 }
      p.on('-h', '--help',                   H_DESC) { help_exit     = true }
      p.separator "\n#{TRAILING_HELP}" if TRAILING_HELP.present?
    end
    parser.parse(args)

    @export_root = set_subdir(@export_root, @common_root)
    @import_root = set_subdir(@import_root, File.dirname(@export_root))
    @records     = Array.wrap(@records)
    @max_records = @max_records.to_i
    @batch_count = @batch_count.to_i
    @batch_size  = @batch_size.to_i
    @debugging   = false     if @debugging.nil?
    @silent      = false     if @silent.nil?
    @verbose     = debugging if @verbose.nil?
    @verbose     = false     if silent

    if help_exit
      puts parser.to_s.gsub(/ {11}(\S)/, '    \1')
      if DEBUG || debugging
        require_relative 'logging' unless defined?(output_line)
        output_line "HELP: records       = #{records.inspect}"
        output_line "HELP: RUBY_VERSION  = #{RUBY_VERSION.inspect}"
        output_line "HELP: $0            = #{$0.inspect}"
        output_line "HELP: ARGV          = #{args.inspect}"
        output_line "HELP: common_root   = #{common_root.inspect}"
        output_line "HELP: export_root   = #{export_root.inspect}"
        output_line "HELP: import_root   = #{import_root.inspect}"
        output_line "HELP: max           = #{max_records.inspect}"
        output_line "HELP: batch_count   = #{batch_count.inspect}"
        output_line "HELP: batch_size    = #{batch_size.inspect}"
        output_line "HELP: silent        = #{silent.inspect}"
        output_line "HELP: verbose       = #{verbose.inspect}"
        output_line "HELP: debugging     = #{debugging.inspect}"
      end
      exit
    end
  end

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Split `arg` into an array of Libra record identification numbers.
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
      File.basename(item.strip, '.*')
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
  # @return [nil]                     If `subdir` is blank.
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
