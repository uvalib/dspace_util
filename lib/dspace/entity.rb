# lib/dspace/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace entity.

require 'dspace/item'

# Information about current DSpace entity items.
#
module Dspace::Entity

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for an entity acquired from the DSpace API.
  #
  class Entry < Dspace::Item::Entry
  end

  # Acquire entities from DSpace.
  #
  class Lookup < Dspace::Item::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace entities.
    #
    # @param [Array<String,Hash>] item  Specific entities to find.
    # @param [Hash]               opt   Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*item, **opt)
      # noinspection RubyMismatchedReturnType
      super
    end

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    protected

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

  end

end
