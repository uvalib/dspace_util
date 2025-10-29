# src/dspace_import_zip/person.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Extensions for importing DSpace Person entities.

require 'common'
require 'logging'
require 'person'

require_relative 'collection'
require_relative 'export_item'
require_relative 'entity'
require_relative 'xml'

# =============================================================================
# :section: Classes
# =============================================================================

# Extensions for importing DSpace Person entities.
#
class Person

  # Extensions for importing DSpace Person entities.
  #
  module Methods

    include Entity::Methods

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

  end

  # Extensions for importing DSpace Person entities.
  #
  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

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
      super(**data, entity_type: 'Person')
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
        key   = org.table_key
        val   = OrgUnit.current_table.dig(key, :uuid)
        val ||= (subdir = OrgUnit.import_name(key)) && "folderName:#{subdir}\n"
        "relation.isOrgUnitOfPerson #{val}" if val
      }.compact.join("\n").presence
    end

  end

  extend ClassMethods

  # Extensions for importing DSpace Person entities.
  #
  class Import < Entity::Import

    include Methods

    def import_name (data = nil) = super(data || self)

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Complete instance initialization for import.
    #
    # If `data[:export]` is present, `data[:export].orcid` is used to set
    # :orcid if :computing_id is found there.
    #
    # @param [Hash] data
    #
    # @return [void]
    #
    def finish_initialize(data)
      if (e = data[:export]).is_a?(ExportItem)
        orcid = e.orcid[self[:computing_id]]
      else
        orcid = normalize_orcid(data)
      end
      self[:orcid] = orcid if orcid
      add_org(to_h)
    end

    # =========================================================================
    # :section: Entity::Import overrides
    # =========================================================================

    public

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

    public

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
    # @return [Import]                Original *val* if not present in table.
    #
    def merged_value_for(key, val, tag:)
      return val if (current = self[key]).blank?
      val.add_org(current, prepend: true)
      # noinspection RubyMismatchedReturnType
      super
    end

  end

end
