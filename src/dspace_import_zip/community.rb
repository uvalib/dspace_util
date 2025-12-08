# src/dspace_import_zip/community.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get existing Communities from the DSpace instance.

require 'common'
require 'dspace'

# =============================================================================
# :section: Classes
# =============================================================================

# A table of DSpace Communities.
#
class Community < Hash

  # The name of the DSpace Community.
  # @return [String]
  def name = self[__method__]

  # The DSpace handle associated with the Community.
  # @return [String]
  def handle = self[__method__]

  # Create a new instance
  #
  # @param [String] name
  # @param [String] handle
  #
  def initialize(name, handle)
    self[:name]   = name
    self[:handle] = handle
  end

  # ===========================================================================
  # :section: Modules
  # ===========================================================================

  # Methods associated with the Community class.
  #
  module ClassMethods

    # =========================================================================
    # :section:
    # =========================================================================

    # Existing Communities acquired from DSpace.
    #
    # @param [Hash] opt               To DSpace#communities on first run.
    #
    # @return [Hash{String=>Dspace::Community::Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= Dspace.communities(**opt)
    end

  end

  extend ClassMethods

end
