# src/dspace_import_zip/xml.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating LibraOpen export to an import "metadata_dspace.xml".

require 'common'

require 'nokogiri'

# Build a <dublin_core> element.
#
class Xml < Nokogiri::XML::Builder

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Create a new Xml instance from occurrences of #single and/or #multi from
  # within the supplied block.
  #
  # @param [String, nil] schema       For the outer <dublin_core> element.
  # @param [Hash]        opt          Passed to super.
  #
  def initialize(schema: nil, **opt, &blk)
    element_opt = { schema: schema }.compact
    super(opt) do
      # noinspection RubyResolve
      dublin_core(element_opt, &blk)
    end
  end

  # Emit one <dcvalue> element for a single-value field.
  #
  # @param [String, nil] value        Element value.
  # @param [String]      e            Element name attribute.
  # @param [String, nil] q            Qualifier attribute.
  #
  # @return [void]
  #
  def single(value, e, q = nil, &blk)
    make_element(value, e, q, &blk)
  end

  # Emit one <dcvalue> element for a single-value field.
  #
  # @param [Array,String,nil] value   Element value.
  # @param [String]      e            Element name attribute.
  # @param [String, nil] q            Qualifier attribute.
  #
  # @return [void]
  #
  def multi(value, e, q = nil, &blk)
    Array.wrap(value).each do |v|
      make_element(v, e, q, &blk)
    end
  end

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Emit a <dcvalue> element for non-blank data.
  #
  # @param [String, nil] value        Element value.
  # @param [String]      e            Element name attribute
  # @param [String, nil] q            Qualifier attribute
  #
  # @return [Nokogiri::XML::Node, nil]
  #
  def make_element(value, e, q, &blk)
    value = value&.strip
    value = blk.call(value) if blk
    return if value.blank?
    qualifier = q ? { qualifier: q } : {}
    # noinspection RubyResolve
    dcvalue(value, element: e, **qualifier)
  end

end
