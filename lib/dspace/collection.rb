# lib/dspace/collection.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API collection methods.

require_relative 'entity'

module Dspace::Collection

  include Dspace::Api

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  class Entry < Dspace::Entity::Entry
  end

  # ===========================================================================
  # :section: Constants
  # ===========================================================================

  # Collections which won't show up in the DSpace API response.
  #
  # @type [Array<Entry>]
  #
  HIDDEN_COLLECTIONS = [
    if production?
      Entry.new(name: 'Profiles', handle: '123456789/3', uuid: '002cb6bf-7b21-409c-bfcf-2c3b543a193e')
    else
      Entry.new(name: 'Profiles', handle: '123456789/3', uuid: '6cd1178e-94c6-4db5-8965-fd7ce443969b')
    end,
    if production?
      Entry.new(name: 'OrgUnits', handle: '123456789/4', uuid: '3d9b25c0-2e83-4d27-b823-423825a2c653')
    else
      Entry.new(name: 'OrgUnits', handle: '123456789/4', uuid: 'eecf980e-19cd-46fe-9fc1-449d412d3f12')
    end,
  ].freeze

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Fetch all DSpace collections.
  #
  # Because the DSpace API request includes only publicly-visible collections,
  # default collections for Persons and OrgUnits have to be included manually.
  #
  # @param [Symbol, nil] sort_key     One of `Entry#keys`.
  # @param [Hash]        opt          Passed to #get_collection_objects.
  #
  # @return [Hash{String=>Entry}]
  #
  def collections(sort_key: :name, **opt)
    list, pages = get_collection_objects(**opt)
    result = transform_collection_objects(list, **opt)
    (1...pages).each do |pg|
      list, _ = get_collection_objects(**opt, page: pg)
      result.merge!(transform_collection_objects(list, **opt))
    end
    result_key = opt[:result_key] || Entry.default_key
    HIDDEN_COLLECTIONS.each do |entry|
      key = entry[result_key]
      result[key] = entry
    end
    sort_key ? result.sort_by { |_, entry| entry[sort_key] }.to_h : result
  end

  # ===========================================================================
  # :section: Internal methods
  # ===========================================================================

  protected

  # Fetch the DSpace API search result objects for collections.
  #
  # @param [Hash] opt                 Passed to #dspace_api.
  #
  # @return [Array<(Array<Hash>,Integer)>]  Objects and total number of pages.
  #
  def get_collection_objects(**opt)
    opt.delete(:result_key) # Not appropriate in this context.
    data  = dspace_api('core/collections', dsoType: 'item', **opt)
    pages = data.dig(:page, :totalPages) || 1
    items = Array.wrap(data.dig(:_embedded, :collections))
    return items, pages
  end

  # Transform DSpace API search result objects.
  #
  # @param [Array<Hash>] list
  # @param [Symbol]      result_key   One of `Entry#keys`.
  #
  # @return [Hash{String=>Entry}]
  #
  def transform_collection_objects(list, result_key: Entry.default_key, **)
    list.map { |item|
      entry = Entry.new(item)
      key   = entry[result_key]
      [key, entry]
    }.to_h
  end

end
