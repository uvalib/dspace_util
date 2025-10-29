# lib/publication.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace Publication entity type.

require 'entity'

# =============================================================================
# :section: Classes
# =============================================================================

# Encapsulates creation of Publication entities.
#
class Publication < Entity

  # Methods which derive Publication information from provided data.
  #
  module Methods
    include Entity::Methods
  end

  # Methods associated with the Publication class.
  #
  module ClassMethods
    include Entity::ClassMethods
    include Methods
  end

  extend ClassMethods

end
