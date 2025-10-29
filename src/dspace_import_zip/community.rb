# src/dspace_import_zip/community.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Get existing communities from the DSpace instance.

require 'common'
require 'dspace'

# =============================================================================
# :section: Classes
# =============================================================================

# A table of DSpace communities.
#
class Community < Hash

  # The name of the DSpace community.
  # @return [String]
  def name = self[__method__]

  # The DSpace handle associated with the community.
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

    # Existing communities acquired from DSpace.
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
