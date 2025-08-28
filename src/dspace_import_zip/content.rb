# src/dspace_import_zip/content.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating exported LibraOpen content to a DSpace import.

require 'common'
require 'logging'

# =============================================================================
# :section: Methods
# =============================================================================

# Create the "contents" file for a Publication import and copy content files.
#
# NOTE: This method requires that the import subdirectory already exists.
#
# @param [ExportItem] item
# @param [String]     output_file     Filename of output file.
# @param [String]     root            Top-level import directory.
#
# @return [Boolean]                   Currently always true.
#
def make_publication_content(item, output_file: 'contents', root: option.import_root)
  file_map   = order_content(item.fileset, item.content).presence or return
  read_group = get_read_group(item)
  import_dir = File.expand_path(Publication.import_name(item), root)
  File.open("#{import_dir}/#{output_file}", 'w') do |contents|
    file_map.each_key do |name|
      entry = read_group ? "#{name}\tpermissions:-r '#{read_group}'" : name
      contents.puts entry
    end
  end
  file_map.each_pair do |name, path|
    FileUtils.cp(path, "#{import_dir}/#{name}")
  end
  true
end

# If there are constraints on the visibility of content for the item, this
# method returns with the DSpace group allowed to read the content.
#
# @param [ExportItem] item
#
# @return [String, nil]
#
def get_read_group(item)
  case parse_json(item.visibility)[:visibility]
    when 'authenticated' then 'Authenticated Users'
    when 'restricted'    then 'Submitter Only'
  end
end

# Ensure that `content_paths` are returned in the order defined by
# `fileset_files`.  In the returned hash, each filename is paired with the
# relative path of the actual file associated with it.
#
# @param [Array<String>] fileset_files    fileset-*.json
# @param [Array<String>] content_paths
#
# @return [Hash{String=>String}]
#
def order_content(fileset_files, content_paths)
  info { "#{__method__}(#{fileset_files}, #{content_paths})" }
  content = content_paths.map { |path|
    [decode_filename(File.basename(path)), path]
  }.to_h
  Array.wrap(fileset_files).map { |fileset|
    data  = parse_json(fileset)
    title = Array.wrap(data[:title]).compact
    label = data[:label]
    name  = title.first&.strip&.presence || label&.strip&.presence
    path  = content[name]
    [name, path] if path
  }.compact.to_h.tap { |result|
    unknown = (content.keys - result.keys).presence
    missing = (result.values - content.values).presence
    if unknown || missing
      tag = "#{__method__}: %s" % File.dirname(content_paths.first)
      error { "#{tag}: unlisted content files: #{unknown.inspect}" } if unknown
      error { "#{tag}: missing content files: #{missing.inspect}" }  if missing
    end
  }.transform_keys { safe_filename(_1) }
end

# Translate filenames with placeholder UTF-8 characters to be in the form that
# they are referenced in their related "fileset*.json" file.
#
# @param [String] file                Path to file
#
# @return [String]
#
def decode_filename(file)
  file.to_s.strip.tr('', '?:')
end

# Translate filenames with problematic characters into a form that will be
# acceptable to Zip.
#
# @param [String] file                Path to file
#
# @return [String]
#
def safe_filename(file)
  file.to_s.strip.tr('?:', '_')
end
