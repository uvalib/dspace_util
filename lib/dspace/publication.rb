# lib/dspace/publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API Publication methods.

require 'dspace/entity'

# Information about current DSpace Publication entities.
#
module Dspace::Publication

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for a Publication entity acquired from the DSpace API.
  #
  class Entry < Dspace::Entity::Entry

    def title  = self[__method__]
    def author = self[__method__]

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

  end

  # Acquire Publication entities from DSpace.
  #
  class Lookup < Dspace::Entity::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace Publication entities.
    #
    # @param [Array<String,Hash>] item  Specific Publications to find.
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

    # Transform DSpace API search result objects into Publication entries.
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

    # Transform a DSpace API search result list object into Publication entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Entry]
    #
    def transform_item(item, **opt)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item, **opt)
      entry[:title]  = field.(:'dc.title')              || entry[:title]
      entry[:author] = field.(:'dc.contributor.author') || entry[:author]
      entry
    end

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    protected

    # Generate a query for finding Publication entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def item_query(*arg, **opt)
      super(*arg, **opt, entity_type: 'Publication')
    end

    # Transform the argument into a Publication query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def item_term(arg)
      author, title, handle = item_values(arg, :author, :title, :handle)
      term = []
      term << "handle:#{handle}"                if handle
      term << "dc.title:#{title}"               if title
      term << "dc.contributor.author:#{author}" if author
      term
    end

    # Transform the String argument into properties for #item_terms.
    #
    # @param [String] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def item_specifier(arg)
      arg = arg&.squish
      case
        when arg.blank?                then raise 'empty string'
        when handle?(arg)              then { handle: arg }
        when arg.sub!(/^author:/i, '') then { author: arg }
        when arg.sub!(/^title:/i, '')  then { title:  arg }
        else                                { title:  arg }
      end
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace Publication entities.
  #
  # @param [Array<String,Hash>] item  All Publications if empty.
  # @param [Hash]               opt   Passed to Lookup#execute.
  #
  # @return [Hash{String=>Entry}]
  #
  def publications(*item, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*item, **opt)
  end

end
