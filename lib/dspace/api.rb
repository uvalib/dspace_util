# lib/dspace/api.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API methods

require 'open-uri'
require 'common'
require 'logging'
require 'storage_table'

# Methods supporting interaction with the DSpace API.
#
module Dspace::Api

  # ===========================================================================
  # :section: Constants
  # ===========================================================================

  public

  # This appears to be the maximum page size accepted by DSpace API requests.
  #
  # @type [Integer]
  #
  PAGE_SIZE = 100

  # External hostname for the DSpace API service.
  #
  # @return [String]
  #
  API_HOST = ENV['DSPACE_API'].freeze

  # External hostname for the machine hosting the DSpace instance.
  #
  # @return [String]
  #
  PUBLIC_HOST = ENV['DSPACE_PUBLIC'].freeze

  # Internal VPN hostname for the machine hosting the DSpace instance.
  #
  # @return [String]
  #
  PRIVATE_HOST = ENV['DSPACE_PRIVATE'].freeze

  # Local DSpace handles begin with this prefix.
  #
  # @type [String]
  #
  HANDLE_PREFIX = ENV['DSPACE_PREFIX'].freeze

  # Local DSpace Collection for Person entities.
  #
  # @type [String]
  #
  PERSON_COLLECTION = ENV['USR_COLLECTION'].freeze

  # Local DSpace Collection for OrgUnit entities.
  #
  # @type [String]
  #
  ORG_COLLECTION = ENV['ORG_COLLECTION'].freeze

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  public

  # Indicate whether *arg* appears to be a UUID.
  #
  # @param [any, nil] arg
  #
  def uuid?(arg)
    arg.to_s.match?(/^\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/i)
  end

  # Indicate whether *arg* appears to be a DSpace handle identifier.
  #
  # @param [any, nil] arg
  #
  def handle?(arg)
    arg.to_s.match?(%r{^(#{HANDLE_PREFIX}|123456789)/\d+$})
  end

  # Send a DSpace API request.
  #
  # The program is exited if there was an HTTP error.
  #
  # @param [String] path              Relative or absolute path.
  # @param [Hash]   opt               Additional URL options.
  #
  # @return [Hash{Symbol=>*}]
  #
  def dspace_api(path, **opt)
    opt.reverse_merge!(size: PAGE_SIZE)
    url  = dspace_api_url(path, **opt)
    debug { "#{__method__}: GET #{url}" }
    text = URI.open(url).read.presence
    text ? JSON.parse(text, symbolize_names: true) : {}
  rescue OpenURI::HTTPError => e
    error { "#{__method__}: #{e}"}
    exit(false)
  end

  # Generate an absolute URL to the DSpace API.
  #
  # @param [String] path              Relative or absolute path.
  # @param [Hash]   opt               Additional URL options.
  #
  def dspace_api_url(path, **opt)
    root = "https://#{API_HOST}/server/api"
    path = path.start_with?('http') ? path.dup : File.join(root, path)
    if opt.present?
      path << (path.include?('?') ? '&' : '?')
      path << opt.map { "#{_1}=#{_2}" }.join('&')
    end
    path
  end

  # ===========================================================================
  # :section: Modules
  # ===========================================================================

  # Methods supporting the lookup and persistence of DSpace items.
  #
  module Lookup

    include Dspace::Api
    include StorageTable

    # =========================================================================
    # :section: Methods
    # =========================================================================

    public

    # Either execute a search if search items or search parameters are given or
    # return with all current items (which will result in a search unless the
    # "--fast" parameter is given).
    #
    # @param [Array<String,Hash>] item  All items if empty and no search params
    # @param [Hash]               opt   Passed to #execute or #current_table.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    #
    def find_or_fetch(*item, **opt)
      ct_opt = opt.extract!(:fetch, :fast, :write_saved) # For current_table.
      ex_opt = opt.extract!(:sort_key, :no_mark, :full)  # For execute.
      saved  = item.blank? && opt.compact.blank?         # Use current_table?
      debug do
        case
          when !saved        then branch = 'EXECUTE'
          when ct_opt[:fast] then branch = 'STORED'
          else                    branch = 'CURRENT'
        end
        i, o, e, c = [item, opt, ex_opt, ct_opt].map(&:inspect)
        "#{self.class}.#{__method__} #{branch} #{i} #{o} #{e} #{c}"
      end
      # noinspection RubyMismatchedReturnType
      if saved
        current_table(**ex_opt, **ct_opt)
      else
        execute(*item, **ex_opt, **opt)
      end
    end

    # Fetch information about the given DSpace items.
    #
    # @param [Symbol, nil]  sort_key  One of `Entry#keys`.
    # @param [Boolean, nil] no_mark   If not *true*, mark page progress.
    # @param [Boolean, nil] full      Passed to #transform_items.
    # @param [Hash]         opt       Passed to #get_items.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    #
    def execute(*, sort_key: :title, no_mark: nil, full: nil, **opt)
      debug { "#{self.class}.#{__method__} sort_key: #{sort_key}, no_mark: #{no_mark}, full: #{full}, #{opt}" }

      start       = Time.now
      ti_opt      = opt.extract!(:result_key).merge!(full: full)
      list, pages = get_items(**opt)
      result      = transform_items(list, **ti_opt)

      # If more pages are available, get each of them in sequence.
      if pages > 1
        no_mark = mark_steps_disabled if no_mark.nil?
        ms_opt  = { start: start, marker: '.', no_mark: no_mark }
        show_char ms_opt[:marker] unless no_mark # For completion of page 0.
        mark_steps(1...pages, **ms_opt) do |page|
          list, _ = get_items(**opt, page: page)
          items = transform_items(list, **ti_opt)
          result.merge!(items)
        end
      end

      # Allow the subclass to adjust the results.
      if block_given?
        result.each_pair do |_, entry|
          yield(result, entry)
        end
      end

      # noinspection RubyMismatchedArgumentType
      sort_key ? result.sort_by { |_, v| v.send(sort_key).to_s }.to_h : result
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Fetch the DSpace API search result objects for Collections.
    #
    # @param [Symbol] item_type       E.g. :communities, :collections
    # @param [Hash]   opt             Passed to #dspace_api.
    #
    # @return [Array<(Array<Hash>,Integer)>]  Objects and total number of pages
    #
    def get_items(item_type:, **opt)
      data  = dspace_api("core/#{item_type}", dsoType: 'item', **opt)
      pages = data.dig(:page, :totalPages) || 1
      items = Array.wrap(data.dig(:_embedded, item_type))
      return items, pages
    end

    # Transform DSpace API search result objects into entries.
    #
    # @param [Array<Hash>] list
    # @param [Symbol]      result_key   One of `Entry#keys`.
    # @param [Hash]        opt          Passed to #transform_item.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    #
    def transform_items(list, result_key:, **opt)
      list.map { |item|
        entry = transform_item(item, **opt)
        key   = entry[result_key]
        [key, entry]
      }.to_h
    end

    # Transform a DSpace API search result list object into an entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Dspace::Item::Entry]
    #
    def transform_item(item, **opt)
      Dspace::Item::Entry.new(item, **opt)
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    public

    # Existing items acquired from DSpace.
    #
    # @param [Hash] opt               To #get_current_table on first run.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    #
    def current_table(**opt)
      debug { "#{self.class}.#{__method__} #{opt}" }
      # noinspection RubyMismatchedReturnType
      super
    end

    # Generate a table key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data
    #
    # @return [String, nil]           Hash key.
    #
    def key_for(data)
      data[:table_key] || data[:uuid]
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    protected

    # Acquire data for existing items from DSpace.
    #
    # @param [Hash] opt               Passed to #execute.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    #
    def get_current_data(**opt)
      debug { "#{self.class}.#{__method__} #{opt}" }
      execute(**opt)
    end

    # Get the value of `current_table` from the previous run.
    #
    # @param [Hash] opt               Passed to #transform_item.
    #
    # @return [Hash{String=>Dspace::Item::Entry}]
    # @return [nil] If the storage_path file is not found or empty.
    #
    def get_stored_table(**opt)
      super&.transform_values { transform_item(_1, **opt) }
    end

    # Store the value of `current_table` for future "--fast" runs.
    #
    # @param [Hash{String=>Hash}] entries
    # @param [Hash]               opt
    #
    def set_stored_table(entries, file: storage_path, **opt)
      debug { "Lookup.#{__method__} opt=#{opt.inspect}" }
      unless opt[:full]
        entries = entries.transform_values { _1.except(:full_path) }
      end
      super
    end

  end

end
