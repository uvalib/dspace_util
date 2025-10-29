# lib/dspace/person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API Person methods.

require_relative 'entity'

# Information about current DSpace Person entities.
#
module Dspace::Person

  include Dspace::Entity

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
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    # Fetch information about the given DSpace Person entities.
    #
    # @param [Array<String,Hash>] entity
    # @param [Hash]               opt       Passed to super.
    #
    # @return [Hash{String=>Entry}]
    #
    def execute(*entity, **opt)
      # noinspection RubyMismatchedReturnType
      super do |result, entry|
        if (parent = entry[:parent])
          entry[:department]  = entry[:name]
          entry[:institution] = result[parent]&.name || parent
        else
          entry[:institution] = entry[:name]
        end
      end
    end

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides - internal methods
    # =========================================================================

    protected

    # Transform DSpace API search result objects into Person entries.
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

    # Transform a DSpace API search result list object into a Person entry.
    #
    # @param [Hash] item
    #
    # @return [Entry]
    #
    def transform_entity_object(item)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item)
      entry[:name]         ||= field.(:'dc.title')
      entry[:org]          ||= field.(:'relation.isOrgUnitOfPerson')
      entry[:first_name]   ||= field.(:'person.givenName')
      entry[:last_name]    ||= field.(:'person.familyName')
      entry[:computing_id] ||= field.(:'person.identifier')
      unless entry[:first_name] && entry[:last_name]
        values = entity_specifier(entry[:name])
        entry[:first_name] ||= values[:first_name] if values[:first_name]
        entry[:last_name]  ||= values[:last_name]  if values[:last_name]
      end
      entry
    end

    # Generate a query for finding Person entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def entity_query(*arg, **opt)
      super(*arg, **opt, type: 'Person')
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
    # @param [String] arg
    #
    # @return [Hash{Symbol=>String}]
    #
    def entity_specifier(arg)
      arg = arg.to_s.squish.presence or raise 'empty string'
      if arg.include?(',')
        last, first = arg.split(',', 2).map(&:strip)
        { last_name: last, first_name: first }.compact
      elsif arg != arg.downcase
        { last_name: arg }
      else
        { computing_id: arg }
      end
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Fetch all DSpace Persons.
  #
  # @param [Hash] opt                 Passed to #lookup_persons.
  #
  # @return [Hash{String=>Entry}]
  #
  def persons(**opt)
    # noinspection RubyMismatchedReturnType
    lookup_persons(**opt)
  end

  # Fetch information about the given DSpace Person entities.
  #
  # @param [Array<String,Hash>] person    All Persons if empty.
  # @param [Hash]               opt       Passed to super.
  #
  # @return [Hash{String=>Entry}]
  #
  def lookup_persons(*person, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*person, **opt)
  end

end
