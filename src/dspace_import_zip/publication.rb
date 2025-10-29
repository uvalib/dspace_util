# src/dspace_import_zip/publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Extensions for importing DSpace Publication entities.

require 'common'
require 'logging'
require 'publication'

require_relative 'options'
require_relative 'collection'
require_relative 'embargo'
require_relative 'export_item'
require_relative 'entity'

# =============================================================================
# :section: Classes
# =============================================================================

# Whether embargo metadata should be included.
#
# @type [Boolean]
#
EMBARGO = (ENV['EMBARGO'] != 'false')

# Extensions for importing DSpace Publication entities.
#
class Publication

  require_relative 'publication/content'
  require_relative 'publication/metadata'

  # Extensions for importing DSpace Publication entities.
  #
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

  # Methods associated with the Publication class.
  #
  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    # Add import subdirectories for each export.
    #
    # @param [Array<ExportItem>] exports
    # @param [Hash] opt                   Passed to #mark_steps.
    #
    # @return [Integer]                   Number of subdirectories created.
    #
    def make_imports(exports, **opt)
      mark_steps(exports, **opt) do |export|
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
        'metadata_local.xml'  => schema_xml(export),
        'dublin_core.xml'     => metadata_xml(export),
        'collections'         => collections(export),
        'relationships'       => relationships(export),
      }
      write_import_files(subdir, files) and make_content(export)
    end

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" of a Publication entity import.
    #
    # @param [ExportItem] _export
    #
    # @return [String]
    #
    def entity_xml(_export)
      super(entity_type: 'Publication')
    end

    # Content for the "metadata_local.xml" file of a Publication entity import.
    #
    # @param [ExportItem] export
    # @param [String]     schema
    #
    # @return [String, nil]
    #
    def schema_xml(export, schema: 'local')
      return unless EMBARGO && (embargo = Embargo.new(export)).active?
      Xml.new(schema: schema) { |xml|
        xml.single(embargo.terms, 'embargo', 'terms')
        xml.single(embargo.lift,  'embargo', 'lift')
      }.to_xml
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
      make_metadata(export)
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
        val   = Person.current_table.dig(key, :uuid)
        val ||= (subdir = Person.import_name(key)) && "folderName:#{subdir}\n"
        "relation.isAuthorOfPublication #{val}" if val
      }.compact.join("\n").presence
    end

  end

  extend ClassMethods

end
