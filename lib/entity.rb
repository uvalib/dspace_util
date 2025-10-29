# lib/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Abstract base class for DSpace entity types.

require 'common'
require 'logging'

# =============================================================================
# :section: Classes
# =============================================================================

# Abstract base class for DSpace entity types.
#
class Entity

  # Methods which derive entity information from provided data.
  #
  module Methods

    # Prefix for describing an entity in diagnostic output.
    #
    # @return [String]
    #
    def type_label = 'Entity'

    # Generate a table key derived from the given data.
    #
    # @param [Hash] data
    #
    # @return [String, nil]           Import table key.
    #
    def key_for(data) = to_be_overridden

    # Fields to use from LibraOpen export data.
    #
    # @return [Array<Symbol>]
    #
    def export_fields = to_be_overridden

    # Name of the entity for use in titles.
    #
    # @param [Hash] data
    #
    # @return [String, nil]
    #
    def title_name(data) = to_be_overridden

    # Description line(s).
    #
    # @param [Hash] data
    #
    # @return [Array<String>]
    #
    def description(data) = []

    # Email address associated with the entity.
    #
    # @param [Hash] data
    #
    # @return [String, nil]
    #
    def entity_email(data) = to_be_overridden

    # For strings, strip leading and trailing whitespace, reduce internal
    # whitespace to a single space.  If the result is nil or empty, return nil.
    #
    # @param [any, nil] v
    #
    # @return [any, nil]
    #
    def normalize(v)
      v = v.squish.gsub(/\\u0026/, '&').sub(/[.,;:]+$/, '') if v.is_a?(String)
      v.presence
    end

  end

  # Methods associated with the Entity class.
  #
  module ClassMethods

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Existing entities acquired from DSpace.
    #
    # @param [Hash] opt               To getter method on first run.
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    #
    def current_table(**opt) = to_be_overridden

  end

  extend ClassMethods

  # Base class for holding the data for a single entity import.
  #
  class Import < Hash

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Create a new Entity::Import instance.
    #
    # @param [Hash] data
    #
    def initialize(data)
      data = extract_fields(data) unless data.is_a?(Import)
      update(data)
    end

    # Return a hash with clean values.
    #
    # @param [Hash] data
    #
    # @return [Hash]
    #
    def extract_fields(data)
      data.slice(*export_fields).transform_values { normalize(_1) }.compact
    end

    # The key for this instance in a table of entities.
    #
    # @return [String]
    #
    def table_key = to_be_overridden

    # Create a new instance if necessary.
    #
    # @param [Import, Hash] data
    #
    # @return [Import]
    #
    def self.wrap(data)
      # noinspection RubyMismatchedReturnType
      data.is_a?(self) ? data : new(data)
    end

    # =========================================================================
    # :section: Hash overrides
    # =========================================================================

    public

    def inspect
      "#{self.class.name}=#{super}"
    end

  end

end
