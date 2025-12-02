# lib/common.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Common definitions.

require 'active_support'
require 'active_support/core_ext'
require 'fileutils'
require 'json'
require 'pp'

# =============================================================================
# :section: Constants
# =============================================================================

# The absolute path of the "dspace_util" project directory.
#
# @type [String]
#
PROJECT_DIRECTORY = File.dirname(__FILE__, 2).freeze

# Target DSpace deployment (either "staging" or "production").
#
# @return [String]
#
DEPLOYMENT = ENV['DSPACE_DEPLOYMENT'].freeze

# =============================================================================
# :section: Methods
# =============================================================================

# Indicate whether the execution is target is the staging DSpace instance.
#
def staging?
  DEPLOYMENT == 'staging'
end

# Indicate whether the execution is target is the production DSpace instance.
#
def production?
  DEPLOYMENT == 'production'
end

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

# Form a table key from individual part(s).
#
# Because the key maybe used as the basis of a subdirectory name, this method
# ensures that the result does not end with '.' because that could be a
# problem for `mkdir`.
#
# @param [Array<String>] parts
# @param [String]        connector
#
# @return [String, nil]
#
def key_from(*parts, connector: '+')
  parts.compact_blank!
  parts.map! { CGI.escapeURIComponent(_1.downcase) }
  parts.join(connector).delete_suffix('.') unless parts.blank?
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
# @param [Boolean, nil] no_mark       If not *true*, mark page progress.
#
# @return [Integer]                   Number of successful iterations.
#
# @yield [key, value] Operate on the current iteration Hash pair.
# @yield [value]      Operate on the current iteration value.
#
def mark_steps(enumerable, start: Time.now, marker: '#', no_mark: nil, **)
  success = 0
  no_mark = mark_steps_disabled if no_mark.nil?
  if enumerable.respond_to?(:each_pair)
    enumerable.each_pair do |key, value|
      yield(key, value) and success += 1
      show_char marker unless no_mark
    end
  elsif enumerable.respond_to?(:each)
    enumerable.each do |value|
      yield(value) and success += 1
      show_char marker unless no_mark
    end
  else
    raise "#{enumerable.class} is not acceptable"
  end
  show { ' (%0.1f seconds)' % (Time.now - start) } unless no_mark
  success
end

# Indicate whether #mark_steps will actually show a marker for each step.
#
# @return [Boolean]
#
def mark_steps_disabled
  option.debug || option.verbose
end

# Read a data file from the "data" project subdirectory.
#
# Each line has one or more '|' separated columns.  Blank lines and comment
# lines beginning with '#' are ignored.
#
# @param [String] file                Project-relative path to the data file.
#
# @return [Hash]                      Keys and values added by caller.
#
# @yield [result, cols]               Operate on columns from each data line.
# @yieldparam [Hash]          result  Result accumulator.
# @yieldparam [Array<String>] cols    Data columns.
#
def read_data(file)
  result = {}
  file = File.expand_path(file, PROJECT_DIRECTORY)
  File.foreach(file) do |line|
    next if (line = line.squish).blank? || line.start_with?('#')
    yield result, line.split('|').map(&:strip)
  end
  result
end
