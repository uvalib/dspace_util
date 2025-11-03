# lib/person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace Person entity type.

require 'dspace'
require 'entity'
require 'org_unit'

# =============================================================================
# :section: Constants
# =============================================================================

UVA_DOMAIN ||= 'virginia.edu'

# =============================================================================
# :section: Classes
# =============================================================================

# An object which maintains data for Person entities to be created.
#
class Person < Entity

  # Methods which derive Person information from provided data.
  #
  module Methods

    include Entity::Methods

    # =========================================================================
    # :section: Entity::Methods overrides
    # =========================================================================

    public

    # Prefix for describing an entity in diagnostic output.
    #
    # @return [String]
    #
    def type_label = 'Person'

    # Fields to use from LibraOpen export data.
    #
    # @return [Array<Symbol>]
    #
    def export_fields
      %i[first_name last_name computing_id department institution]
    end

    # Generate a table key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data   Person properties.
    #
    # @return [String, nil]           Hash key.
    #
    def key_for(data)
      return data[:table_key] if data[:table_key]
      data   = Import.wrap(data)
      part   = Array.wrap(data[:computing_id]).compact_blank.presence
      part ||= data.values_at(:last_name, :first_name).compact_blank.presence
      part ||= data.values_at(:institution, :department).compact_blank
      key_from(*part)
    end

    # Name of the person in bibliographic order for use in titles.
    #
    # @param [Hash] data
    #
    # @return [String, nil]
    #
    def title_name(data)
      Import.wrap(data).values_at(:last_name, :first_name).compact.join(', ')
    end

    # Email address associated with the Person.
    #
    # @param [Hash] data
    #
    # @return [String, nil]
    #
    def entity_email(data)
      cid = Import.wrap(data)[:computing_id]
      cid.include?('@') ? cid : "#{cid}@#{UVA_DOMAIN}" if cid.present?
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Return a normalized UVA computing ID value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def normalize_cid(value, field: :computing_id)
      value = value[field] if value.is_a?(Hash)
      value.to_s.strip.downcase.sub(/@(\w+\.)*virginia\.edu$/, '').presence
    end

    # Return a normalized given name.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def normalize_first_name(value, field: :first_name)
      value = value[field] if value.is_a?(Hash)
      value.to_s.squish.delete_prefix('Dr. ').presence
    end

  end

  # Methods associated with the Person class.
  #
  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    public

    # Existing Persons acquired from DSpace.
    #
    # @param [Hash] opt               To Dspace#persons on first run.
    #
    # @return [Hash{String=>Dspace::Person::Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= Dspace.persons(**opt)
    end

  end

  extend ClassMethods

  # Data for a single Person entity import.
  #
  class Import < Entity::Import

    include Methods

    def key_for     (data = nil) = super(data || self)
    def title_name  (data = nil) = super(data || self)
    def entity_email(data = nil) = super(data || self)

    # Create a new Person::Import instance with computing_id and names
    # normalized.
    #
    # @param [Hash] data
    #
    def initialize(data)
      super
      each_pair do |k, v|
        case k
          when :computing_id then self[k] = normalize_cid(v)
          when :first_name   then self[k] = normalize_first_name(v)
        end
      end
      compact_blank!
      self[:last_name] ||= self[:department] || self[:institution]
      finish_initialize(data)
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Complete instance initialization.
    #
    # @param [Hash] _data
    #
    # @return [void]
    #
    def finish_initialize(_data)
    end

    # =========================================================================
    # :section: Entity::Import overrides
    # =========================================================================

    public

    # The key for this instance in a table of Person entities.
    #
    # @return [String]
    #
    def table_key
      # noinspection RubyMismatchedReturnType
      @table_key ||= key_for(self)
    end

    # Create a new instance if necessary.
    #
    # @param [Import, Hash] data
    #
    # @return [Import]
    #
    def self.wrap(data)
      # noinspection RubyMismatchedReturnType
      super
    end

  end

end
