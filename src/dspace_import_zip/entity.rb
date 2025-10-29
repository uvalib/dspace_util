# src/dspace_import_zip/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating LibraOpen export to an import "metadata_dspace.xml".

require 'common'
require 'logging'

require_relative 'options'
require_relative 'xml'

# =============================================================================
# :section: Classes
# =============================================================================

# Abstract base class for DSpace entity types.
class Entity

  # Methods which derive entity information from provided data.
  module Methods

    # Prefix for describing a key in diagnostic output.
    #
    # @return [String]
    #
    def key_label = 'Entity'

    # Generate an ImportTable key derived from the given data.
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

    # The name of the import subdirectory for an entity import.
    #
    # @param [Hash, String] data
    #
    # @return [String, nil]
    #
    def import_name(data) = to_be_overridden

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
    # whitespace to a single space.  If the result is blank or nil, return nil.
    #
    # @param [*] v
    #
    # @return [*, nil]
    #
    def normalize(v)
      v = v.squish.gsub(/\\u0026/, '&').sub(/[.,;:]+$/, '') if v.is_a?(String)
      v.presence
    end

    # Form a key from individual part(s).
    #
    # Because the key is used as the basis of a subdirectory name, this method
    # ensures that the result does not end with '.' because that could be a
    # problem for `mkdir`.
    #
    # @param [Array<String>] parts
    # @param [String]        connector
    #
    # @return [String, nil]
    #
    def key_from(*parts, connector: '+')
      parts.compact_blank!
      parts.map! { CGI.escapeURIComponent(_1.downcase) }
      parts.join(connector).delete_suffix('.') unless parts.blank?
    end

  end

  module ClassMethods

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    # Existing entities acquired from DSpace.
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    #
    def current_table = to_be_overridden

    # All entity imports.
    #
    # @return [ImportTable]
    #
    def import_table = to_be_overridden

    # Add an entry to `import_table` unless it is already present in
    # `current_table`.
    #
    # @param [Hash]    data           Entry properties.
    # @param [Boolean] force          If true add unconditionally.
    #
    # @return [String, nil]           ID added.
    #
    def add_import(data, force: false)
      tag = "#{key_label}.#{__method__}"
      if (key = key_for(data)).nil?
        debug { "#{tag}: no key derivable from #{data.inspect}" }
      elsif !force && current_table.key?(key)
        info { "#{tag}: #{key}: already in current_table" }
      else
        import_table.add(data, key: key)
      end
    end

    # Add import subdirectories for each entity referenced by the subclass.
    #
    # @param [Hash] opt               Passed to #show_steps.
    #
    # @return [Integer]               Number of subdirectories created.
    #
    def make_imports(**opt)
      show_steps(import_table, **opt) do |key, data|
        make_import(key, data)
      end
    end

    # Create a subdirectory for an entity import.
    #
    # @param [String] key             Import table key.
    # @param [Import] data
    #
    # @return [Boolean]
    #
    def make_import(key, data) = to_be_overridden

    # Create the import subdirectory and its files.
    #
    # @param [String] dir             Subdirectory name.
    # @param [Hash]   files           File/content mapping.
    # @param [String] root            Top-level import directory.
    #
    # @return [Boolean]
    #
    def write_import_files(dir, files, root: option.import_root, **)
      dir_path = make_import_subdir(dir, root: root)
      files.each_pair do |file, content|
        next if content.blank?
        content += "\n" unless content.end_with?("\n")
        file_path = File.expand_path(file, dir_path)
        File.write(file_path, content)
      end
      true
    rescue => err
      error { "#{__method__}(#{dir}): #{err}" }
      false
    end

    # Create the import subdirectory for the item.
    #
    # @param [String] dir             Subdirectory name.
    # @param [String] root            Top-level import directory.
    #
    # @return [String]                Subdirectory path.
    #
    def make_import_subdir(dir, root: option.import_root)
      dir_path = File.expand_path(dir, root)
      if Dir.exist?(dir_path)
        warning { "#{__method__}(#{dir}): clearing #{dir_path.inspect}" }
        FileUtils.rm_rf(dir_path, secure: true)
      end
      Dir.mkdir(dir_path)
      dir_path
    rescue => err
      raise "Could not create import subdir for #{dir}: #{err}"
    end

    # =========================================================================
    # :section: DSpace data
    # =========================================================================

    protected

    # Acquire current entity data from DSpace.
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    #
    def get_current_data = to_be_overridden

    # Generate `current_table` contents from `saved_table_path` contents for
    # the "--fast" option or from existing data acquired from DSpace.
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    #
    def get_current_table
      option.fast and (saved_table = get_saved_table) and return saved_table
      get_current_data.map { |_, entry|
        key = key_for(entry)
        [key, entry]
      }.to_h.tap { set_saved_table(_1) }
    end

    # The relative path to the `current_table` data storage file.
    #
    # @return [String]
    #
    def saved_table_path = to_be_overridden

    # Get the value of `current_table` from the previous run.
    #
    # @param [String] table_file
    #
    # @return [Hash{String=>Dspace::Entity::Entry}]
    # @return [nil] If the saved_table_path file is not found or empty.
    #
    def get_saved_table(table_file: saved_table_path)
      debug { "#{__method__} #{table_file}" }
      JSON.load_file(table_file).presence
    rescue Errno::ENOENT
      nil
    end

    # Store the value of `current_table` for future "--fast" runs.
    #
    # @param [Hash{String=>Dspace::Entity::Entry}] entries
    # @param [String]                              table_file
    #
    def set_saved_table(entries, table_file: saved_table_path)
      debug { "#{__method__} #{table_file}" }
      table_file = File.expand_path(table_file, PROJECT_DIRECTORY)
      unless Dir.exist?((dir = File.dirname(table_file)))
        debug { "#{__method__}: creating #{dir.inspect}" }
        Dir.mkdir(dir)
      end
      File.open(table_file, 'w') do |file|
        JSON.dump(entries, file)
      end
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" file of an entity import.
    #
    # @param [String] type            The entity type.
    # @param [String] schema
    #
    # @return [String]                XML format.
    #
    def entity_xml(type:, schema: 'dspace', **)
      Xml.new(schema: schema) { |xml|
        xml.single(type, 'entity', 'type')
      }.to_xml
    end

    # Content for the "metadata_XXX.xml" of an entity import.
    #
    # @param [Import] data
    #
    # @return [String, nil]
    #
    def schema_xml(data) = nil

    # Content for the "dublin_core.xml" file of an entity import.
    #
    # @param [Import] data
    #
    # @return [String, nil]
    #
    def metadata_xml(data) = nil

    # Content for the "collections" file of an entity import.
    #
    # @param [Import] data
    #
    # @return [String, nil]
    #
    def collections(data) = nil

    # Content for the "relationships" file of an entity import.
    #
    # @param [Import] data
    #
    # @return [String, nil]
    #
    def relationships(data) = nil

  end

  extend ClassMethods

  # Base class for holding the data for a single entity import.
  class Import < Hash

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

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

    # The key for this instance in ImportTable.
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

  end

  # Base class for objects which maintaining mappings to data to be used to
  # create import subdirectories for entities.
  #
  class ImportTable < Hash

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    # Generate the value entry derived from the given data.
    #
    # @param [Hash] data              Entry properties.
    #
    # @return [Import]
    #
    def value_for(data) = to_be_overridden

    # Accumulate identities and data.
    #
    # @param [Hash]        data       Entry properties.
    # @param [String, nil] key        Default: derived from `data`.
    #
    # @return [String, nil]           ID added.
    #
    def add(data, key: nil)
      tag = "#{key_label}.import_table.#{__method__}"
      # noinspection RubyMismatchedArgumentType
      if (key ||= key_for(data)).nil?
        debug { "#{tag}: no key derivable from #{data.inspect}" }
      elsif (val = value_for(data)).blank?
        debug { "#{tag}: #{key}: no data" }
      else
        self[key] = merged_value_for(key, val, tag: tag) || val
      end
      key
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    RESOLUTION = %i[preserve replace merge].freeze

    # If the entry already exists in the table, resolve differences between the
    # existing at `key` and the potentially-different information in `val`.
    #
    # @param [String] key
    # @param [Import] val
    # @param [String] tag             Leader for diagnostic output.
    #
    # @return [Import, nil]
    #
    def merged_value_for(key, val, tag:)
      return if (current = self[key]).blank?
      info { "#{tag}: #{key}: already in import_table" }
      val.each_pair do |k, v_new|
        next if (v_old = current[k]).blank? || (v_old == v_new)
        resolution = resolve_value(v_old, v_new, key: k)
        info do
          old, new = v_old.inspect, v_new.inspect
          msg =
            case resolution
              when :replace  then "#{new} replaces #{old}"
              when :preserve then "#{new} skipped to preserve #{old}"
              when :merge    then "#{new} added to #{old}"
            end
          "#{tag}: #{key}: #{k} #{msg}"
        end
        case resolution
          when :replace  then # val[k] = v_new
          when :preserve then val[k] = v_old
          when :merge    then val[k] = [*v_old, *v_new]
        end
      end
    end

    # Indicate whether the old field value should be retained.
    #
    # @param [any, nil]    v_old
    # @param [any, nil]    v_new
    # @param [Symbol, nil] key        Currently unused.
    #
    # @return [Symbol]                An element of #RESOLUTION.
    #
    #--
    # noinspection RubyUnusedLocalVariable
    #++
    def resolve_value(v_old, v_new, key: nil)
      (v_old.size >= v_new.size) ? :preserve : :replace
    end

  end

end
