# src/dspace_import_zip/publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Create the DSpace import directory from LibraOpen export directory.

require 'common'
require 'logging'

require_relative 'options'
require_relative 'collection'
require_relative 'export_item'
require_relative 'entity'
require_relative 'person'

# =============================================================================
# :section: Classes
# =============================================================================

# Encapsulates creation of Publication entities.
class Publication < Entity

  require_relative 'publication/content'
  require_relative 'publication/metadata'

  # Methods which derive Publication information from provided data.
  module Methods

    include Entity::Methods
    include Publication::Content
    include Publication::Metadata

    # =========================================================================
    # :section: Entity::Methods overrides
    # =========================================================================

    # The name of the import subdirectory for a Publication entity import.
    #
    # @param [Hash, String] data
    #
    # @return [String]
    #
    def import_name(data)
      name = data.is_a?(Hash) ? data[:import_name] : normalize(data)
      "#{IMPORT_PREFIX}#{name}" if name.present?
    end

    # =========================================================================
    # :section:
    # =========================================================================

    # Update `item` to include a mapping of depositor to ORCID.
    #
    # @param [ExportItem] item
    #
    # @return [ExportItem]            The item with `orcid` modified.
    # @return [nil]                   If :author_orcid_url was not present.
    #
    def set_orcid!(item)
      dat = item.work_metadata
      orc = Person.normalize_orcid(dat, field: :author_orcid_url) or return
      cid = Person.normalize_cid(dat, field: :depositor)
      item.orcid.merge!(cid => orc)
    end

  end

  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Class methods
    # =========================================================================

    # Add import subdirectories for each export.
    #
    # @param [Array<ExportItem>] exports
    # @param [Hash] opt                   Passed to #show_steps.
    #
    # @return [Integer]                   Number of subdirectories created.
    #
    def make_imports(exports, **opt)
      show_steps(exports, **opt) do |export|
        make_import(export)
      end
    end

    # Create a subdirectory for a Publication entity import.
    #
    # @param [ExportItem] export
    #
    # @return [Boolean]
    #
    def make_import(export)
      subdir = import_name(export) or return
      files  = {
        'metadata_dspace.xml' => entity_xml(export),
        'dublin_core.xml'     => metadata_xml(export),
        'collections'         => collections(export),
        'relationships'       => relationships(export),
      }
      write_import_files(subdir, files) and make_publication_content(export)
    end

    # =========================================================================
    # :section: Internal methods - import files
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" of a Publication entity import.
    #
    # @param [ExportItem] _export
    #
    # @return [String]
    #
    def entity_xml(_export)
      super(type: 'Publication')
    end

    # Content for the "dublin_core.xml" of a Publication entity import.
    #
    # As a side effect, `export.person` will be filled with the UUIDs of
    # authors associated with this item (but not contributors).
    #
    # @param [ExportItem] export
    #
    # @return [String]
    #
    def metadata_xml(export)
      publication_metadata(export)
    end

    # Content for the "collections" file of a Publication entity import.
    #
    # @param [ExportItem] _export
    #
    # @return [String, nil]
    #
    def collections(_export)
      handle = collection_handle('PUB_COLLECTION')
      "#{handle}\n" if handle.present?
    end

    # Content for the "relationships" file of a Publication entity import.
    #
    # @param [ExportItem] export
    #
    # @return [String, nil]
    #
    def relationships(export)
      export.person.map { |key|
        term = Person.current_table.dig(key, :uuid)
        term ||= "folderName:%s\n" % Person.import_name(key)
        "relation.isAuthorOfPublication #{term}"
      }.join("\n").presence
    end

  end

  extend ClassMethods

end
