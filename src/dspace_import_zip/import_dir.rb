# src/dspace_import_zip/import_dir.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Create the DSpace import directory from LibraOpen export directory.

require 'common'
require 'logging'

require_relative 'options'
require_relative 'export_item'
require_relative 'org_unit'
require_relative 'person'
require_relative 'publication'

# =============================================================================
# :section: Methods
# =============================================================================

# Create the DSpace import directory from LibraOpen export directory.
#
# @param [Integer, nil] phase         Execution phase.
# @param [Integer, nil] max           Maximum entries if positive.
# @param [String]  src                Source export directory.
#
# @return [Boolean]
#
def make_import_dir(phase: nil, max: nil, src: option.export_root)
  phase = option.phase       if phase.nil?
  max   = option.max_records if max.nil?
  max   = nil unless max.positive?
  info { max ? "#{__method__}(max: #{max.inspect})" : __method__ }

  # Organize LibraOpen exports, quitting early if there are none.
  exports = Dir.entries(src).map { export_item(_1, src: src) }.compact
  if exports.empty?
    show { "\nNO EXPORT ITEMS SELECTED" }
    return false
  end
  # noinspection RubyMismatchedArgumentType
  exports = exports.take(max) if max && (exports.size > max)

  # The execution phase determines preliminary actions to take or avoid.
  only_adding_org_units = (phase == ORG_UNIT_PHASE)
  only_adding_persons   = (phase == PERSON_PHASE)
  adding_publications   = (phase == PUBLICATION_PHASE) || (phase == NO_PHASE)

  # Pre-fetch needed DSpace items to ensure that command-line options affecting
  # data acquisition can be applied.  Also, since these operations may result
  # in noticeable delays when running from the command line, this clarifies how
  # the program is spending its time during the run.
  if true
    show { "\nGETTING CURRENT DSPACE COLLECTIONS" }
    t_opt = {}
    count = Collection.current_table(**t_opt).size
    show { "#{count} entries" }
  end
  if true
    show { "\nGETTING CURRENT DSPACE ORGANIZATIONS" }
    t_opt = { fast: option.fast }
    t_opt.merge!(fetch: option.fetch) if only_adding_org_units
    count = OrgUnit.current_table(**t_opt).size
    show { "#{count} entries" }
  end
  unless only_adding_org_units
    show { "\nGETTING CURRENT DSPACE PERSONS" }
    t_opt = { fast: option.fast }
    t_opt.merge!(fetch: option.fetch) if only_adding_persons
    count = Person.current_table(**t_opt).size
    show { "#{count} entries" }
  end

  # Build Person and OrgUnit import tables, pre-processing each export to
  # extract depositor-to-ORCID mappings.
  show { "\nSCANNING #{exports.size} EXPORTS FROM #{src.inspect}" }
  exports.each do |e|
    Publication.set_orcid!(e) unless only_adding_org_units
    (e.author_metadata.values + e.contributor_metadata.values).each do |data|
      OrgUnit.add_import(data)
      Person.add_import(data.merge(export: e)) unless only_adding_org_units
      if adding_publications
        key = OrgUnit.key_for(data)
        org = OrgUnit.import_table[key] || OrgUnit.current_table[key]
        # noinspection RubyMismatchedArgumentType
        e.orgs << org if org
      end
    end
    e.orgs.uniq! if adding_publications
  end

  org_count = OrgUnit.import_table.size.nonzero?
  per_count = Person.import_table.size.nonzero?
  pub_count = exports.size.nonzero?

  if phase == NO_PHASE
    # Prevent a non-phased approach if there are too many entities to import in
    # a single zip file within practical limits.
    count = [org_count, per_count, pub_count].compact.sum
    limit = option.batch_size.nonzero? || BATCH_SIZE
    exit_note =
      if count > limit
        if org_count
          'ADD "--phase 1" OPTION TO CREATE ORG UNIT ENTITIES FIRST'
        elsif per_count
          'ADD "--phase 2" OPTION TO CREATE PERSON ENTITIES FIRST'
        end
      end
    show("\nTOTAL ENTITIES TO CREATE (#{count}) IS OVER #{limit}") if exit_note
  else
    # If there are no entities to create in this phase then there is nothing
    # left to do.
    exit_note =
      case phase
        when ORG_UNIT_PHASE    then 'ORG UNIT'    unless org_count
        when PERSON_PHASE      then 'PERSON'      unless per_count
        when PUBLICATION_PHASE then 'PUBLICATION' unless pub_count
      end
    exit_note &&= "\nNO #{exit_note} ENTITIES TO CREATE"
  end

  # Quit now if there are blockers or if previous phases have not completed.
  if exit_note.present?
    show(exit_note)
    return false
  elsif org_count && (phase > ORG_UNIT_PHASE)
    error { "STILL #{org_count} ORG UNIT ENTITIES UNCREATED" }
    OrgUnit.import_table.each_pair do |k, v|
      show { "#{k.inspect} => #{v.inspect}" }
    end
    return false
  elsif per_count && (phase > PERSON_PHASE)
    error { "STILL #{per_count} PERSON ENTITIES UNCREATED" }
    Person.import_table.each_pair do |k, v|
      show { "#{k.inspect} => #{v.inspect}" }
    end
    return false
  end

  # Ensure that the proper sections below are skipped depending on the phase.
  case phase
    when ORG_UNIT_PHASE    then per_count = pub_count = nil
    when PERSON_PHASE      then org_count = pub_count = nil
    when PUBLICATION_PHASE then org_count = per_count = nil
  end

  # Prepare the import directory and generate imports.
  make_import_root or return false
  imported = 0
  if org_count
    show { "\nCREATING #{org_count} ORG UNIT IMPORT ITEMS" }
    imported += OrgUnit.make_imports
  end
  if per_count
    show { "\nCREATING #{per_count} PERSON IMPORT ITEMS" }
    imported += Person.make_imports
  end
  if pub_count
    show { "\nCREATING #{pub_count} PUBLICATION IMPORT ITEMS" }
    imported += Publication.make_imports(exports)
  end
  imported > 0
end

# Identify export subdirectory file components.
#
# The item will be rejected if `option.select` is present and this item is
# not included.
#
# The item will be rejected if `option.reject` is present and this item
# *is* included.
#
# @param [String] export_subdir
# @param [String] src                 Source export directory.
#
# @return [ExportItem, nil]
#
def export_item(export_subdir, src: option.export_root)
  return if export_subdir.blank? || export_subdir.start_with?('.')
  return if (number = get_export_number(export_subdir, src: src)).nil?
  return if option.select.present? && !option.select.include?(number)
  return if option.reject.present? && option.reject.include?(number)
  ExportItem.new(import_name: number) do |export|
    export_dir = "#{src}/#{export_subdir}"
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
# (This LibraOpen number isn't used by DSpace; it's just used to visually
# associate export subdirectories with import subdirectories.)
#
# @param [String] export_subdir
# @param [String] src                 Source export directory.
#
# @return [String, nil]
#
def get_export_number(export_subdir, src: option.export_root)
  export_subdir.to_s.downcase.delete_prefix!(EXPORT_PREFIX) or
    error { "#{src}: ignored file: #{export_subdir}" }
end

# Create the empty import directory.
#
# @param [String] root                Top-level import directory.
#
# @return [String, nil]
#
def make_import_root(root: option.import_root)
  if Dir.exist?(root)
    warning { "#{__method__}: clearing existing #{root.inspect}" }
    FileUtils.rm_rf(root, secure: true)
  else
    info { "#{__method__}: creating #{root.inspect}" }
  end
  Dir.mkdir(root)
  root
rescue => err
  error { "Could not create import directory #{root.inspect}: #{err}" }
end
