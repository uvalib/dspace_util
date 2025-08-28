# lib/logging.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Log output methods.

require 'common'

# =============================================================================
# :section: Methods - $stderr
# =============================================================================

def debug(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if option.debug
end

def info(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if option.debug || option.verbose
end

def warning(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) unless option.quiet
end

def error(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk)
end

def log_line(msg = nil, tag: nil)
  msg ||= (yield if block_given?)
  $stderr.puts tag ? "#{tag.upcase}: #{msg}" : msg unless msg.nil?
end

# =============================================================================
# :section: Methods - $stdout
# =============================================================================

def show(msg = nil, &blk)
  output_line(msg, &blk) unless option.quiet
end

def show_char(msg = nil, &blk)
  output_char(msg, &blk) unless option.quiet
end

def output_line(msg = nil)
  msg ||= (yield if block_given?)
  $stdout.puts msg unless msg.nil?
end

def output_char(c)
  c ||= (yield if block_given?)
  $stdout.print c unless c.nil?
end

# Output each row of a two-dimensional array of columns.
#
# @param [Array<Array<(Array<String>)>] column
#
def output_columns(column)
  max_col = column.size - 1
  max_row = column[0].size - 1
  width   = column.map { _1.map(&:size).max }
  (0..max_row).each do |row|
    cols =
      (0..max_col).map do |col|
        value = column[col][row]
        value = '%-*s' % [width[col], value] if col < max_col
        value
      end
    output_line cols.join('  ')
  end
end
