# src/dspace_import_zip/export_item.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# LibraOpen export subdirectory file components.

require 'common'

# =============================================================================
# :section: Classes
# =============================================================================

# Organizes the files found in a LibraOpen export subdirectory along with added
# information needed to generate a matching DSpace import subdirectory.
#
class ExportItem < Hash

  # The LibraOpen identifier for the item.
  # @return [String]
  def import_name = self[__method__]

  # File for exported item metadata.
  # @return [String]
  def work = self[__method__]

  # File for exported item rights.
  # @return [String]
  def rights = self[__method__]

  # File for exported item embargo status.
  # @return [String, nil]
  def embargo = self[__method__]

  # File for exported item visibility.
  # @return [String]
  def visibility = self[__method__]

  # File(s) for exported item author(s).
  # @return [Array<String>]
  def author = self[__method__]

  # File(s) for exported item non-author contributor(s).
  # @return [Array<String>]
  def contributor = self[__method__]

  # File(s) for exported item content file description(s).
  # @return [Array<String>]
  def fileset = self[__method__]

  # Exported item content file(s).
  # @return [Array<String>]
  def content = self[__method__]

  # Keys for `Person.import_table` of authors associated with this import.
  # @return [Array<String>]
  def person = self[__method__]

  # Depositor ORCID association.
  # @return [Hash{String=>String}]
  def orcid = self[__method__]

  # Orgs with which the imported item should be associated.
  # @return [Array<Dspace::OrgUnit::Entry,OrgUnit::Import>]
  def orgs = self[__method__]

  # Create a new ExportItem instance.
  #
  # @param [Hash] values              Initial values.
  #
  def initialize(**values)
    update(values)
    %i[work rights embargo visibility].each do |single_field|
      next if (v = self[single_field]).nil? || v.is_a?(String)
      raise "#{single_field}: #{v.class} instead of String"
    end
    %i[author contributor fileset content person].each do |multi_field|
      self[multi_field] = Array.wrap(self[multi_field])
    end
    self[:orcid] = {}
    self[:orgs]  = []
    yield self if block_given?
    debug { "No import_name for #{self.inspect}" unless self[:import_name] }
  end

  # The values read from the `work` file.
  #
  # @return [Hash{Symbol=>*}]
  #
  def work_metadata
    @work_metadata ||= parse_json(work)
  end

  # A map of the values read from the `author` files.
  #
  # @return [Hash{String=>Hash{Symbol=>*}}]
  #
  def author_metadata
    @author_metadata ||= author.map { [_1, parse_json(_1)] }.to_h
  end

  # A map of the values read from the `contributor` files.
  #
  # @return [Hash{String=>Hash{Symbol=>*}}]
  #
  def contributor_metadata
    @contributor_metadata ||= contributor.map { [_1, parse_json(_1)] }.to_h
  end

end
