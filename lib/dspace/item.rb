# lib/dspace/item.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API generic item methods.

require 'dspace/api'

# Information about current DSpace generic items.
#
module Dspace::Item

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for an item acquired from the DSpace API.
  #
  class Entry < Hash

    include Dspace::Api

    def name    = self[__method__] # May be non-unique
    def uuid    = self[__method__]
    def handle  = self[__method__]

    KEYS = instance_methods(false).freeze

    def self.keys = const_get(:KEYS)
    def self.default_key = :uuid

    # Initialize the entry with the provided hash value.
    #
    # @param [Hash, nil]    obj       Provided directly or:
    # @param [Hash]         opt       Provided via keyword arguments.
    # @param [Boolean, nil] full      Ignored in the base class.
    #
    def initialize(obj = nil, full: nil, **opt)
      raise "Has both obj and opt=#{opt}" if obj.present? && opt.present?
      update((obj || opt).slice(*self.class.keys).compact_blank)
    end

    # =========================================================================
    # :section: Hash overrides
    # =========================================================================

    public

    def inspect
      "#{self.class.name}=#{super}"
    end

    # =========================================================================
    # :section: Methods
    # =========================================================================

    public

    # The display for this entry.
    #
    # @return [String]
    #
    def title
      self[:name] || '???'
    end

    # Indicate whether the target string matches an aspect of this entry.
    #
    # @param [String]  target
    # @param [Boolean] any_field      If *true*, consider all fields.
    #
    def match?(target, any_field = false)
      case
        when target.blank?                then false
        when any_field && uuid?(target)   then target == self[:uuid]
        when any_field && handle?(target) then target == self[:handle]
        else                                   target == self[:name]
      end
    end

  end

  # Acquire items from DSpace.
  #
  class Lookup

    include Dspace::Api::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace items.
    #
    # @param [Array<String,Hash>] item    Specific items to find.
    # @param [String, nil]        scope   Limit to the given Collection.
    # @param [Hash]               opt     Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*item, scope: nil, **opt, &blk)
      opt[:query] = item_query(*item) unless opt.key?(:query)
      opt[:scope] = item_scope(scope) unless scope.nil?
      super(**opt, &blk)
    end

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    protected

    # Fetch the DSpace API search result objects.
    #
    # @param [String] query           Full query term.
    # @param [Hash]   opt             Passed to #dspace_api.
    #
    # @return [Array<(Array<Hash>,Integer)>] Objects and total number of pages.
    #
    def get_items(query:, **opt)
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
    # @param [Hash]        opt          Passed to #transform_item.
    #
    # @return [Hash{String=>Entry}]
    #
    def transform_items(list, result_key: Entry.default_key, **opt)
      list.map { |item|
        item  = item.dig(:_embedded, :indexableObject)
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
    # @return [Entry]
    #
    def transform_item(item, **opt)
      Entry.new(item, **opt)
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Return the UUID associated with the given Collection identity.
    #
    # @param [String, nil] arg        Collection name, handle or UUID.
    # @param [Boolean]     fatal      If *false*, allow failed scope lookup.
    #
    # @return [String]                Scope UUID.
    # @return [nil]                   Not *fatal* and *arg* scope not found.
    #
    def item_scope(arg, fatal: true)
      return if arg.nil? || (arg = arg.squish).blank?
      return arg if uuid?(arg)
      if (hdl = handle?(arg))
        Dspace.collections.find { |_, c| return c.uuid if arg == c.handle }
      else
        Dspace.collections.find { |_, c| return c.uuid if c.match?(arg) }
      end
      if fatal
        identifier = hdl ? 'handle' : 'name'
        error { "#{arg.inspect} is not a valid collection #{identifier}" }
        exit(false)
      end
    end

    # Generate a query for finding items.
    #
    # @param [Array<String,Hash>] arg
    # @param [String, nil]        entity_type
    #
    # @return [String]
    #
    def item_query(*arg, entity_type: nil, **)
      arg.map! { '(%s)' % item_terms(_1) }
      res = []
      res << "dspace.entity.type:#{entity_type}" if entity_type.present?
      res << '(%s)' % arg.join('+OR+')           if arg.present?
      res.join('+AND+')
    end

    # Transform the argument into a compound query term.
    #
    # @param [String, Hash{Symbol=>*}] arg
    #
    # @return [String]
    #
    def item_terms(arg)
      arg  = item_criteria(arg)
      term = item_term(arg)
      term.is_a?(Array) ? term.join('+AND+') : term.to_s
    end

    # Transform the argument into a query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def item_term(arg)
      name, handle = item_values(arg, :name, :handle)
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
    def item_values(arg, *keys)
      arg.values_at(*keys).map do |v|
        CGI.escapeURIComponent(v) unless (v = v.to_s.squish).blank?
      end
    end

    # Transform the argument into properties for #item_terms.
    #
    # @param [String, Hash{Symbol=>*}] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def item_criteria(arg)
      case arg
        when Hash   then arg.compact
        when String then item_specifier(arg)
        else             raise "not a String or Hash: #{arg.inspect}"
      end
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
        when arg.blank?   then raise 'empty string'
        when handle?(arg) then { handle: arg }
        else                   { name:   arg }
      end
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
