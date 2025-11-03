# lib/dspace/community.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API community methods.

require 'dspace/item'

# Information about current DSpace communities.
#
module Dspace::Community

  # ===========================================================================
  # :section: Modules
  # ===========================================================================

  # Methods supporting community paths.
  #
  module Path

    include Dspace::Api

    # =========================================================================
    # :section: Constants
    # =========================================================================

    public

    # Community / sub-community / collection separator.
    #
    # @type [String]
    #
    SEPARATOR = ' >> '

    # =========================================================================
    # :section: Methods
    # =========================================================================

    public

    # Indicate whether the argument could be a full community path.
    #
    # @param [String, nil] arg
    #
    def full_path?(arg)
      arg.is_a?(String) && arg.include?(SEPARATOR)
    end

    # =========================================================================
    # :section: Module methods
    # =========================================================================

    public

    # Storage for community paths already looked-up.
    #
    # @return [Hash{String=>Hash}]
    #
    def self.saved_community
      @saved_community ||= {}
    end

  end

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Information for a community acquired from the DSpace API.
  #
  class Entry < Dspace::Item::Entry

    include Dspace::Api
    include Dspace::Community::Path

    def full_path = self[__method__] # Full community path of community.

    KEYS = (superclass::KEYS + instance_methods(false)).freeze

    # =========================================================================
    # :section: Dspace::Item::Entry overrides
    # =========================================================================

    public

    # Initialize the entry with the provided hash value.
    #
    # @param [Hash, nil] obj          Provided directly or:
    # @param [Hash]      opt          Provided via keyword arguments.
    # @param [Boolean]   full         If *true*, add community path to name.
    #
    def initialize(obj = nil, full: nil, **opt)
      super(obj, **opt)
      name = self[:name]
      name_full = full_path?(name)
      self[:name] = name.split(SEPARATOR).last if name_full
      if full && name_full
        self[:full_path] ||= name
      elsif full
        self[:full_path] ||= extract_community(obj, name)
      else
        self[:full_path] = nil
      end
    end

    # The display for this entry.
    #
    # @return [String]
    #
    def title
      self[:full_path] || super
    end

    # Indicate whether the target string matches an aspect of this entry.
    #
    # @param [String]  target
    # @param [Boolean] any_field      If *true*, consider all fields.
    #
    def match?(target, any_field = false)
      full_path?(target) ? (target == self[:full_path]) : super
    end

    # =========================================================================
    # :section: Internal methods
    # =========================================================================

    protected

    # The community/sub-community path to the given collection.
    #
    # @param [Hash, nil]   obj
    # @param [String, nil] base       Initial base path name.
    #
    # @return [String, nil]
    #
    def extract_community(obj, base = nil)
      path = Array.wrap(base)
      while (href = get_parent_url(obj)).present?
        # noinspection RubyMismatchedArgumentType
        if (obj = Path.saved_community[href])
          path << obj[:name]
        elsif (obj = dspace_api(href).presence)
          path << obj[:name]
          Path.saved_community[href] = obj
        end
      end
      path.reverse.join(SEPARATOR).presence
    end

    # The DSpace API URL for the parent community.
    #
    # @param [Hash, nil] obj
    #
    # @return [String, nil]
    #
    def get_parent_url(obj)
      return unless obj.is_a?(Hash)
      obj.dig(:_links, :parentCommunity, :href) || parent_url(obj[:uuid])
    end

    # The DSpace API URL for the parent community.
    #
    # @param [String, nil] uuid
    # @param [String]      endpoint   Format string for the URL endpoint.
    #
    # @return [String]
    # @return [nil]                   If *uuid* is nil.
    #
    def parent_url(uuid, endpoint: 'core/communities/%s/parentCommunity')
      dspace_api_url(endpoint % uuid) if uuid.present?
    end

  end

  # Acquire communities from DSpace.
  #
  class Lookup

    include Dspace::Api::Lookup

    # =========================================================================
    # :section: Dspace::Api::Lookup overrides
    # =========================================================================

    protected

    # Fetch the DSpace API search result objects for collections.
    #
    # @param [Hash] opt               Passed to #dspace_api.
    #
    # @return [Array<(Array<Hash>,Integer)>]  Objects and total number of pages
    #
    def get_items(**opt)
      super(item_type: :communities, **opt)
    end

    # Transform DSpace API search result objects into entries.
    #
    # @param [Array<Hash>] list
    # @param [Symbol]      result_key   One of `Entry#keys`.
    # @param [Hash]        opt          Passed to #transform_item.
    #
    # @return [Hash{String=>Entry}]
    #
    def transform_items(list, result_key: Entry.default_key, **opt)
      # noinspection RubyMismatchedReturnType
      super
    end

    # Transform a DSpace API search result list object into an entry.
    #
    # @param [Hash] item
    # @param [Hash] opt               Passed to Entry#initialize.
    #
    # @return [Entry]
    #
    def transform_item(item, **opt)
      Entry.new(item, **opt)
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    public

    # Existing communities acquired from DSpace.
    #
    # @param [Hash] opt               To #get_current_table on first run.
    #
    # @return [Hash{String=>Entry}]
    #
    def current_table(**opt)
      # noinspection RubyMismatchedReturnType
      @current_table ||= super
    end

    # =========================================================================
    # :section: StorageTable overrides
    # =========================================================================

    protected

    # The absolute path to the `current_table` data storage file.
    #
    # @return [String]
    #
    def storage_path
      @storage_path ||= super(file: "tmp/saved/#{DEPLOYMENT}/communities.json")
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Get information about DSpace communities.
  #
  # @param [Hash] opt                 Passed to Lookup#find_or_fetch.
  #
  # @return [Hash{String=>Entry}]
  #
  def communities(**opt)
    # noinspection RubyMismatchedReturnType
    Lookup.new.find_or_fetch(**opt)
  end

end
