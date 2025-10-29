# src/dspace_import_zip/collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get configured or existing collections from the DSpace instance.

require 'common'
require 'dspace'

# =============================================================================
# :section: Classes
# =============================================================================

# An association of a DSpace collection with one or more normalized department
# names.
#
class Collection < Hash

  # The name of the DSpace collection.
  # @return [String]
  def name = self[__method__]

  # The DSpace handle associated with the collection.
  # @return [String]
  def handle = self[__method__]

  # Departments associated with the collection.
  # @return [Array<Dept>]
  def depts = self[__method__]

  # Create a new instance
  #
  # @param [String]                     name
  # @param [String, nil]                handle
  # @param [Array<String, Array, Hash>] depts
  #
  def initialize(name, handle = nil, *depts)
    self[:name]   = name
    self[:handle] = handle
    self[:depts]  = depts.map { Dept.wrap(_1).presence }.compact.uniq
  end

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # An object which holds a department name which may match one listed in
  # "data/collection_*.txt".
  #
  class Dept < Hash

    # Create a new instance.
    #
    # @param [String, Array, Hash, nil] arg
    #
    def initialize(arg)
      dept =
        case arg
          when Dspace::OrgUnit::Entry then arg.department || arg.name
          when Hash                   then arg[:department]
          when Array                  then arg.first
          when String                 then arg
          else debug { "Dept: unexpected #{arg.inspect}" if arg }
        end
      data = OrgUnit::Import.new({ department: dept })
      self[:department] = data[:department]
    end

    # Create a new instance if necessary.
    #
    # @param [Dept, Hash, Array, String, nil] data
    #
    # @return [Dept]
    #
    def self.wrap(data)
      # noinspection RubyMismatchedReturnType
      data.is_a?(self) ? data : new(data)
    end

  end

  # ===========================================================================
  # :section: Modules
  # ===========================================================================

  # Methods associated with the Collection class.
  #
  module ClassMethods

    include Dspace::Api

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # Existing Collections acquired from DSpace.
    #
    # @param [Hash] opt               To Dspace#collections on first run.
    #
    # @return [Hash{String=>Dspace::Collection::Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= Dspace.collections(**opt)
    end

    # The handle of the existing DSpace collection identified by the value of
    # `ENV[var]`.
    #
    # @param [String] var
    #
    # @return [String, nil]
    #
    def handle(var)
      var = var.to_s.upcase
      val = ENV[var].presence or raise("Missing ENV[#{var}]")
      return val if handle?(val)
      if uuid?(val)
        collection = current_table[val]
      else
        _, collection = current_table.find { |_, c| c.match?(val) }
      end
      raise "Missing collection #{val.inspect}" if collection.blank?
      collection.handle.presence
    end

    # =========================================================================
    # :section:
    # =========================================================================

    public

    # The handle of the collection that should be the destination for
    # publications by authors/contributors associated with *org*.
    #
    # @param [Dspace::OrgUnit::Entry, OrgUnit::Import] org
    #
    # @return [String, nil]
    #
    def for(org)
      dept = Dept.wrap(org)
      dept_collection[dept]&.first
    end

    # Mapping of department to one or more collection handles.
    #
    # @return [Hash{Dept=>Array<String>}]
    #
    def dept_collection
      @dept_collection ||=
        {}.tap { |result|
          collection_dept.each_pair do |handle, entry|
            entry.depts.each do |dept|
              result[dept] ||= []
              result[dept] << handle
            end
          end
        }.transform_values(&:uniq).freeze
    end

    # Mapping of collection handle to associated departments.
    #
    # @return [Hash{String=>Collection]
    #
    def collection_dept
      @collection_dept ||= get_data_table.freeze
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # Read the data file which associates collections with normalized
    # department names.
    #
    # @param [String] file            Project-relative path to the data file.
    #
    # @return [Hash{String=>Collection]
    #
    def get_data_table(file: "data/collection_#{DEPLOYMENT}.txt")
      read_data(file) do |result, (handle, name, depts, *)|
        depts = depts.split(';').map(&:strip).compact_blank
        result[handle] = new(name, handle, *depts)
      end
    end

  end

  extend ClassMethods

end
