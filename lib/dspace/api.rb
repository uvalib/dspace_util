# lib/dspace/api.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# DSpace API methods

require 'open-uri'
require 'common'
require 'logging'

module Dspace::Api

  # ===========================================================================
  # :section: Constants
  # ===========================================================================

  public

  # This appears to be the maximum page size accepted by DSpace API requests.
  #
  # @type [Integer]
  #
  PAGE_SIZE = 100

  # External hostname for the machine hosting the DSpace instance.
  #
  # @return [String]
  #
  PUBLIC_HOST = ENV['DSPACE_PUBLIC'].freeze

  # Internal VPN hostname for the machine hosting the DSpace instance.
  #
  # @return [String]
  #
  PRIVATE_HOST = ENV['DSPACE_PRIVATE'].freeze

  # Local DSpace handles begin with this prefix.
  #
  # @type [String]
  #
  HANDLE_PREFIX = ENV['DSPACE_PREFIX'].freeze

  # Local DSpace collection for Person entities.
  #
  # @type [String]
  #
  PERSON_COLLECTION = ENV['USR_COLLECTION'].freeze

  # Local DSpace collection for OrgUnit entities.
  #
  # @type [String]
  #
  ORG_COLLECTION = ENV['ORG_COLLECTION'].freeze

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Send a DSpace API request.
  #
  # The program is exited if there was an HTTP error.
  #
  # @param [String] path
  # @param [Hash]   opt
  #
  # @return [Hash{Symbol=>*}]
  #
  def dspace_api(path, **opt)
    path = File.join("https://#{PUBLIC_HOST}/server/api", path)
    opt  = opt.reverse_merge(size: PAGE_SIZE).map { "#{_1}=#{_2}" }.join('&')
    url  = [path, opt].compact.join('?')
    debug { "#{__method__}: GET #{url}" }
    text = URI.open(url).read || ''
    JSON.parse(text, symbolize_names: true)
  rescue OpenURI::HTTPError => e
    error { "#{__method__}: #{e}"}
    exit(false)
  end

end
