# src/dspace_import_zip/logging.rb
#
# frozen_string_literal: true
# warn_indent:           true
#
# Log output methods.

require_relative 'common'

# =============================================================================
# :section: Methods
# =============================================================================

def debug(msg = nil, &blk)
  output_line(msg, tag: 'DEBUG', &blk) if debugging
end

def info(msg = nil, &blk)
  output_line(msg, tag: 'INFO', &blk) if verbose
end

def warning(msg = nil, &blk)
  output_line(msg, tag: 'WARNING', &blk) unless silent
end

def error(msg = nil, &blk)
  output_line(msg, tag: 'ERROR', &blk)
end

def show(msg = nil, &blk)
  output_line(msg, &blk) unless silent
end

def show_char(msg = nil, &blk)
  output_char(msg, &blk) unless silent
end

def output_line(msg = nil, tag: nil)
  msg ||= (yield if block_given?)
  $stdout.puts tag ? "#{tag}: #{msg}" : msg
end

def output_char(c)
  c ||= (yield if block_given?)
  $stdout.print c
end
