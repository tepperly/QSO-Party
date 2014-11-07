#!/usr/bin/ruby
# -*- encoding: utf-8; -*-
#
#

require_relative 'database'

QSOLINE=/^qso:\s+(\d+)\s+([a-z]+)\s+(\d+-\d+-\d+)\s+(\d+)\s+([a-z0-9\/]+)\s+(\d+)\s+([a-z]+)\s+([a-z0-9\/]+)\s+(\d+)\s+([a-z]+)\s*((\d+)\s*)?$/i

db = ChartDB.new
ARGV.each { |filename|
  open(filename, "r:ascii") { |infile|
    fileId = db.addLog(filename)
    infile.each { |line|
      if line =~ QSOLINE
        db.addQSO(fileId, $1, $2, $3, $4,
                  $5, $6, $7,
                  $8, $9, $10)
      end
    }
  }
}
