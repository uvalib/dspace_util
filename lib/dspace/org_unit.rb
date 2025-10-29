# lib/dspace/org_unit.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API OrgUnit methods.

require 'dspace/entity'
require 'org_unit'

# Information about current DSpace OrgUnit entities.
#
module Dspace::OrgUnit

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for an OrgUnit entity acquired from the DSpace API.
  #
  class Entry < Dspace::Entity::Entry

    def parent      = self[__method__] # UUID of parent organization
    def department  = self[__method__] # Entry name if a department.
    def institution = self[__method__] # Entry name if not a department
    def table_key   = self[__method__] # Key for current_table.

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

  end

  # Acquire OrgUnit entities from DSpace.
  #
  class Lookup < Dspace::Entity::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    public

    # Fetch information about the given DSpace OrgUnit entities.
    #
    # @param [Array<String,Hash>] item  Specific OrgUnits to find.
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

    # Transform DSpace API search result objects into OrgUnit entries.
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

    # Transform a DSpace API search result list object into an OrgUnit entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Entry]
    #
    def transform_item(item, **opt)
      field = ->(f) { Array.wrap(item.dig(:metadata, f)).first&.dig(:value) }
      entry = Entry.new(item, **opt)
      entry[:name]      ||= field.(:'organization.legalName')
      entry[:parent]    ||= field.(:'organization.parentOrganization')
      entry[:table_key] ||= field.(:'organization.identifier')
      entry
    end

    # =========================================================================
    # :section: Dspace::Entity::Lookup overrides
    # =========================================================================

    protected

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

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    public

    # Existing OrgUnits acquired from DSpace.
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
    # @param [Hash{Symbol=>*}] data   Department properties.
    #
    # @return [String, nil]           Hash key.
    #
    def key_for(data)
      ::OrgUnit.key_for(data)
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
      @storage_path ||= super(file: "tmp/saved/#{DEPLOYMENT}/orgs.json")
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace OrgUnit entities.
  #
  # @param [Array<String,Hash>] item  All OrgUnits if empty.
  # @param [Hash]               opt   Passed to Lookup#find_or_fetch.
  #
  # @return [Hash{String=>Entry}]
  #
  def orgs(*item, **opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.find_or_fetch(*item, **opt)
  end

end
