# lib/org_unit.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace OrgUnit entity type.

require 'dspace'
require 'entity'

# =============================================================================
# :section: Constants
# =============================================================================

# Institution names which indicate UVA as found in LibraOpen data.
#
# @type [Array<String>]
#
UVA_ORG_NAMES ||= [
  'University of Virginia',
  'Univ. of Virginia',
  'UVA',
  # Special cases
  'Academic Preservation Trust',
  'University of Virginia Library',
  'UVa School of Nursing',
].freeze

# The canonical institution name indicating UVA.
#
# @type [String]
#
UVA_ORG_NAME ||= UVA_ORG_NAMES.first

# =============================================================================
# :section: Classes
# =============================================================================

# An object which maintains data for OrgUnit entities to be created.
#
class OrgUnit < Entity

  # Methods which derive OrgUnit information from provided data.
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
    def type_label = 'Org'

    # Fields to use from LibraOpen export data.
    #
    # @return [Array<Symbol>]
    #
    def export_fields
      %i[department institution]
    end

    # Generate a table key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data   Department properties.
    #
    # @return [String, nil]           Hash key.
    #
    def key_for(data)
      return data[:table_key] if data[:table_key]
      data   = Import.wrap(data)
      part   = data.values_at(:institution, :department).compact_blank.presence
      part ||= data[:title_name]
      key_from(*part)
    end

    # Name of the department for a UVA department; otherwise, the institution
    # and department, or nil.
    #
    # @param [Hash] data
    #
    # @return [String, nil]
    #
    def title_name(data)
      Import.wrap(data)[:title_name]
    end

    # Description line(s).
    #
    # @param [Hash] data
    #
    # @return [Array<String>]
    #
    def description(data)
      Import.wrap(data)[:description]
    end

    # =========================================================================
    # :section: Entity::Methods overrides
    # =========================================================================

    public

    # Indicate whether arg matches a name indicating UVA.
    #
    # @param [String, nil] arg
    #
    def uva_org_name?(arg)
      arg.present? && UVA_ORG_NAMES.any? { _1.casecmp?(arg) }
    end

  end

  # Methods associated with the OrgUnit class.
  #
  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    public

    # Existing OrgUnits acquired from DSpace.
    #
    # @param [Hash] opt               To Dspace#orgs on first run.
    #
    # @return [Hash{String=>Dspace::OrgUnit::Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= Dspace.orgs(**opt)
    end

  end

  extend ClassMethods

  # Data for a single OrgUnit entity import.
  #
  class Import < Entity::Import

    include Methods

    def key_for     (data = nil) = super(data || self)
    def title_name  (data = nil) = super(data || self)
    def description (data = nil) = super(data || self)

    # Create a new OrgUnit::Import instance with department and institution
    # normalized to account for observed variations in the source data.
    #
    # @param [Hash] data
    #
    def initialize(data)
      super

      orig = dept = self[:department]
      inst = self[:institution]
      inst = nil if inst == dept
      inst = self[:institution] = normalize_institution(inst)

      if dept.blank?
        self[:title_name]  = inst || UVA_ORG_NAME
        self[:description] = []

      elsif inst.present?
        self[:department]  = dept = normalize_department(dept, translate: false)
        self[:title_name]  = [inst, dept].compact_blank.join(' - ')
        self[:description] = [inst, orig].compact_blank

      else
        if (school = normalize_school(dept, return_name: false))
          dept   = school
          school = nil
        elsif dept.match(/^(MD)-DMED *(.*)$/i)
          school = normalize_school($1)
          dept   = "Medical #{$2}"
        elsif dept.match(/^(UPG-)?(MD)-[A-Z]{4} *(.*)$/)
          school = normalize_school($2)
          dept   = $3
        elsif dept.match(/^([A-Z][A-Z])- *Dean'?s Office/i)
          school = normalize_school($1)
          dept   = "Dean's Office, #{school}"
        elsif dept.match(/^([A-Z][A-Z])- *(.*)$/i)
          school = normalize_school($1)
          dept   = $2
        end
        dept = dept.dup
        dept.sub!(/^Masters? of */, '')       # Redundant degree term.
        dept.sub!(/, *UPG-MD-[A-Z]{4}$/, '')  # Redundant department reference.
        dept.sub!(/ +\([A-Z]{3,4}\)$/, '')    # Redundant department code.
        dept.sub!(/-[a-z]{3,4} *$/, '')       # School class section number.
        self[:department]  = dept = normalize_department(dept)
        self[:title_name]  = dept
        self[:description] = [UVA_ORG_NAME, school, orig].compact_blank
      end
    end

    # =========================================================================
    # :section: Entity::Import overrides
    # =========================================================================

    public

    # The key for this instance in a table of OrgUnit entities.
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

    # =========================================================================
    # :section: Internal methods - institution
    # =========================================================================

    protected

    # Transform to a standardized institution name.
    #
    # @param [String, nil] name
    # @param [Boolean]     translate  If *false*, just clean the name.
    #
    # @return [String]
    # @return [nil]                   If name is blank or indicates UVA.
    #
    def normalize_institution(name, translate: true)
      name = name&.squish
      return if name.blank? || uva_org_name?(name)
      translate && self.class.institution_translation[name]&.dup || name
    end

    # Mapping of normalized institution name to a translated name.
    #
    # @return [Hash{String=>String]
    #
    def self.institution_translation
      @institution_translation ||= self.get_institution_translation.freeze
    end

    # Mapping of normalized institution name to a translated name.
    #
    # @param [String] file            Project-relative path to the data file.
    #
    # @return [Hash{String=>String]
    #
    def self.get_institution_translation(file: 'data/institution.txt')
      read_data(file) do |result, (original, replacement, *)|
        result[original] = replacement
      end
    end

    # =========================================================================
    # :section: Internal methods - school
    # =========================================================================

    protected

    # Transform a code to a school or division name.
    #
    # @param [String, nil] name
    # @param [Boolean]     return_name  If *false*, return nil if not found.
    #
    # @return [String]
    # @return [nil]                     If name is not a school code.
    #
    def normalize_school(name, return_name: true)
      name   = name&.squish&.upcase&.presence or return
      school = self.class.school_translation[name]&.dup
      return_name ? (school || name) : school
    end

    # Mapping of code to a school or division name.
    #
    # @return [Hash{String=>String]
    #
    def self.school_translation
      @school_translation ||= self.get_school_translation.freeze
    end

    # Mapping of code to a school or division name.
    #
    # @param [String] file            Project-relative path to the data file.
    #
    # @return [Hash{String=>String]
    #
    def self.get_school_translation(file: 'data/school.txt')
      read_data(file) do |result, (code, name, *)|
        result[code] = name
      end
    end

    # =========================================================================
    # :section: Internal methods - department
    # =========================================================================

    protected

    # Transform to a standardized department name.
    #
    # @param [String, nil] name
    # @param [Boolean]     translate  If *false*, just clean the name.
    #
    # @return [String]                Blank if name is nil or empty.
    #
    #--
    # noinspection SpellCheckingInspection
    #++
    def normalize_department(name, translate: true)
      name = name&.squish&.presence or return ''
      name.sub!(/[ .,;:]+$/, '')
      name.sub!(/^(Department|Dept\.|Dept|School|College) (of|for) /i, '')
      name.sub!(/ (under)?grad(uate)?$/i, '')
      name.sub!(/ Dept$/i, '')
      translate && self.class.department_translation[name]&.dup || name
    end

    # Mapping of normalized department name to a translated name.
    #
    # @return [Hash{String=>String]
    #
    def self.department_translation
      @department_translation ||= self.get_department_translation.freeze
    end

    # Mapping of normalized department name to a translated name.
    #
    # @param [String] file            Project-relative path to the data file.
    #
    # @return [Hash{String=>String]
    #
    def self.get_department_translation(file: 'data/department.txt')
      read_data(file) do |result, (original, replacement, *)|
        result[original] = replacement
      end
    end

  end

end
