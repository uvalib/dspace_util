# src/dspace_import_zip/person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Accumulate author/contributor identities.

require 'common'
require 'logging'
require 'dspace'

require_relative 'collection'
require_relative 'entity'
require_relative 'xml'

# =============================================================================
# :section: Constants
# =============================================================================

UVA_DOMAIN = 'virginia.edu'

# =============================================================================
# :section: Classes
# =============================================================================

# An object which maintains data for Person entities to be created.
class Person < Entity

  # Methods which derive Person information from provided data.
  module Methods

    include Entity::Methods

    # =========================================================================
    # :section: Entity::Methods overrides
    # =========================================================================

    # Prefix for describing a key in diagnostic output.
    #
    # @return [String]
    #
    def key_label = 'Person'

    # Fields to use from LibraOpen export data.
    #
    # @return [Array<Symbol>]
    #
    def export_fields
      %i[first_name last_name computing_id department institution]
    end

    # Generate an ImportTable key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data     Person properties.
    #
    # @return [String, nil]             Hash key.
    #
    def key_for(data)
      return data[:table_key] if data[:table_key]
      data    = Import.wrap(data)
      parts   = Array.wrap(data[:computing_id]).presence
      parts ||= data.values_at(:last_name, :first_name)
      key_from(*parts)
    end

    # The name of the import subdirectory for a Person entity import.
    #
    # @param [Hash, String] data
    #
    # @return [String, nil]
    #
    def import_name(data)
      key = data.is_a?(Hash) ? key_for(data) : normalize(data)
      "#{PERSON_PREFIX}#{key}" if key.present?
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

    # Return a normalized ORCID value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def normalize_orcid(value, field: :orcid)
      value = value[field] if value.is_a?(Hash)
      value.to_s.strip.sub(%r{^https?://(\w+\.)*orcid\.org/}i, '').presence
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

  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    # Existing Persons acquired from DSpace.
    #
    # @return [Hash{String=>Dspace::Person::Entry}]
    #
    def current_table
      # noinspection RubyMismatchedReturnType
      @current_table ||= get_current_table
    end

    # All Person entity imports.
    #
    # @return [ImportTable]
    #
    def import_table
      @import_table ||= ImportTable.new
    end

    # Create a subdirectory for a Person entity import.
    #
    # @param [String] key             Import table key.
    # @param [Import] data
    #
    # @return [Boolean]
    #
    # @see /opt/dspace/config/registries/schema-person-types.xml
    #
    def make_import(key, data)
      subdir = import_name(key) or return
      files  = {
        'metadata_person.xml' => schema_xml(data),
        'metadata_dspace.xml' => entity_xml(data),
        'dublin_core.xml'     => metadata_xml(data),
        'collections'         => collections(data),
        'relationships'       => relationships(data),
      }
      write_import_files(subdir, files)
    end

    # =========================================================================
    # :section: DSpace data - Entity::ClassMethods overrides
    # =========================================================================

    protected

    # Acquire current Person entity data from DSpace.
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    #
    def get_current_data = Dspace.persons

    # The project-relative path to the `current_table` data storage file.
    #
    # @return [String]
    #
    def saved_table_path = 'tmp/saved/persons'

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" of a Person entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def entity_xml(data)
      super(**data, type: 'Person')
    end

    # Content for the "metadata_organization.xml" of a Person entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def schema_xml(data)
      Xml.new(schema: 'person') { |xml|
        xml.single(data[:computing_id], 'identifier')
        xml.single(data[:orcid],        'identifier', 'orcid')
        xml.single(data[:first_name],   'givenName')
        xml.single(data[:last_name],    'familyName')
        xml.single(data.entity_email,   'email')
      }.to_xml
    end

    # Content for the "dublin_core.xml" file of a Person entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def metadata_xml(data)
      Xml.new { |xml|
        xml.single(data.title_name,   'title')
        xml.single(data.entity_email, 'identifier')
      }.to_xml
    end

    # Content for the "collections" file of a Person entity import.
    #
    # @param [Import] _data
    #
    # @return [String, nil]
    #
    def collections(_data)
      handle = collection_handle('USR_COLLECTION')
      "#{handle}\n" if handle.present?
    end

    # Content for the "relationships" file of a Person entity import.
    #
    # @param [Import] data
    #
    # @return [String, nil]
    #
    def relationships(data)
      data.orgs.map { |org|
        key    = org.table_key
        term   = OrgUnit.current_table.dig(key, :uuid)
        term ||= "folderName:%s\n" % OrgUnit.import_name(key)
        "relation.isOrgUnitOfPerson #{term}"
      }.join("\n").presence
    end

  end

  extend ClassMethods

  # Data for a single Person entity import.
  class Import < Entity::Import

    include Methods

    def key_for     (data = nil) = super(data || self)
    def import_name (data = nil) = super(data || self)
    def title_name  (data = nil) = super(data || self)
    def entity_email(data = nil) = super(data || self)

    # Create a new Person::Import instance with computing_id and names
    # normalized.
    #
    # If `data[:export]` is present, `data[:export].orcid` is used to set
    # :orcid if :computing_id is found there.
    #
    # @param [Hash] data
    #
    def initialize(data)
      export = data[:export]
      super
      each_pair do |k, v|
        case k
          when :computing_id then self[k] = normalize_cid(v)
          when :first_name   then self[k] = normalize_first_name(v)
        end
      end
      if export.is_a?(ExportItem)
        self[:orcid] = export.orcid[self[:computing_id]]
      elsif (orc = self[:orcid])
        self[:orcid] = normalize_orcid(orc)
      end
      compact_blank!
      add_org(to_h)
    end

    # =========================================================================
    # :section: Entity::Import overrides
    # =========================================================================

    # The key for this instance in Person::ImportTable.
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

    # Return a duplicate of the current instance.
    #
    # @return [Import]
    #
    def dup
      super.tap { _1.add_org(self) }
    end

    # =========================================================================
    # :section:
    # =========================================================================

    # All of the OrgUnits associated with this Person.
    #
    # @return [Array<OrgUnit::Import>]
    #
    attr_reader :orgs

    # Add a unique organization.
    #
    # @param [Hash]    data
    # @param [Boolean] prepend        If true, add to the top of the list.
    #
    def add_org(data, prepend: false)
      @orgs ||= []
      other = data.is_a?(self.class) ? data.orgs : [OrgUnit::Import.wrap(data)]
      other = other.compact_blank
      if other.present?
        keys  = @orgs.map { _1.table_key }
        added = other.map { _1.dup unless keys.include?(_1.table_key) }.compact
        @orgs = prepend ? (added + @orgs) : (@orgs + added)
      end
    end

  end

  # All Person entity imports.
  #
  class ImportTable < Entity::ImportTable

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    # Generate the value entry derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data   Person properties.
    #
    # @return [Import]
    #
    def value_for(data)
      data.is_a?(Import) ? data.deep_dup : Import.new(data)
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # If the entry already exists in the table, resolve differences between the
    # existing at `key` and the potentially-different information in `val`.
    #
    # In particular, the result will be a value with orgs from both the added
    # and existing values.
    #
    # @param [String] key
    # @param [Import] val
    # @param [String] tag
    #
    # @return [Import, nil]
    #
    def merged_value_for(key, val, tag:)
      return if (current = self[key]).blank?
      val.add_org(current, prepend: true)
      # noinspection RubyMismatchedReturnType
      super
    end

  end

end
