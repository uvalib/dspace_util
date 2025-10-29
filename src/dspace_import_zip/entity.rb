# src/dspace_import_zip/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Abstract base class extensions for importing DSpace entities.

require 'entity'

require_relative 'options'
require_relative 'xml'

# =============================================================================
# :section: Classes
# =============================================================================

# Abstract base class extensions for importing DSpace entities.
#
class Entity

  # Extensions for importing DSpace entities.
  #
  module Methods

    # The name of the import subdirectory for an entity import.
    #
    # @param [Hash, String] data
    #
    # @return [String, nil]
    #
    def import_name(data) = to_be_overridden

  end

  # Extensions for importing DSpace entities.
  #
  module ClassMethods

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

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
      tag = "#{type_label}.#{__method__}"
      if (key = key_for(data)).nil?
        debug { "#{__method__}: #{tag}: no key from #{data.inspect}" }
      elsif !force && current_table.key?(key)
        info { "#{__method__}: #{tag}: #{key}: already in current_table" }
      else
        import_table.add(data, key: key)
      end
    end

    # Add import subdirectories for each entity referenced by the subclass.
    #
    # @param [Hash] opt               Passed to #mark_steps.
    #
    # @return [Integer]               Number of subdirectories created.
    #
    def make_imports(**opt)
      mark_steps(import_table, **opt) do |key, data|
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
    # :section: Internal methods
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" file of an entity import.
    #
    # @param [String] entity_type
    # @param [String] schema
    #
    # @return [String]                XML format.
    #
    def entity_xml(entity_type:, schema: 'dspace', **)
      Xml.new(schema: schema) { |xml|
        xml.single(entity_type, 'entity', 'type')
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

  # Extensions for importing DSpace entities.
  #
  class Import
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
      tag = "#{type_label}.import_table.#{__method__}"
      # noinspection RubyMismatchedArgumentType
      if (key ||= key_for(data)).nil?
        debug { "#{__method__}: #{tag}: no key from #{data.inspect}" }
      elsif (val = value_for(data)).blank?
        debug { "#{__method__}: #{tag}: #{key}: no data" }
      else
        self[key] = merged_value_for(key, val, tag: tag)
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
    # @return [Import]                Original *val* if not present in table.
    #
    def merged_value_for(key, val, tag:)
      return val if (current = self[key]).blank?
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
      if (old = v_old.try(:size)) && (new = v_new.try(:size)) && (old >= new)
        :preserve
      else
        :replace
      end
    end

  end

end
