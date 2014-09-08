#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP log scan script
# Tom Epperly NS6T
# ns6t@arrl.net

require_relative 'logscan'

logCheck = CheckLog.new

ARGV.each { |file|
  if File.file?(file)
    print "File: " + file + "\n"
    log = logCheck.checkLog(file, -1)
    print log.to_s
  end
}
