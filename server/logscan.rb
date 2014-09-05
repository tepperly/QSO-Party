#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# CQP log scan script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

def mySplit(str, pattern)
  result = [ ]
  start = 0
  while m = pattern.match(str, start)
    result << str[start..(m.begin(0)-1)]
    start = m.end(0)
  end
  if start < str.length
    result << str[start..-1]
  end
  result
end

END_OF_RECORD = /(\r\n?|\n\r?)(?=([a-z]+(-[a-z]+)*:))/i

def splitLines(str)
  lines = mySplit(str, END_OF_RECORD)
  lines.each { |line|
    print "LINE=" + line.strip + "\n"
  }
  nil
end

def logProperties(str)
  results = { }
  results["QSOlines"] = str.scan(/\bqso:\s+/).size
  
  results
end
