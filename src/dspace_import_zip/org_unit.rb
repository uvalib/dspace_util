# src/dspace_import_zip/org_unit.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Extensions for importing DSpace OrgUnit entities.

require 'common'
require 'logging'
require 'org_unit'

require_relative 'collection'
require_relative 'entity'
require_relative 'xml'

# =============================================================================
# :section: Classes
# =============================================================================

# Extensions for importing DSpace OrgUnit entities.
#
class OrgUnit

  # Extensions for importing DSpace OrgUnit entities.
  #
  module Methods

    include Entity::Methods

    # The name of the import subdirectory for an OrgUnit entity import.
    #
    # @param [Hash, String] data
    #
    # @return [String, nil]
    #
    def import_name(data)
      key = data.is_a?(Hash) ? key_for(data) : normalize(data)
      "#{ORG_PREFIX}#{key}" if key.present?
    end

  end

  # Extensions for importing DSpace OrgUnit entities.
  #
  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    # All OrgUnit entity imports.
    #
    # @return [ImportTable]
    #
    def import_table
      @import_table ||= ImportTable.new
    end

    # Create a subdirectory for an OrgUnit entity import.
    #
    # @param [String] key             Import table key.
    # @param [Import] data
    #
    # @return [Boolean]
    #
    # @see /opt/dspace/config/registries/schema-organization-types.xml
    #
    def make_import(key, data)
      subdir = import_name(key) or return
      files  = {
        'metadata_organization.xml' => schema_xml(data),
        'metadata_dspace.xml'       => entity_xml(data),
        'dublin_core.xml'           => metadata_xml(data),
        'collections'               => collections(data),
      }
      write_import_files(subdir, files)
    end

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" of an OrgUnit entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def entity_xml(data)
      super(**data, entity_type: 'OrgUnit')
    end

    # Content for the "metadata_organization.xml" of an OrgUnit entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def schema_xml(data)
      Xml.new(schema: 'organization') { |xml|
        xml.single(data.title_name, 'legalName')
        xml.single(data.key_for,    'identifier')
      }.to_xml
    end

    # Content for the "dublin_core.xml" file of an OrgUnit entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def metadata_xml(data)
      Xml.new { |xml|
        xml.single(data.title_name, 'title')
        xml.multi(data.description, 'description')
      }.to_xml
    end

    # Content for the "collections" file of an OrgUnit entity import.
    #
    # @param [Import] _data
    #
    # @return [String, nil]
    #
    def collections(_data)
      handle = collection_handle('ORG_COLLECTION')
      "#{handle}\n" if handle.present?
    end

  end

  extend ClassMethods

  # Extensions for importing DSpace OrgUnit entities.
  #
  class Import < Entity::Import

    include Methods

    def import_name (data = nil) = super(data || self)

  end

  # All OrgUnit entity imports.
  #
  class ImportTable < Entity::ImportTable

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    # Generate the value entry derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data   Entry properties.
    #
    # @return [Import]
    #
    def value_for(data)
      data.is_a?(Import) ? data.deep_dup : Import.new(data)
    end

  end

end
