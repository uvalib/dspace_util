# lib/dspace/collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API collection methods.

require 'dspace/community'

# Information about current DSpace collections.
#
module Dspace::Collection

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for a collection acquired from the DSpace API.
  #
  # Note that there is no functional relationship between communities and
  # collections in DSpace; the superclass relationship is used here only to
  # inherit common aspects of community path definition.
  #
  class Entry < Dspace::Community::Entry

    def entity_type = self[__method__] # Type of collection items

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

    # =========================================================================
    # :section: Dspace::Item::Entry overrides
    # =========================================================================

    public

    # Initialize the entry with the provided hash value.
    #
    # @param [Hash, nil] obj          Provided directly or:
    # @param [Hash]      opt          Provided via keyword arguments.
    # @param [Boolean]   full         If *true*, add community path to name.
    #
    def initialize(obj = nil, full: nil, **opt)
      super
      self[:entity_type] ||= extract_type(obj)
    end

    # =========================================================================
    # :section: Dspace::Item::Entry overrides
    # =========================================================================

    protected

    # The DSpace API URL for the parent community.
    #
    # @param [String, nil] uuid
    # @param [String]      endpoint   Format string for the URL endpoint.
    #
    # @return [String]
    # @return [nil]                   If *uuid* is nil.
    #
    def parent_url(uuid, endpoint: 'core/collections/%s/parentCommunity')
      super
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Get the collection type from the DSpace data value.
    #
    # @param [Hash, nil] obj
    # @param [String]    missing      Default result.
    #
    # @return [String]
    #
    def extract_type(obj, missing: 'nil')
      type = obj&.dig(:metadata, :'dspace.entity.type')
      type.is_a?(Array) && type[0]&.dig(:value) || missing
    end

  end

  # Acquire collections from DSpace.
  #
  class Lookup

    include Dspace::Api::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    protected

    # Fetch the DSpace API search result objects for collections.
    #
    # @param [Hash] opt               Passed to #dspace_api.
    #
    # @return [Array<(Array<Hash>,Integer)>]  Objects and total number of pages
    #
    def get_items(**opt)
      super(item_type: :collections, **opt)
    end

    # Transform DSpace API search result objects into entries.
    #
    # @param [Array<Hash>] list
    # @param [Symbol]      result_key   One of `Entry#keys`.
    # @param [Hash]        opt          Passed to #transform_item.
    #
    # @return [Hash{String=>Entry}]
    #
    def transform_items(list, result_key: Entry.default_key, **opt)
      # noinspection RubyMismatchedReturnType
      super
    end

    # Transform a DSpace API search result list object into an entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Entry]
    #
    def transform_item(item, **opt)
      Entry.new(item, **opt)
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    public

    # Existing collections acquired from DSpace.
    #
    # @param [Hash] opt               To #get_current_table on first run.
    #
    # @return [Hash{String=>Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= super
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    protected

    # The absolute path to the `current_table` data storage file.
    #
    # @return [String]
    #
    def storage_path
      @storage_path ||= super(file: "tmp/saved/#{DEPLOYMENT}/collections.json")
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace collections.
  #
  # @param [Hash] opt                 Passed to Lookup#find_or_fetch.
  #
  # @return [Hash{String=>Entry}]
  #
  def collections(**opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.find_or_fetch(**opt)
  end

end
