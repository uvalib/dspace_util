# src/dspace_import_zip/import_zip.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Creation of the zip output file to be copied to DSpace for import.

require 'common'
require 'logging'

require_relative 'options'

require 'zip'

# =============================================================================
# :section: Methods
# =============================================================================

# Create a new zip archive from the contents of `root`.
#
# @param [Integer, nil] parts         Break into N files (batch_count).
# @param [Integer, nil] size          Break into files of N items (batch_size).
# @param [String]       root          Top-level import directory.
#
#--
# noinspection RubyMismatchedArgumentType
#++
def make_import_zip(parts: nil, size: nil, root: option.import_root)
  parts = option.batch_count if parts.nil?
  size  = option.batch_size  if size.nil?
  parts = nil if parts && (parts <= 1)
  size  = nil if size  && (size  <= 0)
  info do
    args = { parts: parts, size: size }.compact.presence
    args &&= args.map { "#{_1}: #{_2}" }.join(', ')
    args &&= "(#{args})"
    "#{__method__}#{args}"
  end

  dirs  = Dir.glob("#{root}/*")
  count = dirs.size
  extra = nil

  # Automatically generate zip files in batches if the total number of entities
  # to create is too large.
  if count.zero?
    error { "#{__method__}: #{root} is empty" }
    return
  elsif count > (size || BATCH_SIZE)
    show { "\nPARTITIONING #{count} ENTITIES INTO MULTIPLE ZIP FILES" }
    size ||= BATCH_SIZE
  end

  if size
    batch = size
    prev  = parts
    parts = count / size
    parts += 1 if (batch * parts) < count
    warning { "#{__method__}: size #{batch} forcing #{parts} parts" } if prev
  elsif parts && (parts > 1)
    limit = (parts > count)
    parts = count if limit
    batch = count / parts
    batch += 1 if (batch * parts) < count
    extra = (batch * parts) - count
    warning { "#{__method__}: limiting to #{parts} parts" } if limit
  else
    parts = 1
    batch = count
  end

  zips = []
  if parts > 1
    show { "\nCREATING #{parts} ZIP ARCHIVES" }
    width = parts.to_s.size
    (1..parts).each do |part|
      items = batch.to_i
      if extra&.positive?
        items -= 1
        extra -= 1
      end
      files = dirs.shift(items).flat_map { Dir.glob("#{_1}/*") }
      zips << create_zip(files, root: root, part: '%0*d' % [width, part])
    end
  else
    files = dirs.flat_map { Dir.glob("#{_1}/*") }
    zips << create_zip(files, root: root)
  end

  verify_zip(zips) unless option.quiet
end

# Create a new zip archive from the contents of `root`.
#
# @param [Array<String>]        files Files to include.
# @param [String, Integer, nil] part  Modify with part number.
# @param [String, nil]          name  Overrides `#zip_name.
# @param [String]               root  Top-level import directory.
#
# @return [String]                    The name of the zip file created.
#
def create_zip(files, part: nil, name: nil, root: option.import_root)
  name ||= zip_name(part: part, root: root)
  info { "#{__method__} #{name}" }
  show { "\nCREATING #{name.inspect} (#{files.size} FILES)" }

  # noinspection RubyMismatchedArgumentType
  if File.exist?(name)
    info { "#{__method__}: replacing existing #{name.inspect}" }
    FileUtils.rm(name)
  end

  start = Time.now
  zip64 = Zip.write_zip64_support
  Zip.write_zip64_support = true
  Zip::File.open(name, create: true) do |zip|
    files.each do |src|
      dst = src.delete_prefix("#{root}/")
      # debug "#{__method__}: #{dst}"
      zip.add(dst, src)
      show_char '#'
    end
    show_char ' writing...'
  end
  Zip.write_zip64_support = zip64
  show { ' (%0.1f seconds)' % (Time.now - start) }

  # noinspection RubyMismatchedReturnType
  name
end

# Use `unzip` to validate the indicated zip file(s).
#
# @param [Array<String>, String, nil] zips
# @param [Integer, nil]               parts   If `zips` not given (batch_count)
# @param [Integer, nil]               size    If `zips` not given (batch_size)
# @param [String]                     root    Top-level import directory.
#
def verify_zip(zips = nil, parts: nil, size: nil, root: option.import_root)
  info __method__
  if zips.nil?
    parts = option.batch_count if parts.nil?
    size  = option.batch_size  if size.nil?
    batch = parts.positive? || size.positive?
    zips  = batch ? Dir.glob("#{root}-[0-9]*.zip") : zip_name(root: root)
  end
  Array.wrap(zips).each do |zip|
    show { "\nCHECKING #{zip.inspect}" }
    output_line `unzip -tq "#{zip}"`
  end
end

# File name of the output zip file.
#
# @param [String, Integer, nil] part  Modify with part number.
# @param [String]               root  Top-level import directory.
#
# @return [String]
#
def zip_name(part: nil, root: option.import_root)
  part ? "#{root}-#{part}.zip" : "#{root}.zip"
end
