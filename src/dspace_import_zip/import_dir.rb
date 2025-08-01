# src/dspace_import_zip/import_dir.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Create the DSpace import directory from Libra export directory.

require_relative 'common'
require_relative 'logging'
require_relative 'options'
require_relative 'components'
require_relative 'content'
require_relative 'metadata'
require_relative 'entity'

# =============================================================================
# :section: Methods
# =============================================================================

# Create the DSpace import directory from Libra export directory.
#
# @param [Integer]       max          Maximum entries if positive.
# @param [Array<String>] numbers      Limit to these record numbers.
# @param [String]        src          Source export directory.
#
def make_import_dir(max: max_records, numbers: records, src: export_root)
  max = nil unless max.positive?
  info { max ? "#{__method__}(max: #{max.inspect})" : __method__ }
  make_import_root
  start   = Time.now
  subdirs = Dir.entries(src)
  count   = numbers.presence&.size || (subdirs.size - 2)
  show { "PROCESSING #{count} EXPORT ITEMS FROM #{src.inspect}" }
  subdirs.each do |dir|
    next unless (export = export_components(dir, numbers: numbers, src: src))
    make_metadata(export)
    make_content(export)
    make_entity(export)
    show_char '#' unless verbose
    break if max && (max -= 1).zero?
  end
  show { ' (%0.1f seconds)' % (Time.now - start) }
end

# Identify export subdirectory file components.
#
# @param [String]        export_subdir
# @param [Array<String>] numbers      Limit to these record numbers.
# @param [String]        src          Source export directory.
#
# @return [Components, nil]
#
def export_components(export_subdir, numbers: records, src: export_root)
  return if export_subdir.blank? || export_subdir.start_with?('.')
  number = get_export_number(export_subdir) or return
  return if numbers.present? && !numbers.include?(number)
  import_dir = make_item_import_dir(number) or return
  export_dir = "#{src}/#{export_subdir}"

  Components.new(import_dir: import_dir) do |export|
    Dir.entries(export_dir).each do |export_file|
      next if export_file.blank? || export_file.start_with?('.')
      file_path = "#{export_dir}/#{export_file}"
      case export_file
        when 'work.json'       then export[:work]         = file_path
        when 'rights.json'     then export[:rights]       = file_path
        when 'embargo.json'    then export[:embargo]      = file_path
        when 'visibility.json' then export[:visibility]   = file_path
        when /^author-/        then export[:author]      << file_path
        when /^contributor-/   then export[:contributor] << file_path
        when /^fileset-/       then export[:fileset]     << file_path
        else                        export[:content]     << file_path
      end
    end
  end
end

# Extract the export item number from the subdirectory name.
#
# (This Libra number isn't used by DSpace; it's just used to visually associate
# export subdirectories with import subdirectories.)
#
# @param [String] export_subdir
#
# @return [String, nil]
#
def get_export_number(export_subdir)
  export_subdir.to_s.downcase.delete_prefix!(EXPORT_PREFIX) or
    error { "#{export_root}: ignored file: #{export_subdir}" }
end

# Create the import subdirectory for the item and return its path.
#
# @param [String] item_number
# @param [String] root
#
# @return [String, nil]
#
def make_item_import_dir(item_number, root: import_root)
  info { "#{__method__}(#{item_number})" }
  raise 'missing item_number' if item_number.blank?
  import_dir = "#{root}/#{IMPORT_PREFIX}#{item_number}"
  if Dir.exist?(import_dir)
    info { "#{__method__}(#{item_number}): removing #{import_dir.inspect}" }
    FileUtils.rm_rf(import_dir, secure: true)
  elsif !Dir.exist?(root)
    make_import_root(root: root) or return
  end
  Dir.mkdir(import_dir)
  import_dir
rescue => err
  error { "Could not create import subdir for item #{item_number}: #{err}" }
end

# Create the empty import directory.
#
# @param [String] root
#
# @return [String, nil]
#
def make_import_root(root: import_root)
  exists = Dir.exist?(root)
  info { "#{__method__}: #{exists ? 'clearing' : 'creating'} #{root.inspect}" }
  FileUtils.rm_rf(root, secure: true) if exists
  Dir.mkdir(root)
  root
rescue => err
  error { "Could not create import directory #{root.inspect}: #{err}" }
end
