# lib/dspace/item.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API generic item methods.

require_relative 'entity'

# Information about current DSpace generic items.
#
module Dspace::Item

  include Dspace::Entity

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
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace items.
    #
    # @param [Array<String,Hash>] entity
    # @param [Hash]               opt       Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*entity, **opt)
      # noinspection RubyMismatchedReturnType
      super
    end

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides - internal methods
    # =========================================================================

    protected

    # Transform DSpace API search result objects into entries.
    #
    # @param [Array<Hash>] list
    # @param [Hash]        opt        Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def transform_entity_objects(list, **opt)
      # noinspection RubyMismatchedReturnType
      super(list, result_key: Entry.default_key, **opt)
    end

    # Transform a DSpace API search result list object into an entry.
    #
    # @param [Hash] item
    #
    # @return [Entry]
    #
    def transform_entity_object(item)
      Entry.new(item)
    end

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

  # Fetch all DSpace items.
  #
  # @param [Hash] opt                 Passed to #lookup_items.
  #
  # @return [Hash{String=>Entry}]
  #
  def items(**opt)
    # noinspection RubyMismatchedReturnType
    lookup_items(**opt)
  end

  # Fetch information about the given DSpace Publication entities.
  #
  # @param [Array<String,Hash>] name  All items if empty.
  # @param [Hash]               opt   Passed to super.
  #
  # @return [Hash{String=>Entry}]
  #
  def lookup_items(*name, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*name, **opt)
  end

end
