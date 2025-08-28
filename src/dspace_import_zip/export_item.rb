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

  # Exported item metadata.
  # @return [String]
  def work = self[:work]

  # Exported item rights.
  # @return [String]
  def rights = self[:rights]

  # Exported item embargo status.
  # @return [String, nil]
  def embargo = self[:embargo]

  # Exported item visibility.
  # @return [String]
  def visibility = self[:visibility]

  # Exported item author(s).
  # @return [Array<String>]
  def author = self[:author]

  # Exported item non-author contributor(s).
  # @return [Array<String>]
  def contributor = self[:contributor]

  # Exported item content file description(s).
  # @return [Array<String>]
  def fileset = self[:fileset]

  # Exported item content file(s).
  # @return [Array<String>]
  def content = self[:content]

  # Keys for `Person.import_table` of authors associated with this import.
  # @return [Array<String>]
  def person = self[:person]

  # Create a new ExportItem instance.
  #
  # @param [Hash] hash                Initial values.
  #
  def initialize(**hash)
    update(hash)
    %i[work rights embargo visibility].each do |single_field|
      next if (v = self[single_field]).nil? || v.is_a?(String)
      raise "#{single_field}: #{v.class} instead of String"
    end
    %i[author contributor fileset content person].each do |multi_field|
      self[multi_field] = Array.wrap(self[multi_field])
    end
    yield self if block_given?
  end

end
