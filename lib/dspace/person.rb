# lib/dspace/person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API Person methods.

require 'dspace/entity'
require 'person'

# Information about current DSpace Person entities.
#
module Dspace::Person

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for a Person entity acquired from the DSpace API.
  #
  class Entry < Dspace::Entity::Entry

    def org          = self[__method__] # Probably non-unique.
    def first_name   = self[__method__]
    def last_name    = self[__method__]
    def computing_id = self[__method__] # Missing for non-UVA persons.
    def table_key    = self[__method__] # Key for current_table.

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

  end

  # Acquire Person entities from DSpace.
  #
  class Lookup < Dspace::Entity::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace Person entities.
    #
    # @param [Array<String,Hash>] item  Specific Persons to find.
    # @param [Hash]               opt   Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*item, **opt)
      # noinspection RubyMismatchedReturnType
      super do |result, entry|
        unless entry[:institution].present? || (parent = entry[:parent]).blank?
          inst = result[parent]&.name
          inst = nil if ::OrgUnit.uva_org_name?(inst)
          entry[:institution] = inst || parent
        end
      end
    end

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    protected

    # Transform DSpace API search result objects into Person entries.
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

    # Transform a DSpace API search result list object into a Person entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Entry]
    #
    def transform_item(item, **opt)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item, **opt)
      entry[:name]         ||= field.(:'dc.title')
      entry[:org]          ||= field.(:'relation.isOrgUnitOfPerson')
      entry[:first_name]   ||= field.(:'person.givenName')
      entry[:last_name]    ||= field.(:'person.familyName')
      entry[:computing_id] ||= field.(:'person.identifier')
      unless entry[:first_name] && entry[:last_name]
        values = entity_specifier(entry[:name], fatal: false)
        entry[:first_name] ||= values[:first_name] if values[:first_name]
        entry[:last_name]  ||= values[:last_name]  if values[:last_name]
      end
      entry
    end

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    protected

    # Generate a query for finding Person entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def entity_query(*arg, **opt)
      super(*arg, **opt, entity_type: 'Person')
    end

    # Transform the argument into a Person query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def entity_term(arg)
      cid, last, first =
        entity_values(arg, :computing_id, :last_name, :first_name)
      term = []
      term << "person.identifier:#{cid}"  if cid
      term << "person.familyName:#{last}" if last
      term << "person.givenName:#{first}" if last && first
      term
    end

    # Transform the String argument into properties for #person_term.
    #
    # @param [String]  arg
    # @param [Boolean] fatal          If *false*, return empty hash.
    #
    # @return [Hash{Symbol=>String}]
    #
    def entity_specifier(arg, fatal: true)
      arg = arg.to_s.squish
      if arg.blank?
        raise 'empty string' if fatal
        {}
      elsif arg.include?(',')
        last, first = arg.split(',', 2).map(&:strip)
        { last_name: last, first_name: first }.compact
      elsif arg != arg.downcase
        { last_name: arg }
      else
        { computing_id: arg }
      end
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    public

    # Existing Persons acquired from DSpace.
    #
    # @param [Hash] opt               To #get_current_table on first run.
    #
    # @return [Hash{String=>Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= super
    end

    # Generate a table key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data   Person properties.
    #
    # @return [String, nil]           Hash key.
    #
    def key_for(data)
      ::Person.key_for(data)
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
      @storage_path ||= super(file: "tmp/saved/#{DEPLOYMENT}/persons.json")
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace Person entities.
  #
  # @param [Array<String,Hash>] item  All Persons if empty.
  # @param [Hash]               opt   Passed to Lookup#find_or_fetch.
  #
  # @return [Hash{String=>Entry}]
  #
  def persons(*item, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.find_or_fetch(*item, **opt)
  end

end
