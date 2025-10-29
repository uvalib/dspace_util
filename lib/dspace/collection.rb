# lib/dspace/collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API collection methods.

require_relative 'entity'

# Information about current DSpace collections.
#
module Dspace::Collection

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  class Entry < Dspace::Entity::Entry
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
