# src/dspace_import_zip/metadata.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating a LibraOpen export to the DSpace "dublin_core.xml"
# for a Publication entity import.

require 'common'
require 'logging'

require_relative 'person'
require_relative 'xml'

# =============================================================================
# :section: Constants
# =============================================================================

# Indicate whether DOIs should be included as "dc.identifier.doi" in
# Publication metadata.
#
# This is the old LibraOpen DOI which will eventually be mapped to the new
# DSpace item.
#
# @type [Boolean]
#
DOI = true

# Indicate whether DOIs should appear as "dc.identifier.uri" in addition to
# "dc.identifier.doi" in Publication metadata.
#
# This will make the old LibraOpen DOI appear as a link on DSpace item show
# pages under the "URI" section.
#
# @type [Boolean]
#
DOI_URI = DOI

# =============================================================================
# :section: Classes
# =============================================================================

# Build a <dublin_core> element of metadata for a Publication.
class MetadataXml < Xml

  # @return [Hash{Symbol=>*}]
  attr_reader :work_metadata

  # Create a new MetadataXml instance.
  #
  # @param [ExportItem, Hash] item    LibraOpen work exported values.
  # @param [Hash]             opt     Passed to super.
  #
  def initialize(item, **opt, &blk)
    @work_metadata = item.is_a?(ExportItem) ? item.work_metadata : item
    super(**opt, &blk)
  end

  # Emit one <dcvalue> element for a single-value field.
  #
  # @param [Symbol]      field        Work field holding the element value.
  # @param [String]      e            Element name attribute.
  # @param [String, nil] q            Qualifier attribute.
  #
  # @return [void]
  #
  def single(field, e, q = nil, &blk)
    field = work_metadata[field]
    super
  end

  # Emit one <dcvalue> element for a single-value field.
  #
  # @param [Symbol]      field        Work field holding the element value.
  # @param [String]      e            Element name attribute
  # @param [String, nil] q            Qualifier attribute
  #
  # @return [void]
  #
  def multi(field, e, q = nil, &blk)
    field = work_metadata[field]
    super
  end

end

# =============================================================================
# :section: Methods
# =============================================================================

# Content for the "dublin_core.xml" of a Publication entity import.
#
# As a side effect, `item.person` will be filled with the UUIDs of authors
# associated with this item (but not contributors).
#
# @param [ExportItem] item
#
# @return [String]
#
def publication_metadata(item)
  aut = map_persons(item, :author)
  con = map_persons(item, :contributor)
  MetadataXml.new(item) { |xml|
    #          LibraOpen field     DSpace element  DSpace qualifier  Value translation
    #          ------------------- --------------  ----------------  -------------------
    xml.multi( :title,             'title')
    xml.multi( :author_ids,        'contributor',  'author')         { aut[_1] }
    xml.multi( :contributor_ids,   'contributor')                    { con[_1] }
    xml.multi( :language,          'language')
    xml.multi( :language,          'language',     'iso')            { lang_iso(_1) }
    xml.multi( :rights,            'rights')                         { rights(_1) }
    xml.multi( :rights,            'rights',       'uri')            { rights_uri(_1) }
    xml.multi( :keyword,           'subject')
    xml.multi( :related_url,       'relation')
    xml.multi( :sponsoring_agency, 'description',  'sponsorship')
    xml.single(:resource_type,     'type')                           { resource(_1) }
    xml.single(:publisher,         'publisher')
    xml.single(:published_date,    'date',         'issued')         { issue_date(_1) }
    xml.single(:id,                'identifier')
    xml.single(:doi,               'identifier',   'doi')            { doi(_1) }         if DOI
    xml.single(:doi,               'identifier',   'uri')            { doi_uri(_1) }     if DOI_URI
    xml.single(:source_citation,   'identifier',   'citation')
    xml.single(:notes,             'description')
    xml.single(:date_modified,     'description')                    { submit_date(_1) }
    xml.single(:abstract,          'description',  'abstract')
  }.to_xml
end

# Create a map of UUID to "last_name, first_name".
#
# As a side effect, `export.person` will be filled with the UUIDs of authors
# associated with this item (but not contributors).  For authors, this method
# always returns an empty object so that "dc.contributor.author" is not created
# to avoid duplication with "relation.isAuthorOfPublication".
#
# @param [ExportItem] item
# @param [Symbol]     kind
#
# @return [Hash{String=>String}]
#
def map_persons(item, kind)
  info { "#{__method__}(#{kind})" }
  res = {}
  set = (kind == :author) ? item.author_metadata : item.contributor_metadata
  set.each_pair do |file, data|
    if (key = Person.key_for(data)).nil?
      error { "#{file}: no computing_id or last_name" }
    elsif kind != :author
      debug { (val = res[key]) and "#{file}[#{key}]: override #{val.inspect}" }
      res[key] = Person.title_name(data)
    elsif item.person.include?(key)
      debug { "#{file}[#{key}]: duplicate" }
    else
      item.person << key
    end
  end
  res
end

# =============================================================================
# :section: Methods - language
# =============================================================================

# Translation of LibraOpen "language" field value to a "dc.language.iso" value.
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
  'Russian'    => 'ru', # not configured in DSpace currently
  'Spanish'    => 'es',
  'Turkish'    => 'tr', # not present in LibraOpen
}.freeze

# Produce a "dc.language.iso" value from a LibraOpen "language" field value.
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

# Get a DSpace "dc.rights" value from a LibraOpen "rights" field value.
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

# Get a DSpace "dc.rights.uri" value from a LibraOpen "rights" field value.
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

# Translation of LibraOpen "resource_type" to DSpace "dc.type" value.
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

# Get a DSpace "dc.type" value from a LibraOpen "resource_type" field value.
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

# Produce a "dc.identifier.doi" value from a LibraOpen "doi" field value.
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
  value.delete_prefix('/').presence
end

# Produce a "dc.identifier.uri" value from a LibraOpen "doi" field value.
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
# :section: Methods - date
# =============================================================================

# Produce a "dc.date.issued" from a LibraOpen "published_date" field value.
#
# @param [String, Hash] value
# @param [Symbol]       field
#
# @return [String]                    "YYYY-MM-DD" or the original value.
# @return [nil]                       If `value` was nil or blank.
#
def issue_date(value, field: :published_date)
  value = value[field] if value.is_a?(Hash)
  value = value.to_s.squish.sub(/^(forthcoming|in.progress)\D*/i, '').presence
  yymmdd =
    case value
      when /^(\d{4})$/                             then [$1,  1,  1]
      when /^spring (\d{4})$/                      then [$1,  3,  1]
      when /^summer (\d{4})$/                      then [$1,  6,  1]
      when /^fall (\d{4})$/                        then [$1,  9,  1]
      when /^winter (\d{4})$/                      then [$1, 12,  1]
      when /^(\d{4})-(\d{1,2})$/                   then [$1, $2,  1]
      when /^(\d{4})-(\d{1,2})-(\d{1,2})( *T.*)?$/ then [$1, $2, $3]
      when /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/       then [$3, $1, $2]
      when /^(\d{1,2})\/(\d{1,2})\/(\d{2})$/       then ["20#{$3}", $1, $2]
    end
  if yymmdd
    '%04d-%02d-%02d' % yymmdd.map(&:to_i)
  elsif value
    # noinspection RubyMismatchedArgumentType
    Date.parse(value).to_s rescue value
  end
end

# Produce a "dc.description" from a LibraOpen "date_modified" field value.
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
