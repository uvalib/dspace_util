# lib/storage_table.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Management of persistent local data storage.

require 'common'
require 'logging'

# Methods to be mixed in to class methods to manage persistent storage of data
# acquired from DSpace and maintained in the "tmp/saved" project directory.
#
module StorageTable

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Existing items acquired from DSpace.
  #
  # @param [Hash] opt                 Passed to #get_current_table.
  #
  # @return [Hash{String=>Hash}]
  #
  def current_table(**opt)
    # noinspection RubyMismatchedReturnType
    get_current_table(**opt)
  end

  # Generate a table key derived from the given data.
  #
  # @param [Hash{Symbol=>*}] data
  #
  # @return [String, nil]             Hash key.
  #
  def key_for(data) = to_be_overridden

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Acquire current item data from DSpace.
  #
  # @param [Hash] opt
  #
  # @return [Hash{String=>Hash}]
  #
  def get_current_data(**opt) = to_be_overridden

  # Generate `current_table` contents from `storage_path` if *fast* or
  # otherwise from existing data acquired from DSpace.
  #
  # @param [Boolean] fetch            If *false*, just return blank.
  # @param [Boolean] fast             If *false*, do not read saved table.
  # @param [Boolean] write_saved      If *false*, do not update saved table.
  # @param [Hash]    opt              Passed #get_current_data if executed.
  #
  # @return [Hash{String=>Hash}]
  #
  def get_current_table(fetch: true, fast: true, write_saved: true, **opt)
    debug { "StorageTable.#{__method__} fetch: #{fetch}, fast: #{fast}, write_saved: #{write_saved}, #{opt}" }
    return {} unless fetch
    data = nil
    fast = false if opt.except(:full, :no_mark).compact.present?
    if fast && (data = get_stored_table(full: opt[:full]))
      return data unless opt[:full]
      return data unless (v = data.values.first).respond_to?(:full_path)
      data = nil  unless v.full_path.present?
    end
    data ||=
      get_current_data(**opt).map { |_, entry|
        key = key_for(entry)
        [key, entry]
      }.to_h
    set_stored_table(data, **opt) if write_saved
    data
  end

  # The absolute path to the `current_table` data storage file.
  #
  # @param [String] file              Relative path from including module.
  # @param [String] mode              Data directory branch.
  #
  # @return [String]                  Absolute path to data file.
  #
  def storage_path(file: nil, mode: DEPLOYMENT)
    if file.nil?
      raise 'file path not provided by including module'
    elsif !file.split('/').include?(mode)
      raise "#{file.inspect} missing #{mode.inspect}"
    else
      File.expand_path(file, PROJECT_DIRECTORY)
    end
  end

  # Get the value of `current_table` from the previous run.
  #
  # @param [String] file
  #
  # @return [Hash{String=>Hash{Symbol=>*}}]
  # @return [nil] If the storage_path file is not found or empty.
  #
  def get_stored_table(file: storage_path, **)
    debug { "StorageTable.#{__method__} file: #{file.inspect}" }
    JSON.load_file(file).presence&.transform_values(&:symbolize_keys)
  rescue Errno::ENOENT
    nil
  end

  # Store the value of `current_table` for future "--fast" runs.
  #
  # @param [Hash{String=>Hash}] entries
  # @param [String]             file
  #
  def set_stored_table(entries, file: storage_path, **)
    debug { "StorageTable.#{__method__} file: #{file.inspect}" }
    unless Dir.exist?((dir = File.dirname(file)))
      debug { "#{__method__}: creating #{dir.inspect}" }
      FileUtils.mkdir_p(dir)
    end
    File.open(file, 'w') do |io|
      JSON.dump(entries, io)
    end
  end

end
