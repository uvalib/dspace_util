# src/dspace_import_zip/publication/metadata.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Methods for translating a LibraOpen export to the DSpace "dublin_core.xml"
# for a Publication entity import.

require 'common'
require 'logging'

require_relative '../person'
require_relative '../xml'

# Methods for translating a LibraOpen export to the DSpace "dublin_core.xml"
# for a Publication entity import.
#
module Publication::Metadata

  # ===========================================================================
  # :section: Constants
  # ===========================================================================

  # Indicate whether DOIs should be included as "dc.identifier.doi" in
  # Publication metadata.
  #
  # This is the old LibraOpen DOI which will eventually be mapped to the new
  # DSpace item.
  #
  # @type [Boolean]
  #
  DOI = true

  # Indicate whether DOIs should appear as "dc.identifier.uri" in addition to
  # "dc.identifier.doi" in Publication metadata.
  #
  # This will make the old LibraOpen DOI appear as a link on DSpace item show
  # pages under the "URI" section.
  #
  # @type [Boolean]
  #
  DOI_URI = DOI

  # ===========================================================================
  # :section: Modules
  # ===========================================================================

  # Methods supporting the transformation of LibraOpen data into a form
  # appropriate for DSpace metadata.
  #
  module TransformationMethods

    # Create a map of UUID to "last_name, first_name".
    #
    # As a side effect, `export.person` will be filled with the UUIDs of
    # authors associated with this item (but not contributors).  For authors,
    # this method always returns an empty object so that
    # "dc.contributor.author" is not created to avoid duplication with
    # "relation.isAuthorOfPublication".
    #
    # @param [ExportItem] item
    # @param [Symbol]     kind        Either :author or :contributor.
    #
    # @return [Hash{String=>String}]
    #
    def map_persons!(item, kind)
      info { "#{__method__}(#{kind})" }
      res = {}
      set = (kind == :author) ? item.author_metadata : item.contributor_metadata
      set.each_pair do |file, data|
        if (key = Person.key_for(data)).nil?
          error { "#{file}: no computing_id or last_name" }
        elsif kind != :author
          debug { (val = res[key]) and "#{file}[#{key}]: override #{val.inspect}" }
          res[key] = Person.title_name(data)
        elsif item.person.include?(key)
          debug { "#{file}[#{key}]: duplicate" }
        else
          item.person << key
        end
      end
      res
    end

    # =========================================================================
    # :section: Internal methods - language
    # =========================================================================

    # Translation of a LibraOpen "language" value to a "dc.language.iso" value.
    #
    # @type [Hash{String=>String}]
    #
    LANGUAGE = {
      'Chinese'    => 'zh',
      'English'    => 'en',
      'French'     => 'fr',
      'German'     => 'de', # not present in LibraOpen
      'Italian'    => 'it', # not present in LibraOpen
      'Japanese'   => 'ja', # not present in LibraOpen
      'Portuguese' => 'pt',
      'Russian'    => 'ru', # not configured in DSpace currently
      'Spanish'    => 'es',
      'Turkish'    => 'tr', # not present in LibraOpen
    }.freeze

    # Produce a "dc.language.iso" value from a LibraOpen "language" value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def language_iso(value, field: :language)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.strip
      # noinspection RubyMismatchedReturnType
      LANGUAGE[value] || value if value.present?
    end

    # =========================================================================
    # :section: Internal methods - rights
    # =========================================================================

    # Translation of Libra "rights" field index value to DSpace "dc.rights".
    #
    # @type [Array<String>]
    #
    RIGHTS = [
      'All rights reserved (no additional license for public reuse)',             # [0]
      'CC0 1.0 Universal',                                                        # [1]
      'Attribution 2.0 Generic (CC BY)',                                          # [2]
      'Attribution 4.0 International (CC BY)',                                    # [3]
      'Attribution-NoDerivatives 4.0 International (CC BY-ND)',                   # [4]
      'Attribution-NonCommercial 4.0 International (CC BY-NC)',                   # [5]
      'Attribution-NonCommercial-NoDerivatives 4.0 International (CC BY-NC-ND)',  # [6]
      'Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA)',     # [7]
      'Attribution-ShareAlike 4.0 International (CC BY-SA)',                      # [8]
    ].freeze

    # Translation of Libra "rights" field index value to a "dc.rights.uri".
    #
    # @type [Array<String,nil>]
    #
    RIGHTS_URI = [
      nil,                                                  # [0]
      'https://creativecommons.org/publicdomain/zero/1.0/', # [1]
      'https://creativecommons.org/licenses/by/2.0/',       # [2]
      'https://creativecommons.org/licenses/by/4.0/',       # [3]
      'https://creativecommons.org/licenses/by-nd/4.0/',    # [4]
      'https://creativecommons.org/licenses/by-nc/4.0/',    # [5]
      'https://creativecommons.org/licenses/by-nc-nd/4.0/', # [6]
      'https://creativecommons.org/licenses/by-nc-sa/4.0/', # [7]
      'https://creativecommons.org/licenses/by-sa/4.0/',    # [8]
    ].freeze

    # Get a DSpace "dc.rights" value from a LibraOpen "rights" field value.
    #
    # @param [Integer, String, Hash] value
    # @param [Symbol]                field
    #
    # @return [String, nil]
    #
    def rights(value, field: :rights)
      value = value[field] if value.is_a?(Hash)
      value = value.strip  if value.is_a?(String)
      index =
        case value
          when Integer then value
          when String  then value.to_i if value.tr('0-9', '').blank?
        end
      RIGHTS[index] || value&.to_s if index
    end

    # Get a DSpace "dc.rights.uri" value from a LibraOpen "rights" field value.
    #
    # @param [Integer, String, Hash] value
    # @param [Symbol]                field
    #
    # @return [String, nil]
    #
    def rights_uri(value, field: :rights)
      value = value[field] if value.is_a?(Hash)
      value = value.strip  if value.is_a?(String)
      index =
        case value
          when Integer then value
          when String  then value.to_i if value.tr('0-9', '').blank?
        end
      RIGHTS_URI[index] if index
    end

    # =========================================================================
    # :section: Internal methods - subject
    # =========================================================================

    # LibraOpen "keyword" value which should be used without splitting.
    #
    # Otherwise, a value containing a comma is interpreted as a list of keyword
    # phrases to be split into separate subject terms.
    #
    # @type [Hash{String=>Array<String>}]
    #
    #--
    # noinspection SpellCheckingInspection
    #++
    SUBJECT_PHRASE = {
      'Advanced chronic kidney disease (ACKD), palliative care (PC)'    => ['Advanced Chronic Kidney Disease', 'ACKD', 'Palliative Care', 'PC'],
      'African Americans'                                               => ['African-Americans'],
      'Artificial Intelligence (AI)'                                    => ['Artificial Intelligence', 'AI'],
      'Artificial intelligence (AI)'                                    => ['Artificial Intelligence', 'AI'],
      'BERT (Bidirectional Encoder Representations from Transformers)'  => ['BERT', 'Bidirectional Encoder Representations from Transformers'],
      'Belief elicitation, BDM, Lottery Choice, BDM, risk aversion'     => ['Belief Elicitation', 'BDM', 'Lottery Choice', 'Risk Aversion'],
      'Broadband, equity, digital'                                      => ['Broadband', 'Digital Equity'],
      'Charlottesville, VA'                                             => nil,
      'Charlottesville, Virginia'                                       => ['Charlottesville, VA'],
      'Clausen, Hugh J., 1926-'                                         => nil,
      'Community Learning through Data Driven Discovery (CLD3)'         => ['Community Learning Through Data Driven Discovery', 'CLD3'],
      'Computer, Math, and Physical Sciences'                           => nil,
      'Cooperative Extension System (CES)'                              => ['Cooperative Extension System', 'CES'],
      'Exploratory data analysis (EDA)'                                 => ['Exploratory Data Analysis', 'EDA'],
      'FGLI (first generation low income)'                              => ['FGLI', 'First Generation Low Income'],
      'Haughney, Edward W. , 1917-'                                     => ['Haughney, Edward W., 1917-'],
      'Learning Health Systems (LHS)'                                   => ['Learning Health Systems', 'LHS'],
      'Levie, Howard S., 1907- 2009'                                    => ['Levie, Howard S., 1907-2009'],
      'Machine learning (ML)'                                           => ['Machine Learning', 'ML'],
      'Nardotti, Michael, 1947-'                                        => nil,
      'Natural Language Processing (NLP)'                               => ['Natural Language Processing', 'NLP'],
      'Open Educational Resources (OER)'                                => ['Open Educational Resources', 'OER'],
      'Parker, Harold E., 1918-'                                        => nil,
      'SACO (Subject Authority Cooperative Program)'                    => ['SACO', 'Subject Authority Cooperative Program'],
      'Saville & Co., Inc'                                              => ['Saville'],
      'Social Justice, Equity and Inclusion'                            => ['Social Justice', 'Equity', 'Inclusion'],
      'Social Justice, Equity, and Inclusion'                           => ['Social Justice', 'Equity', 'Inclusion'],
      'Social construction of technology (SCOT)'                        => ['Social Construction of Technology', 'SCOT'],
      'Third-party (private sector) data'                               => ['Third-Party (Private Sector) Data'],
      'Vietnamese Conflict, 1961-1975'                                  => nil,
      'White, Charles, 1939-'                                           => nil,
      'Wiener, Frederick Bernays, 1906-1996'                            => nil,
    }.map { |k, v| [k, (v || [k]).freeze] }.to_h.freeze

    # LibraOpen "keyword" part which should not be capitalized.
    #
    # @type [Array<String>]
    #
    SUBJECT_WORD = %w[
      a
      an
      and
      bin
      cMYC
      dN/dS
      de
      des
      fMRI
      for
      iTHRIV
      in
      lncRNA
      mHealth
      of
      on
      pN/pS
      the
    ].freeze

    # LibraOpen "keyword" part which should be corrected or transformed.
    #
    # @type [Hash{String=>String}]
    #
    #--
    # noinspection SpellCheckingInspection
    #++
    SUBJECT_FIX = {
      '19th-Century'              => '19th Century',
      'Aged-related'              => 'Age-Related',
      'Agrictulture'              => 'Agriculture',
      'Catalogue'                 => 'Catalog',
      'Cell-to-cell'              => 'Cell-to-Cell',
      'Charlottesville, VA'       => 'Charlottesville, Virginia',
      'Colleciton'                => 'Collection',
      'Colletion'                 => 'Collection',
      'Community-building'        => 'Community-Building',
      'Consumer-resource'         => 'Consumer-Resource',
      'Context-dependence'        => 'Context Dependence',
      'Cultual'                   => 'Cultural',
      'Decision-making'           => 'Decision-Making',
      'DeepFakes'                 => 'Deep Fakes',
      'Deepfakes'                 => 'Deep Fakes',
      'Difference-in-differences' => 'Difference-in-Differences',
      'Dual-mode'                 => 'Dual-Mode',
      'Evidence-based'            => 'Evidence-Based',
      'Faith-based'               => 'Faith-Based',
      'First-generation'          => 'First-Generation',
      'GSVScapstone'              => 'GSVS Capstone',
      'Gender-based'              => 'Gender-Based',
      'Gender-diverse'            => 'Gender-Diverse',
      'Grfp'                      => 'GRFP',
      'High-fat'                  => 'High-Fat',
      'Hip-hop'                   => 'Hip-Hop',
      'Host-pathogen'             => 'Host-Pathogen',
      'Human-computer'            => 'Human-Computer',
      'Human-labeled'             => 'Human-Labeled',
      'Humanites'                 => 'Humanities',
      'Ithriv'                    => 'iTHRIV',
      'Job-ads'                   => 'Job Postings',
      'Leanring'                  => 'Learning',
      'LncRNAs'                   => 'lncRNA',
      'Low-income'                => 'Low-Income',
      'Metal-insulator'           => 'Metal-Insulator',
      'Musicial'                  => 'Musical',
      'Nih'                       => 'NIH',
      'Nsf'                       => 'NSF',
      'Off-site'                  => 'Off-Site',
      'Patient-provider'          => 'Patient-Provider',
      'Peer-reviewed'             => 'Peer-Reviewed',
      'Plaigiarism'               => 'Plagiarism',
      'Privacy-preserving'        => 'Privacy-Preserving',
      'Rank-dependent'            => 'Rank-Dependent',
      'Rear-end'                  => 'Rear-End',
      'Repsoirtory'               => 'Repository',
      'Research-and-development'  => 'Research and Development',
      'Self-binding'              => 'Self-Binding',
      'Self-control'              => 'Self-Control',
      'Socio-demographic'         => 'Socio-Demographic',
      'Socio-ecological'          => 'Socio-Ecological',
      'Spectroscopyk'             => 'Spectroscopy',
      'Succesion'                 => 'Succession',
      'Task-based'                => 'Task-Based',
      'Time-space'                => 'Time-Space',
      'UVa'                       => 'UVA',
      'UVaOHP'                    => 'UVA OHP',
      'Well-being'                => 'Well-Being',
      'Work-life'                 => 'Work-Life',
      'Zero-inflated'             => 'Zero-Inflated',
    }.freeze

    # Get DSpace "dc.subject" value(s) from a LibraOpen "keyword" value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [Array<String>, nil]
    #
    def subject(value, field: :keyword)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.squish.presence or return
      value = value.gsub(/"/, '').sub(/\s*[,.]+$/, '')
      SUBJECT_PHRASE[value.upcase_first] ||
        value.split(/\s*[,;]\s*/).compact_blank.map do |phrase|
          phrase.split(' ').map { |word|
            if SUBJECT_WORD.include?(word)
              word
            else
              word = word.upcase_first
              SUBJECT_FIX[word] || word
            end
          }.join(' ')
        end
    end

    # =========================================================================
    # :section: Internal methods - type
    # =========================================================================

    # Translation of LibraOpen "resource_type" to DSpace "dc.type".
    #
    # Any values which are not included here are either the same in both cases
    # or they should be transmitted as-is (based on the assumption that DSpace
    # will not reject unexpected values).
    #
    # @type [Hash{String=>String}]
    #
    RESOURCE_TYPE = {
      'Part of Book'                  => 'Book chapter',
      'Educational Resource'          => 'Learning Object',
      'Map or Cartographic Material'  => 'Map',
      'Report'                        => 'Technical Report',
    }.freeze

    # Get a DSpace "dc.type" value from a LibraOpen "resource_type" value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def resource(value, field: :resource_type)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.strip
      # noinspection RubyMismatchedReturnType
      RESOURCE_TYPE[value] || value if value.present?
    end

    # =========================================================================
    # :section: Internal methods - DOI
    # =========================================================================

    # Produce a "dc.identifier.doi" value from a LibraOpen "doi" field value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def doi(value, field: :doi)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.strip.presence or return
      value.sub!(/^doi:/i, '')
      value.sub!(/^https?:\/\/(\w+\.)*doi\.org/i, '')
      value.delete_prefix('/').presence
    end

    # Produce a "dc.identifier.uri" value from a LibraOpen "doi" field value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def doi_uri(value, field: :doi)
      id = doi(value, field: field)
      "https://doi.org/#{id}" if id
    end

    # =========================================================================
    # :section: Internal methods - date
    # =========================================================================

    # Produce a "dc.date.issued" from a LibraOpen "published_date" field value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String]                "YYYY-MM-DD" or the original value.
    # @return [nil]                   If `value` was nil or blank.
    #
    def issue_date(value, field: :published_date)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.squish.sub(/^(forthcoming|in.progress)\D*/i, '')
      return if value.blank?
      yymmdd =
        case value
          when /^(\d{4})$/                             then [$1,  1,  1]
          when /^spring (\d{4})$/i                     then [$1,  3,  1]
          when /^summer (\d{4})$/i                     then [$1,  6,  1]
          when /^fall (\d{4})$/i                       then [$1,  9,  1]
          when /^winter (\d{4})$/i                     then [$1, 12,  1]
          when /^(\d{4})-(\d{1,2})$/                   then [$1, $2,  1]
          when /^(\d{4})-(\d{1,2})-(\d{1,2})( *T.*)?$/ then [$1, $2, $3]
          when /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/       then [$3, $1, $2]
          when /^(\d{1,2})\/(\d{1,2})\/([012]\d)$/     then ["20#{$3}", $1, $2]
          when /^(\d{1,2})\/(\d{1,2})\/(\d{2})$/       then ["19#{$3}", $1, $2]
        end
      if yymmdd
        '%04d-%02d-%02d' % yymmdd.map(&:to_i)
      else
        # noinspection RubyMismatchedArgumentType
        Date.parse(value).to_s rescue value
      end
    end

    # Produce a "dc.description" from a LibraOpen "date_modified" field value.
    #
    # @param [String, Hash] value
    # @param [Symbol]       field
    #
    # @return [String, nil]
    #
    def submit_date(value, field: :date_modified)
      value = value[field] if value.is_a?(Hash)
      value = value.to_s.strip.presence or return
      value.sub!(/\.\d+(Z|\+\d\d?:\d\d)$/, '\1')
      value.sub!(/\+00:00$/, 'Z')
      "Original submission date: #{value}"
    end

  end

  # ===========================================================================
  # :section: Classes
  # ===========================================================================

  # Build a <dublin_core> element of metadata for a Publication.
  #
  class MetadataXml < Xml

    include TransformationMethods

    # @return [Hash{Symbol=>*}]
    attr_reader :work_metadata

    # =========================================================================
    # :section: Xml overrides
    # =========================================================================

    public

    # Create a new MetadataXml instance.
    #
    # @param [ExportItem] item        LibraOpen work exported values.
    # @param [Hash]       opt         Passed to super.
    #
    def initialize(item, **opt, &_blk)
      @work_metadata = item.work_metadata
      authors      = map_persons!(item, :author)
      contributors = map_persons!(item, :contributor)
      super(**opt) do
        #      LibraOpen field     DSpace element  DSpace qualifier  Value translation
        #      ------------------- --------------  ----------------  -------------------
        multi( :title,             'title')
        multi( :author_ids,        'contributor',  'author')         { authors[_1] }
        multi( :contributor_ids,   'contributor')                    { contributors[_1] }
        multi( :language,          'language')
        multi( :language,          'language',     'iso')            { language_iso(_1) }
        multi( :rights,            'rights')                         { rights(_1) }
        multi( :rights,            'rights',       'uri')            { rights_uri(_1) }
        multi( :keyword,           'subject')                        { subject(_1) }
        multi( :related_url,       'relation')
        multi( :sponsoring_agency, 'description',  'sponsorship')
        single(:resource_type,     'type')                           { resource(_1) }
        single(:publisher,         'publisher')
        single(:published_date,    'date',         'issued')         { issue_date(_1) }
        single(:id,                'identifier')
        single(:doi,               'identifier',   'doi')            { doi(_1) }         if DOI
        single(:doi,               'identifier',   'uri')            { doi_uri(_1) }     if DOI_URI
        single(:source_citation,   'identifier',   'citation')
        single(:notes,             'description')
        single(:date_modified,     'description')                    { submit_date(_1) }
        single(:abstract,          'description',  'abstract')
      end
    end

    # Emit one <dcvalue> element for a single-value field.
    #
    # @param [Symbol]      field      Work field holding the element value.
    # @param [String]      e          Element name attribute.
    # @param [String, nil] q          Qualifier attribute.
    #
    # @return [void]
    #
    def single(field, e, q = nil, &blk)
      field = work_metadata[field]
      super
    end

    # Emit multiple <dcvalue> elements for a multi-valued field.
    #
    # @param [Symbol]      field      Work field holding the element value.
    # @param [String]      e          Element name attribute
    # @param [String, nil] q          Qualifier attribute
    #
    # @return [void]
    #
    def multi(field, e, q = nil, &blk)
      field = work_metadata[field]
      super
    end

  end

  # ===========================================================================
  # :section: Methods
  # ===========================================================================

  # Content for the "dublin_core.xml" of a Publication entity import.
  #
  # As a side effect, `item.person` will be filled with the UUIDs of authors
  # associated with this item (but not contributors).
  #
  # @param [ExportItem] item
  #
  # @return [String]
  #
  def make_metadata(item)
    MetadataXml.new(item).to_xml
  end

end
