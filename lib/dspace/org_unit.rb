# lib/dspace/org_unit.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API OrgUnit methods.

require_relative 'entity'

module Dspace::OrgUnit

  include Dspace::Entity

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  class Entry < Dspace::Entity::Entry

    def parent      = self[__method__] # UUID of parent organization
    def department  = self[__method__] # Entry name if a department.
    def institution = self[__method__] # Entry name if not a department
    def table_key   = self[__method__] # Key for current_table.

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

  end

  class Lookup < Dspace::Entity::Lookup

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    # Fetch information about the given DSpace OrgUnit entities.
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

    # Transform DSpace API search result objects into OrgUnit entries.
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

    # Transform a DSpace API search result list object into an OrgUnit entry.
    #
    # @param [Hash] item
    #
    # @return [Entry]
    #
    def transform_entity_object(item)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item)
      entry[:name]      ||= field.(:'organization.legalName')
      entry[:parent]    ||= field.(:'organization.parentOrganization')
      entry[:table_key] ||= field.(:'organization.identifier')
      entry
    end

    # Generate a query for finding OrgUnit entities.
    #
    # @param [Array<String,Hash>] arg
    # @param [Hash]               opt   Passed to super.
    #
    # @return [String]
    #
    def entity_query(*arg, **opt)
      super(*arg, **opt, type: 'OrgUnit')
    end

    # Transform the argument into an OrgUnit query term.
    #
    # @param [Hash{Symbol=>String}] arg
    #
    # @return [Array<String>]
    #
    def entity_term(arg)
      name, handle = entity_values(arg, :name, :handle)
      term = []
      term << "handle:#{handle}"               if handle
      term << "organization.legalName:#{name}" if name
      term
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Fetch all DSpace OrgUnits.
  #
  # @param [Hash] opt                 Passed to #lookup_orgs.
  #
  # @return [Hash{String=>Entry}]
  #
  def orgs(**opt)
    # noinspection RubyMismatchedReturnType
    lookup_orgs(**opt)
  end

  # Fetch information about the given DSpace OrgUnit entities.
  #
  # @param [Array<String,Hash>] org       All OrgUnits if empty.
  # @param [Hash]               opt       Passed to super.
  #
  # @return [Hash{String=>Entry}]
  #
  def lookup_orgs(*org, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.execute(*org, **opt)
  end

end
