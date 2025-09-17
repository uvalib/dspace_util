# src/dspace_import_zip/org_unit.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Accumulate department identities.

require 'common'
require 'logging'
require 'dspace'

require_relative 'collection'
require_relative 'entity'
require_relative 'xml'

# =============================================================================
# :section: Constants
# =============================================================================

UVA_ORG_NAME = 'University of Virginia'

# =============================================================================
# :section: Classes
# =============================================================================

# An object which maintains data for OrgUnit entities to be created.
class OrgUnit < Entity

  # Methods which derive OrgUnit information from provided data.
  module Methods

    include Entity::Methods

    # =========================================================================
    # :section: Entity::Methods overrides
    # =========================================================================

    # Prefix for describing a key in diagnostic output.
    #
    # @return [String]
    #
    def key_label = 'Org'

    # Fields to use from LibraOpen export data.
    #
    # @return [Array<Symbol>]
    #
    def export_fields
      %i[department institution]
    end

    # Generate an ImportTable key derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data     Department properties.
    #
    # @return [String, nil]             Hash key.
    #
    def key_for(data)
      return data[:table_key] if data[:table_key]
      key_from(*Import.wrap(data).values_at(:institution, :department))
    end

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

  end

  module ClassMethods

    include Entity::ClassMethods
    include Methods

    # =========================================================================
    # :section: Entity::ClassMethods overrides
    # =========================================================================

    # Existing OrgUnits acquired from DSpace.
    #
    # @return [Hash{String=>Dspace::OrgUnit::Entry}]
    #
    def current_table
      @current_table ||=
        Dspace.orgs.map { |_, entry|
          key = key_for(entry)
          [key, entry]
        }.to_h
    end

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
    # :section: Import files - Entity::ClassMethods overrides
    # =========================================================================

    protected

    # Content for the "metadata_dspace.xml" of an OrgUnit entity import.
    #
    # @param [Import] data
    #
    # @return [String]
    #
    def entity_xml(data)
      super(**data, type: 'OrgUnit')
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

  # Data for a single OrgUnit entity import.
  class Import < Entity::Import

    include Methods

    def key_for     (data = nil) = super(data || self)
    def import_name (data = nil) = super(data || self)
    def title_name  (data = nil) = super(data || self)
    def description (data = nil) = super(data || self)

    # The top-level organization prefix for a UVA department name.
    #
    # @type [Hash{String=>String}]
    #
    SCHOOL = {
      'AR'  => 'Architecture',
      'AS'  => 'Arts & Sciences',
      'BA'  => 'School of Business Administration',
      #'CU' => '???',
      #'DA' => '???',
      #'DS' => '???',
      'ED'  => 'School of Education',
      'EN'  => 'School of Engineering',
      'FM'  => 'Facilities Management',
      'HS'  => 'Health Sciences',
      'IT'  => 'Information Technology',
      'LB'  => 'University Library',
      'LW'  => 'School of Law',
      'MC'  => 'Medical Center',
      'MD'  => 'School of Medicine',
      'NR'  => 'School of Nursing',
      #'PV' => '???',
      #'RS' => 'Research', # ?
      #'SA' => 'Student Affairs', # ?
    }

    # Normalizations for abbreviated UVA department names.
    #
    # @type [Hash{String=>String}]
    #
    #--
    # noinspection SpellCheckingInspection
    #++
    DEPARTMENT = {
      'APMA'                            => 'Applied Mathematics',
      'Arch Dept'                       => 'Architecture',
      'Arch History Dept'               => 'Architectural History',
      'Biomed Engr Dept'                => 'Biomedical Engineering',
      'Biomedical Eng'                  => 'Biomedical Engineering',
      'Chem Engr Dept'                  => 'Chemical Engineering',
      'Comp Science Dept'               => 'Computer Science',
      'Elec & Comp Engr Dept'           => 'Electrical and Computer Engineering',
      'Elec/Computer Engr Dept'         => 'Electrical and Computer Engineering',
      'Landscape Dept'                  => 'Landscape Architecture',
      'Mat Sci & Engr Dept'             => 'Materials Science and Engineering',
      'Mech & Aero Engr Dept'           => 'Mechanical and Aerospace Engineering',
      'Mole Phys & Biophysics'          => 'Molecular Phys and Biological Physics',
      'Planning Dept'                   => 'Urban and Environmental Planning',
      'Urban & Environmental Planning'  => 'Urban and Environmental Planning',
      'Urban/Environmental Planning'    => 'Urban and Environmental Planning',
      'Spanish Italian Portuguese'      => 'Spanish, Italian, and Portuguese',
      'Spanish, Italian & Portuguese'   => 'Spanish, Italian, and Portuguese',
    }

    # Create a new OrgUnit::Import instance with department and institution
    # normalized to account for observed variations in the source data.
    #
    # @param [Hash] data
    #
    def initialize(data)
      super

      orig = dept = self[:department]
      inst = self[:institution].presence
      inst = self[:institution] = UVA_ORG_NAME if inst.nil? || (inst == dept)

      if dept.blank?
        self[:title_name]  = inst
        self[:description] = []

      elsif inst != UVA_ORG_NAME
        self[:department]  = dept = normalize_department(dept)
        self[:title_name]  = [inst, dept].compact_blank.join(' - ')
        self[:description] = [inst, orig].compact_blank

      else
        if (sch = SCHOOL[dept])
          dept = sch.dup
          sch  = nil
        elsif dept.match(/^(UPG-)?(MD)-[A-Z]{4} *(.*)$/)
          dept = $3.dup
          sch  = SCHOOL[$2]
        elsif dept.match(/^([A-Z][A-Z])- *(.*)$/i)
          dept = $2.dup
          sch  = SCHOOL[$1] || $1
        else
          dept = dept.dup
          sch  = nil
        end
        dept.sub!(/, *UPG-MD-[A-Z]{4}$/, '') # Redundant department reference.
        dept.sub!(/ +\([A-Z]{3,4}\)$/, '')   # Redundant department code.
        dept.sub!(/-[a-z]{3,4} *$/, '')      # School class section number.
        dept.sub!(/^Masters? of */, '')
        self[:department]  = dept = normalize_department(dept)
        self[:title_name]  = dept
        self[:description] = [inst, sch, orig].compact_blank
      end
    end

    # =========================================================================
    # :section: Entity::Import overrides
    # =========================================================================

    # The key for this instance in OrgUnit::ImportTable.
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
    # :section:
    # =========================================================================

    # Transform to a standardized department name.
    #
    # @param [String, nil] name
    #
    # @return [String]                Blank if name is nil or blank.
    #
    def normalize_department(name)
      name = name&.squish&.presence or return ''
      name.sub!(/^(Department|Dept\.|Dept) (of|for) /, '')
      name.sub!(/[ .,;:]+$/, '')
      DEPARTMENT[name]&.dup || name
    end

  end

  # All OrgUnit entity imports.
  class ImportTable < Entity::ImportTable

    include Methods

    # =========================================================================
    # :section:
    # =========================================================================

    # Generate the value entry derived from the given data.
    #
    # @param [Hash{Symbol=>*}] data     Entry properties.
    #
    # @return [Import]
    #
    def value_for(data)
      data.is_a?(Import) ? data.deep_dup : Import.new(data)
    end

  end

end
