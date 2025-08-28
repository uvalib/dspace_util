# src/dspace_import_zip/entity.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating a Libra export to an import "metadata_dspace.xml".

require 'common'
require 'logging'

require 'nokogiri'

# =============================================================================
# :section: Methods
# =============================================================================

# Create the "metadata_dspace.xml" file.
#
# @param [Components] export
# @param [String]     output_file     Filename of output XML file.
#
def make_entity(export, output_file: 'metadata_dspace.xml')
  xml_metadata = Nokogiri::XML::Builder.new { |xml|
    # noinspection RubyResolve
    xml.dublin_core(schema: 'dspace') do
      xml.dcvalue('Publication', element: 'entity', qualifier: 'type')
    end
  }.to_xml
  output_file = File.expand_path(output_file, export[:import_dir])
  File.write(output_file, xml_metadata)
end
