#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# CQP log scan script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#
# gems required 
#	levenshtein-ffi
# 	levenshtein

class LineIssue
  def initialize(lineNum, description, isError)
    @lineNum = lineNum
    @description = description
    @isError = isError
  end

  attr_reader :lineNum, :description, :isError

end

class CQPLog 
  def initialize(id)
    @id = id
    @version = nil              # Cabrillo version
    @callsign = nil
    @assisted = false
    @numops = nil               # single, multi, or checklog
    @power = nil                # high, lower, or QRP
    @categories = { }           # fixed, mobile, portable, rover, expedition, hq, school
    @numtrans = nil             # number of transmitters (one, two, limited, unlimited, swl
    @maxqso = nil
    @validqso = nil
    @email = nil
    @sentqth = { }
    @operators = { }            # set of operators
    @comments = nil
    @qsos = [ ]
    @warnings = [ ]
    @errors = [ ]
  end
  
  attr_writer :callsign, :assisted, :numops, :power, :categories, :numtrans, :maxqso,
            :validqso, :email, :sentqth, :operators, :qsos, :warnings, :errors
  attr_reader :id
end

class LineChecker
  EOLREGEX=/\r\n?|\n\r?/
  TAGREGEX=/\A([a-z]+(-[a-z]+)*):/i
  LOOSETAGREGEX=/\A([a-z]+([- ][a-z]+)*):/i
  def extractTag(line)
    if m = TAGREGEX.match(line)
      reurn m[1]
    end
    nil
  end

  def advanceCount(startLineNum, line)
    startLineNum + line.scan(EOLREGEX).size
  end
  
  def matchesLine?(line)
    nil                         # generic never matches
  end

  def inexactMatch?(line)
    true                        # always inexact match
  end

  def sample(line)
    eol = line.index(EOLREGEX)
    if eol
      limit = [20, line.length, eol].min
    else
      limit = [20, line.length].min
    end
    " '" + line[0, limit] + "'"
  end

  def syntaxCheck(line, log, startLineNum)
    if m = LOOSETAGREGEX.match(line)
      log.errors << LineIssue.new(startLine, "Unknown tag: " + m[1])
    else
      log.errors << LineIssue.new(startLine, "Doesn't match any known tag:" + sample(line)  )
    end
    advanceCount
  end

  def inexactCheck(line, log, startLineNum)
    syntaxCheck(line, log, startLineNum)
  end
end

class StartLogTag < LineChecker
  
end



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

def logProperties(id, str)
  log = CQPLog.new(id)
  log.maxqso = str.scan(/\bqso:\s+/i).size # maximum number of QSO lines
  
  
  results = { }
  results["QSOlines"] = str.scan(/\bqso:\s+/).size
  
  results
end
