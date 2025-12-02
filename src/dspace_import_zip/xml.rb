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
  # :section: Constants
  # ===========================================================================

  # Indicate whether DSpace metadata should be provided with embedded HTML.
  #
  # If *true*, this would likely require DSpace configuration changes.
  # If *false*, HTML element tags will appear escaped like `&lt;TAG&gt;`.
  #
  # @type [Boolean]
  #
  DSPACE_HTML = false

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

  # Emit multiple <dcvalue> elements for a multi-valued field.
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

  # Emit one or more <dcvalue> elements for non-blank data.
  #
  # @param [String, nil] value        Element value.
  # @param [String]      e            Element name attribute
  # @param [String, nil] q            Qualifier attribute
  #
  # @return [void]
  #
  def make_element(value, e, q, &blk)
    value = value&.strip
    value = blk.call(value) if blk
    return if value.blank?
    qualifier = q ? { qualifier: q } : {}
    Array.wrap(value).each do |v|
      # noinspection RubyResolve
      dcvalue(v, element: e, **qualifier)
    end
  end

  # ===========================================================================
  # :section: Nokogiri::XML::Builder overrides
  # ===========================================================================

  public

  # Render the object as XML.
  #
  # @param [Array<any>] args          @see Nokogiri::XML::Node#serialize
  #
  # @return [String]
  #
  def to_xml(*args)
    restore_html(super)
  end if DSPACE_HTML

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Match a span of text which represents an encoded HTML element which may
  # contain newlines.
  #
  # This is adequate for the LibraOpen dataset but not in general because it
  # assumes that HTML elements are never nested inside HTML elements of the
  # same type.
  #
  # @type [Regexp]
  #
  HTML_PATTERN = %r{(&lt;(.*?)&gt;.*?&lt;/\2&gt;)}m

  # Restore encoded HTML.
  #
  # @param [String] text
  #
  # @return [String]
  #
  def restore_html(text)
    head, html, rest = text.partition(HTML_PATTERN)
    return head if html.blank?
    tag  = html.match(/^&lt;(.*?)&gt;/).then { $1 }
    html = html.sub(%r{\A&lt;#{tag}&gt;(.*?)&lt;/#{tag}&gt;\Z}m, '\1')
    html = restore_html(html)
    rest = restore_html(rest)
    "#{head}<#{tag}>#{html}</#{tag}>#{rest}"
  end

end
