# src/dspace_import_zip/components.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Export subdirectory file components.

require 'common'

# Organizes the files found in an export subdirectory along with optional
# additional information needed to generate an import subdirectory from an
# export subdirectory.
#
class Components < Hash

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

  # Create a new instance.
  #
  # @param [Hash] hash                Initial values.
  #
  def initialize(**hash)
    update(hash)
    %i[work rights embargo visibility].each do |single_field|
      next if (v = self[single_field]).nil? || v.is_a?(String)
      raise "#{single_field}: #{v.class} instead of String"
    end
    %i[author contributor fileset content].each do |multi_field|
      self[multi_field] = Array.wrap(self[multi_field])
    end
    yield self if block_given?
  end

end
