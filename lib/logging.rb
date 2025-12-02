# lib/logging.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Log output methods.

require 'common'

# =============================================================================
# :section: Methods
# =============================================================================

def show?    = !option.quiet
def debug?   = option.debug
def info?    = option.verbose || debug?
def warning? = show?
def error?   = true

# =============================================================================
# :section: Methods - $stderr
# =============================================================================

def debug(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if debug?
end

def info(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if info?
end

def warning(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if warning?
end

def error(msg = nil, &blk)
  log_line(msg, tag: __method__, &blk) if error?
end

def log_line(msg = nil, tag: nil)
  msg ||= (yield if block_given?)
  $stderr.puts tag ? "#{tag.upcase}: #{msg}" : msg unless msg.nil?
end

# =============================================================================
# :section: Methods - $stdout
# =============================================================================

def show(msg = nil, &blk)
  output_line(msg, &blk) if show?
end

def show_char(msg = nil, &blk)
  output_char(msg, &blk) if show?
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
# @param [Array<Array<(Array<String>)>] columns
# @param [String, nil]                  delimiter   If provided do not format.
#
def output_columns(columns, delimiter: nil)
  max_col = columns.size - 1
  max_row = columns[0].size - 1
  width   = (columns.map { _1.compact.map(&:size).max } if delimiter.nil?)
  (0..max_row).each do |row|
    cols =
      (0..max_col).map do |col|
        value = columns[col][row]
        value = '%-*s' % [width[col], value] if width && (col < max_col)
        value
      end
    output_line cols.join(delimiter || '  ')
  end
end
