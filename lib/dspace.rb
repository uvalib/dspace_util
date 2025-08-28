# lib/dspace.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API methods.

module Dspace

  require 'dspace/collection'
  require 'dspace/item'
  require 'dspace/person'
  require 'dspace/org_unit'
  require 'dspace/publication'

  extend Dspace::Collection
  extend Dspace::Item
  extend Dspace::Person
  extend Dspace::OrgUnit
  extend Dspace::Publication

end
