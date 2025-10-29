# lib/dspace/item.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API generic item methods.

require 'dspace/entity'

# Information about current DSpace generic items.
#
module Dspace::Item

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for an item acquired from the DSpace API.
  #
  class Entry < Dspace::Entity::Entry
  end

  # Acquire items from DSpace.
  #
  class Lookup < Dspace::Entity::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace items.
    #
    # @param [Array<String,Hash>] item  Specific items to find.
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

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    protected

    # Generate a query for finding items.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def entity_query(*arg, **opt)
      super(*arg, **opt, type: nil)
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace items.
  #
  # @param [Array<String,Hash>] item  All items if empty.
  # @param [Hash]               opt   Passed to Lookup#execute.
  #
  # @return [Hash{String=>Entry}]
  #
  def items(*item, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*item, **opt)
  end

end
