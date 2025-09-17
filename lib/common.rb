# lib/common.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Common definitions for dspace_import_zip.

require 'active_support'
require 'active_support/core_ext'
require 'fileutils'
require 'json'

# =============================================================================
# :section: Constants
# =============================================================================

# Maximum number of items to create at once.
#
# @type [Integer]
#
BATCH_SIZE = 1000

# The value of `option.phase` when only creating OrgUnit entities.
#
# @type [Integer]
#
NO_PHASE = 0

# The value of `option.phase` when only creating OrgUnit entities.
#
# @type [Integer]
#
ORG_UNIT_PHASE = 1

# The value of `option.phase` when only creating Person entities.
#
# @type [Integer]
#
PERSON_PHASE = ORG_UNIT_PHASE.next

# The value of `option.phase` when only creating Person entities.
#
# @type [Integer]
#
PUBLICATION_PHASE = PERSON_PHASE.next

# Name prefix for LibraOpen export subdirectories under `export_root`.
#
# @type [String]
#
EXPORT_PREFIX = 'export-'

# Name prefix for Publication import subdirectories under `import_root`.
#
# @type [String]
#
IMPORT_PREFIX = 'import-'

# Name prefix for Person import subdirectories under `import_root`.
#
# @type [String]
#
PERSON_PREFIX = 'person-'

# Name prefix for OrgUnit import subdirectories under `import_root`.
#
# @type [String]
#
ORG_PREFIX = 'org-'

# =============================================================================
# :section: Methods
# =============================================================================

# Create a hash from a JSON file.
#
# @param [String, nil] file           Path to file.
#
# @return [Hash{Symbol=>*}]
#
def parse_json(file)
  return {} if (file = file&.strip).blank?
  # noinspection RubyMismatchedArgumentType
  JSON.load_file(file, symbolize_names: true)
end

# Used within a base class function definition to indicate that it must be
# defined by the subclass.
#
def to_be_overridden
  raise "#{caller[0]} TO BE OVERRIDDEN BY THE SUBCLASS"
end

# Iterate over the data, displaying a marker on $stdout for each iteration.
#
# A marker is not shown for "--debug" or "--verbose" because it is assumed that
# each step will produce its own output line.
#
# @param [Enumerable]   enumerable
# @param [Time]         start
# @param [String]       marker        Marks completion of an iteration.
# @param [Boolean, nil] no_show       If false then show page progress.
#
# @return [Integer]               Number of successful iterations.
#
# @yield [key, value]             Operate on the current iteration Hash pair.
# @yield [value]                  Operate on the current iteration value.
#
def show_steps(enumerable, start: Time.now, marker: '#', no_show: nil, **)
  success = 0
  no_show = show_steps_off if no_show.nil?
  if enumerable.respond_to?(:each_pair)
    enumerable.each_pair do |key, value|
      yield(key, value) and success += 1
      show_char marker unless no_show
    end
  elsif enumerable.respond_to?(:each)
    enumerable.each do |value|
      yield(value) and success += 1
      show_char marker unless no_show
    end
  else
    raise "#{enumerable.class} is not acceptable"
  end
  show { ' (%0.1f seconds)' % (Time.now - start) } unless no_show
  success
end

# Indicate whether #show_steps will actually show a marker for each step.
#
# @return [Boolean]
#
def show_steps_off
  option.debug || option.verbose
end
