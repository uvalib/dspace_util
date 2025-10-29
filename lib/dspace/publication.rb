# lib/dspace/publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API Publication methods.

require_relative 'entity'

# Information about current DSpace Publication entities.
#
module Dspace::Publication

  include Dspace::Entity

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
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    # Fetch information about the given DSpace Publication entities.
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

    # Transform DSpace API search result objects into Publication entries.
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

    # Transform a DSpace API search result list object into Publication entry.
    #
    # @param [Hash] item
    #
    # @return [Entry]
    #
    def transform_entity_object(item)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item)
      entry[:title]  ||= field.(:'dc.title') || entry[:name]
      entry[:author] ||= field.(:'dc.contributor.author')
      entry
    end

    # Generate a query for finding Publication entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def entity_query(*arg, **opt)
      super(*arg, **opt, type: 'Publication')
    end

    # Transform the argument into a Publication query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def entity_term(arg)
      author, title, handle = entity_values(arg, :author, :title, :handle)
      term = []
      term << "handle:#{handle}"                if handle
      term << "dc.title:#{title}"               if title
      term << "dc.contributor.author:#{author}" if author
      term
    end

    # Transform the String argument into properties for #entity_terms.
    #
    # @param [String] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def entity_specifier(arg)
      arg = arg.to_s.squish.presence or raise 'empty string'
      case arg
        when /^#{HANDLE_PREFIX}/ then { handle: arg }
        when /^author:/i         then { author: arg.sub(/^author:/i, '') }
        when /^title:/i          then { title:  arg.sub(/^title:/i, '') }
        else                          { title:  arg }
      end
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Fetch all DSpace Publications.
  #
  # @param [Hash] opt                 Passed to #lookup_publications.
  #
  # @return [Hash{String=>Entry}]
  #
  def publications(**opt)
    # noinspection RubyMismatchedReturnType
    lookup_publications(**opt)
  end

  # Fetch information about the given DSpace Publication entities.
  #
  # @param [Array<String,Hash>] publication   All Publications if empty.
  # @param [Hash]               opt           Passed to super.
  #
  # @return [Hash{String=>Entry}]
  #
  def lookup_publications(*publication, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*publication, **opt)
  end

end
