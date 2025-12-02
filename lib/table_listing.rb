# lib/table_listing.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Generate an output table

# =============================================================================
# :section: Class
# =============================================================================

# Generation of output in tabular form.
#
class TableListing

  # Column separator used for --data output.
  #
  # @type [String]
  #
  DATA_DELIMITER = '|'

  # ===========================================================================
  # :section:
  # ===========================================================================

  # Column heading of each column.
  #
  # @return [Array<String>]
  #
  attr_reader :col_heading

  # Data extraction key associated with each column.
  #
  # @return [Array<Symbol>]
  #
  attr_reader :value_key

  # Indicate whether the output should start with a heading row.
  #
  # @return [Boolean]
  #
  attr_reader :heading_row

  # ===========================================================================
  # :section:
  # ===========================================================================

  # Create a new TableListing instance.
  #
  # @param [Hash{String=>Symbol}]  template   Default: subclass #template.
  # @param [Array<Symbol>, Symbol] only       Generate only these columns.
  # @param [Boolean]               head       Default: true.
  #
  def initialize(template = self.class.template, only: nil, head: nil, **)
    @value_key = template.values.map(&:to_sym)
    if only
      only = Array.wrap(only).map(&:to_sym)
      if (invalid = only - @value_key).present?
        raise "only=#{invalid.inspect} not in #{@value_key.inspect}"
      end
      @value_key = only
      template   = template.select { |_, v| only.include?(v) }
    end
    @col_heading = template.keys.map(&:to_s)
    case
      when option.data then @heading_row = false
      when only        then @heading_row = head || false
      else                  @heading_row = !head.is_a?(FalseClass)
    end
  end

  # Mapping of column heading to data extraction key.
  # The number of elements is the number of output columns.
  #
  # @return [Hash{String=>Symbol}]
  #
  def self.template
    { 'UUID' => :uuid, 'Handle' => :handle, 'Name' => :title }
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  # Generate an output table from the given source.
  #
  # @param [Array<Hash>, Hash{*=>Hash}] source
  # @param [Boolean]                    head
  # @param [Boolean]                    data
  #
  def output(source, head: heading_row, data: option.data)
    col_count = value_key.size
    column = (0...col_count).map { [] }
    if head
      column[0] << "# #{col_heading[0]}"
      (1...col_count).each do |col|
        column[col] << col_heading[col]
      end
    end
    source = source.values if source.is_a?(Hash)
    source.each do |entry|
      (0...col_count).each do |col|
        key = value_key[col]
        val = entry.respond_to?(key) ? entry.send(key) : entry[key]
        column[col] << val
      end
    end
    output_columns(column, delimiter: (DATA_DELIMITER if data))
  end

end
