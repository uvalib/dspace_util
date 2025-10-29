# src/dspace_import_zip/embargo.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating LibraOpen embargo to DSpace.

require 'common'
require 'logging'

require_relative 'visibility'

# =============================================================================
# :section: Classes
# =============================================================================

# Representation of a LibraOpen embargo in DSpace.
#
class Embargo < Hash

  # Visibility during embargo.
  # @return [String]
  def during = self[__method__]

  # Visibility after embargo.
  # @return [String]
  def after = self[__method__]

  # Scheduled embargo release date.
  # @return [Date, nil]
  def release = self[__method__]

  # Actual embargo release date.
  # @return [Date, nil]
  def deactivated = self[__method__]

  # Create a new Embargo instance.
  #
  # @param [ExportItem, Hash] values
  #
  def initialize(values)
    if values.is_a?(ExportItem)
      values = parse_json(values.embargo)
    elsif !values.is_a?(Hash)
      raise "unexpected #{values.class} = #{values.inspect}"
    end

    if (v = values[:during] || values[:visibility_during_embargo])
      self[:during] = get_access_group(v)
    end

    if (v = values[:after] || values[:visibility_after_embargo])
      self[:after] = get_access_group(v)
    end

    if (v = values[:release] || values[:embargo_release_date])
      self[:release] = v.to_date rescue nil
    end

    if (v = values[:deactivated])
      self[:deactivated] = v.to_date rescue nil
    elsif (history = Array.wrap(values[:embargo_history]).last)
      match = history.match(/^An active embargo was deactivated on (\S+)\./)
      date  = match && match[1].presence
      self[:deactivated] = date.to_date rescue nil if date
    end
  end

  # Indicate whether the associated item is currently under embargo.
  #
  def active?
    !deactivated && !!release && (release > Date.today)
  end

  # Value for "local.embargo.terms".
  #
  # @return [String, nil]
  #
  def terms
    active? ? during : after
  end

  # Value for "local.embargo.lift".
  #
  # @return [String, nil]
  #
  def lift
    (deactivated || release)&.to_s
  end

end
