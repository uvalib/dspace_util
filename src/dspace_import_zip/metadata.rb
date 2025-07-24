# src/dspace_import_zip/metadata.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating a Libra export to a DSpace import "dublin_core.xml".

require_relative 'common'
require_relative 'logging'

require 'nokogiri'

# =============================================================================
# :section: Methods
# =============================================================================

# Create "dublin_core.xml" file.
#
# @param [Components] export
# @param [String]     output_file     Filename of output XML file.
#
def make_metadata(export, output_file: 'dublin_core.xml')
  xml_metadata = Nokogiri::XML::Builder.new { |xml|

    # noinspection RubyUnusedLocalVariable
    work        = parse_json(export.work)
    author      = map_persons(export.author)
    contributor = map_persons(export.contributor)

    # Lamba to emit a <dcvalue> element for non-blank data.
    element = ->(e, q, value, &blk) {
      value = value&.strip
      value = blk.(value) if blk
      return if value.blank?
      qualifier = q ? { qualifier: q } : {}
      # noinspection RubyResolve
      xml.dcvalue(value, element: e, **qualifier)
    }

    # Lambda to emit one element for a single-value field.
    single = ->(field, e, q = nil, &blk) {
      value = work[field]
      element.(e, q, value, &blk)
    }

    # Lambda to emit multiple elements for a multi-value field.
    multi = ->(field, e, q = nil, &blk) {
      Array.wrap(work[field]).each do |value|
        element.(e, q, value, &blk)
      end
    }

    # Emit <dublin_core> and its contents.
    # noinspection RubyResolve
    xml.dublin_core do
      #       Libra field         DSpace element  DSpace qualifier  Value translation
      #       ------------------- --------------  ----------------  -------------------
      multi.( :title,             'title')
      multi.( :author_ids,        'contributor',  'author')         { author[_1] }
      multi.( :contributor_ids,   'contributor')                    { contributor[_1] }
      multi.( :language,          'language')
      multi.( :language,          'language',     'iso')            { lang_iso(_1) }
      multi.( :rights,            'rights')                         { rights(_1) }
      multi.( :rights,            'rights',       'uri')            { rights_uri(_1) }
      multi.( :keyword,           'subject')
      multi.( :related_url,       'relation')
      multi.( :sponsoring_agency, 'description',  'sponsorship')
      single.(:resource_type,     'type')                           { resource(_1) }
      single.(:publisher,         'publisher')
      single.(:published_date,    'date',         'issued')
      single.(:id,                'identifier')
      single.(:doi,               'identifier',   'doi')            { doi(_1) }         if DOI
      single.(:doi,               'identifier',   'uri')            { doi_uri(_1) }     if DOI_URI
      single.(:source_citation,   'identifier',   'citation')
      single.(:notes,             'description')
      single.(:date_modified,     'description')                    { submit_date(_1) }
      single.(:abstract,          'description',  'abstract')
    end
  }.to_xml
  output_file = File.expand_path(output_file, export[:import_dir])
  File.write(output_file, xml_metadata)
end

# Create a map of UUID to "last_name, first_name".
#
# @param [Array<String>] person_files   author-*.json or contributor-*.json
#
# @return [Hash{String=>String}]
#
def map_persons(person_files)
  info { "#{__method__}(#{person_files})" }
  res = {}
  Array.wrap(person_files).each do |file|
    json = parse_json(file)
    if (id = json[:id]).blank?
      error { "#{file}: no id" }
      next
    end
    error { "#{file}[#{id}]: overrides #{res[id].inspect}" } if res.key?(id)
    res[id] = json.values_at(:last_name, :first_name).compact_blank.join(', ')
  end
  res
end

# =============================================================================
# :section: Methods - language
# =============================================================================

# Translation of Libra "language" field value to a "dc.language.iso" value.
#
# @type [Hash{String=>String}]
#
LANGUAGE = {
  'Chinese'    => 'zh',
  'English'    => 'en',
  'French'     => 'fr',
  'German'     => 'de', # not present in LibraOpen
  'Italian'    => 'it', # not present in LibraOpen
  'Japanese'   => 'ja', # not present in LibraOpen
  'Portuguese' => 'pt',
  'Spanish'    => 'es',
  'Turkish'    => 'tr', # not present in LibraOpen
}.freeze

# Produce a "dc.language.iso" value from a Libra "language" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String, nil]
#
def lang_iso(value, field: :language)
  value = value[field] if value.is_a?(Hash)
  value = value.to_s.strip
  # noinspection RubyMismatchedReturnType
  LANGUAGE[value] || value if value.present?
end

# =============================================================================
# :section: Methods - rights
# =============================================================================

# Translation of Libra "rights" field index value to DSpace "dc.rights" value.
#
# @type [Array<String>]
#
RIGHTS = [
  'All rights reserved (no additional license for public reuse)',             # [0]
  'CC0 1.0 Universal',                                                        # [1]
  'Attribution 2.0 Generic (CC BY)',                                          # [2]
  'Attribution 4.0 International (CC BY)',                                    # [3]
  'Attribution-NoDerivatives 4.0 International (CC BY-ND)',                   # [4]
  'Attribution-NonCommercial 4.0 International (CC BY-NC)',                   # [5]
  'Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND)',  # [6]
  'Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)',     # [7]
  'Attribution-ShareAlike 4.0 International (CC BY-SA)',                      # [8]
].freeze

# Translation of Libra "rights" field index value to a "dc.rights.uri" value.
#
# @type [Array<String,nil>]
#
RIGHTS_URI = [
  nil,                                                  # [0]
  'https://creativecommons.org/publicdomain/zero/1.0/', # [1]
  'https://creativecommons.org/licenses/by/2.0/',       # [2]
  'https://creativecommons.org/licenses/by/4.0/',       # [3]
  'https://creativecommons.org/licenses/by-nd/4.0/',    # [4]
  'https://creativecommons.org/licenses/by-nc/4.0/',    # [5]
  'https://creativecommons.org/licenses/by-nc-nd/4.0/', # [6]
  'https://creativecommons.org/licenses/by-nc-sa/4.0/', # [7]
  'https://creativecommons.org/licenses/by-sa/4.0/',    # [8]
].freeze

# Get a DSpace "dc.rights" value from a Libra "rights" field value.
#
# @param [Integer, String, Hash] value
# @param [Symbol]                field
#
# @return [String, nil]
#
def rights(value, field: :rights)
  value = value[field] if value.is_a?(Hash)
  value = value.strip  if value.is_a?(String)
  index =
    case value
      when Integer then value
      when String  then value.to_i if value.tr('0-9', '').blank?
    end
  RIGHTS[index] || value&.to_s if index
end

# Get a DSpace "dc.rights.uri" value from a Libra "rights" field value.
#
# @param [Integer, String, Hash] value
# @param [Symbol]                field
#
# @return [String, nil]
#
def rights_uri(value, field: :rights)
  value = value[field] if value.is_a?(Hash)
  value = value.strip  if value.is_a?(String)
  index =
    case value
      when Integer then value
      when String  then value.to_i if value.tr('0-9', '').blank?
    end
  RIGHTS_URI[index] if index
end

# =============================================================================
# :section: Methods - type
# =============================================================================

# Translation of Libra "resource_type" to DSpace "dc.type" value.
#
# Any values which are not included here are either the same in both cases or
# they should be transmitted as-is (based on the assumption that DSpace will
# not reject unexpected values).
#
# @type [Hash{String=>String}]
#
RESOURCE_TYPE = {
  'Part of Book'                  => 'Book chapter',
  'Educational Resource'          => 'Learning Object',
  'Map or Cartographic Material'  => 'Map',
  'Report'                        => 'Technical Report',
}.freeze

# Get a DSpace "dc.type" value from a Libra "resource_type" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String, nil]
#
def resource(value, field: :resource_type)
  value = value[field] if value.is_a?(Hash)
  value = value.to_s.strip
  # noinspection RubyMismatchedReturnType
  RESOURCE_TYPE[value] || value if value.present?
end

# =============================================================================
# :section: Methods - DOI
# =============================================================================

# Produce a "dc.identifier.doi" value from a Libra "doi" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String, nil]
#
def doi(value, field: :doi)
  value = value[field] if value.is_a?(Hash)
  value = value.to_s.strip.presence or return
  value.sub!(/^doi:/i, '')
  value.sub!(/^https?:\/\/(\w+\.)*doi\.org/i, '')
  value.delete_prefix('/')
end

# Produce a "dc.identifier.uri" value from a Libra "doi" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String, nil]
#
def doi_uri(value, field: :doi)
  id = doi(value, field: field)
  "https://doi.org/#{id}" if id
end

# =============================================================================
# :section: Methods - original submission date
# =============================================================================

# Produce a "dc.description" value from a Libra "date_modified" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String, nil]
#
def submit_date(value, field: :date_modified)
  value = value[field] if value.is_a?(Hash)
  value = value.to_s.strip
  "Original submission date: #{value}" if value.present?
end
