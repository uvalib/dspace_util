# lib/dspace/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace entity.

require_relative 'api'

# Information about current DSpace entity items.
#
module Dspace::Entity

  include Dspace::Api

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for an entity acquired from the DSpace API.
  #
  class Entry < Hash

    def name    = self[__method__] # May be non-unique
    def uuid    = self[__method__]
    def handle  = self[__method__]

    KEYS = instance_methods(false).freeze

    def self.keys = const_get(:KEYS)
    def self.default_key = :uuid

    # Initialize the entry with the provided hash value.
    #
    # @param [Hash, nil] obj          Provided directly or:
    # @param [Hash]      opt          Provided as keyword arguments.
    #
    def initialize(obj = nil, **opt)
      update((obj || opt).slice(*self.class.keys).compact)
    end

  end

  # Acquire entities from DSpace.
  #
  class Lookup

    include Dspace::Api

    # =========================================================================
    # :section: Methods
    # =========================================================================

    public

    # Fetch information about the given DSpace entities.
    #
    # @param [Array<String,Hash>] entity
    # @param [String, nil]        scope     Limit to the given collection.
    # @param [Boolean, nil]       no_show   If false then show page progress.
    # @param [Symbol, nil]        sort_key  One of `Entry#keys`.
    # @param [Hash]               opt       Passed to #get_objects.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*entity, scope: nil, no_show: nil, sort_key: :name, **opt)
      opt[:query] = entity_query(*entity) unless opt.key?(:query)
      opt[:scope] = entity_scope(scope)   unless scope.nil?

      # Get the initial page of results.
      start       = Time.now
      list, pages = get_entity_objects(**opt)
      result = transform_entity_objects(list, **opt)

      # If more pages are available, get each of them in sequence.
      if pages > 1
        no_show = show_steps_off if no_show.nil?
        ss_opt  = { start: start, marker: '.', no_show: no_show }
        show_char ss_opt[:marker] unless no_show # For completion of page 0.
        show_steps(1...pages, **ss_opt) do |page|
          list, _ = get_entity_objects(**opt, page: page)
          result.merge!(transform_entity_objects(list, **opt))
        end
      end

      # Allow the subclass to adjust the results.
      if block_given?
        result.each_pair do |_, entry|
          yield(result, entry)
        end
      end

      sort_key ? result.sort_by { |_, entry| entry[sort_key] }.to_h : result
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Fetch the DSpace API search result objects for entities.
    #
    # @param [String] query           Full query term.
    # @param [Hash]   opt             Passed to #dspace_api.
    #
    # @return [Array<(Array<Hash>,Integer)>] Objects and total number of pages.
    #
    def get_entity_objects(query:, **opt)
      opt.delete(:result_key) # Not appropriate in this context.
      opt.reverse_merge!(query: query).compact_blank!
      data  = dspace_api('discover/search/objects', dsoType: 'item', **opt)
      data  = data.dig(:_embedded, :searchResult) || {}
      pages = data.dig(:page, :totalPages) || 1
      items = Array.wrap(data.dig(:_embedded, :objects))
      return items, pages
    end

    # Transform DSpace API search result objects into entries.
    #
    # @param [Array<Hash>] list
    # @param [Symbol]      result_key   One of `Entry#keys`.
    #
    # @return [Hash{String=>Entry}]
    #
    def transform_entity_objects(list, result_key: Entry.default_key, **)
      list.map { |item|
        item  = item.dig(:_embedded, :indexableObject)
        entry = transform_entity_object(item)
        key   = entry[result_key]
        [key, entry]
      }.to_h
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

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Return the UUID associated with the given collection identity.
    #
    # @param [String, nil] arg        Collection name, handle or UUID.
    # @param [Boolean]     fatal      If *false*, allow failed scope lookup.
    #
    # @return [String]                Scope UUID.
    # @return [nil]                   Not *fatal* and *arg* scope not found.
    #
    def entity_scope(arg, fatal: true)
      return if arg.nil? || (arg = arg.squish).blank?
      return arg if uuid?(arg)
      if (hdl = handle?(arg))
        Dspace.collections.find { |_, c| return c.uuid if arg == c.handle }
      else
        Dspace.collections.find { |_, c| return c.uuid if arg == c.name }
      end
      if fatal
        identifier = hdl ? 'handle' : 'name'
        error { "#{arg.inspect} is not a valid collection #{identifier}" }
        exit(false)
      end
    end

    # Generate a query for finding entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [String, nil]        type
    #
    # @return [String]
    #
    def entity_query(*arg, type: nil, **)
      arg.map! { '(%s)' % entity_terms(_1) }
      res = []
      res << "dspace.entity.type:#{type}" if type.present?
      res << '(%s)' % arg.join('+OR+')    if arg.present?
      res.join('+AND+')
    end

    # Transform the argument into a compound query term.
    #
    # @param [String, Hash{Symbol=>*}] arg
    #
    # @return [String]
    #
    def entity_terms(arg)
      arg  = entity_criteria(arg)
      term = entity_term(arg)
      term.is_a?(Array) ? term.join('+AND+') : term.to_s
    end

    # Transform the argument into a query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def entity_term(arg)
      name, handle = entity_values(arg, :name, :handle)
      term = []
      term << "handle:#{handle}" if handle
      term << "name:#{name}"     if name
      term
    end

    # Extract values from the argument for use in a URL parameter.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String,nil>]
    #
    def entity_values(arg, *keys)
      arg.values_at(*keys).map do |v|
        CGI.escapeURIComponent(v) unless (v = v.to_s.squish).blank?
      end
    end

    # Transform the argument into properties for #entity_terms.
    #
    # @param [String, Hash{Symbol=>*}] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def entity_criteria(arg)
      case arg
        when Hash   then arg.compact
        when String then entity_specifier(arg)
        else             raise "not a String or Hash: #{arg.inspect}"
      end
    end

    # Transform the String argument into properties for #entity_terms.
    #
    # @param [String] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def entity_specifier(arg)
      arg = arg&.squish
      case
        when arg.blank?   then raise 'empty string'
        when handle?(arg) then { handle: arg }
        else                   { name:   arg }
      end
    end

  end

end
