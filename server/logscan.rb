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

require 'time'
# require 'cgi'
require 'levenshtein'
require 'json'

class ContestPeriod
  def initialize(start, stop)
    @start = start
    @stop = stop
  end

  def inContest?(time)
    (time >= @start) and (time <= @stop)
  end
end

$CONTESTS = [
  ContestPeriod.new(Time.utc(2015, 10, 3, 16, 0), Time.utc(2015, 10, 4, 22, 0))
#  ContestPeriod.new(Time.utc(2014, 10, 4, 16, 0), Time.utc(2014, 10, 5, 22, 0)), # CQP 2014
#  ContestPeriod.new(Time.utc(2013, 10, 5, 16, 0), Time.utc(2013, 10, 6, 22, 0)), # CQP 2013
#  ContestPeriod.new(Time.utc(2012, 10, 6, 16, 0), Time.utc(2013, 10, 7, 22, 0))
]

class LineIssue
  def initialize(lineNum, description, isError, header=true)
    @lineNum = lineNum
    @description = description
    @isError = isError
    @header = header
  end

  attr_reader :lineNum, :description, :isError, :header

  def to_s
    @lineNum.to_s + ": " + @description
  end

  def to_hash
    { "line" => @lineNum, "msg" => @description }
  end
end

class CQPLog
  def initialize(id, filename, multregex, multaliases)
    @id = id
    @filename = filename
    @version = nil              # Cabrillo version
    @callsign = nil
    @state = 0                  # 0 - before log, 1 - start-of-log, 2 - QSO section, 3 - end-of-line
    @band = nil
    @badcallsigns = { }         # collection of bad callsigns
    @warnmultipliers = { }      # collection of aliases multipliers
    @badmultipliers = { }       # collection of unknown multipliers
    @tally = Hash.new(0)        # callsign database
    @mode = nil
    @name = nil                 # operator name
    @assisted = nil
    @numops = nil               # single, multi, or checklog
    @power = nil                # high, low, or QRP
    @categories = { }           # mobile, expedition, school, youth, yl, newcontester
    @numtrans = nil             # number of transmitters (one, two, limited, unlimited, swl
    @maxqso = nil
    @validqso = 0
    @email = nil
    @sentqth = { }
    @operators = { }            # set of operators
    @comments = nil
    @qsos = [ ]
    @warnings = [ ]
    @errors = [ ]
    @multtest = multregex
    @multaliases = multaliases
  end

  def county?
    @categories.has_key?("expedition") ? 1 : 0
  end

  def school?
    @categories.has_key?("school") ? 1 : 0
  end

  def youth?
    @categories.has_key?("youth") ? 1 : 0
  end

  def mobile?
    @categories.has_key?("mobile") ? 1 : 0
  end

  def female?
    @categories.has_key?("female") ? 1 : 0
  end
  
  def newcontester?
    @categories.has_key?("newcontester") ? 1 : 0
  end

  def numOpsInconsistent?
    result = false
    if @numops and (@numops != :checklog)
      opCount = @operators.keys.count { |op| not op.start_with?("@") }
      if opCount > 0
        result = ! ( ( opCount == 1 and @numops == :single ) or (opCount > 1 and @numops == :multi ) )
      end
    end
    result
  end

  def stateName
    [ "before START-OF-LOG",
      "in log header section",
      "in QSO section",
      "after END-OF-LOG" ][@state]
  end
  
  attr_writer :callsign, :assisted, :numops, :power, :categories, :numtrans, :maxqso, :band,
            :validqso, :email, :sentqth, :operators, :qsos, :warnings, :errors,
            :state, :name, :badcallsigns, :version, :mode, :comments
  attr_reader :id, :callsign, :assisted, :numops, :power, :categories, :numtrans, :maxqso,
            :validqso, :email, :sentqth, :operators, :qsos, :warnings, :errors, :state, :band,
            :name, :badcallsigns, :version, :mode, :comments, :badmultipliers, :warnmultipliers,
            :tally, :filename

  def to_s
    @id.to_s + "\nCabrillo version: " + @version.to_s + "\nCallsign: " + @callsign.to_s + "\nState: " +
      @state.to_s + "\nBand: " + @band.to_s + "\nBad callsigns: " + @badcallsigns.keys.sort.join(' ') + 
      "\nAliased multipliers:" + @warnmultipliers.keys.sort.join(' ') + "\nBad multipliers: " +
      @badmultipliers.keys.sort.join(' ') + "\nMode = " + @mode.to_s + "\nName: " + @name.to_s + "\nAssisted: " +
      @assisted.to_s + "\nPower: " + @power.to_s + "\nNum Ops: " + @numops.to_s + 
      "\nCategories: " + @categories.keys.sort.join(' ') + 
      "\nNum transceivers: " + @numtrans.to_s + "\nMax QSOs: " + @maxqso.to_s + "\nValid QSOs: " + @validqso.to_s + "\nEmail: " +
      @email.to_s + "\nSent QTH: " + translateQTH.join(' ') + "\nOperators: " + @operators.keys.sort.join(' ') + 
      "\nWarnings: " + @warnings.join("\n") + "\nErrors: " + @errors.join("\n") + "\n"
  end

  def calcOpMessage
    if @numops == :single
      if @assisted
        if (@numtrans == :two) or (@numtrans == :unlimited)
          return "Single-op assisted more than one transceiver maps to Multi-multi"
        end
      end
    end
    nil
  end
  
  def calcOpClass
    case @numops
    when :single
      if @assisted
        if @numtrans == :two or @numtrans == :unlimited
          return "multi-multi"
        else
          return "single-assisted"
        end
      else
        return "single"
      end
    when :multi
      if (not @numtrans) or (@numtrans == :one)
        return "multi-single"
      else
        return "multi-multi"
      end
    when :checklog
      return "checklog"
    else
      return "multi-multi"
    end
  end

  def powerStr
    case @power
    when :low
      return "Low"
    when :high
      return "High"
    when :QRP
      return "QRP"
    end
    return "High"
  end

  def filterQTH
    @sentqth.keys.find_all { |sq| @multtest.match(sq) }.sort.map { |qth| qth }
  end

  def translateQTH
    @sentqth.keys.map { |mult| @multaliases[mult] }.find_all { |mult| mult }.sort.uniq
  end

  def to_json
    result = Hash.new
    result["callsign"] = (@callsign ? @callsign : "UNKNOWN")
    result["files"] = [ { "name" => @filename, "id" => @id }, ]
    result["MaxQSO"] = @maxqso
    result["ParseableQSO"] = @validqso
    result["opclass"] = calcOpClass
    result["badcallsigns"] = @badcallsigns.keys.sort
    result["opmsg"] = calcOpMessage
    if @power
      result["power"] = powerStr
    end
    result["categories"] = @categories.keys.sort
    if @email
      result["email"] = @email
    end
    result["SentQTH"] = filterQTH
    result["warnings"] = @warnings.map { |w| w.to_hash }
    result["errors"] = @errors.map { |w| w.to_hash }
    result["multipliers"] = { "errors" => @badmultipliers.keys.sort.map { |m| m },
      "warnings" => @warnmultipliers.keys.sort.map { |m| { "log" => m, 
          "real" => @warnmultipliers[m] } } }
    result
  end
end

class LineChecker
  CALLSIGNREGEX=/([a-z0-9]{1,4}\/)?(\d?[a-z]+\d*\d[a-z]+)(\/[a-z0-9]{1,4})?/i
  EOLREGEX=/\r\n?|\n\r?/
  TAGREGEX=/\A([a-z]+(-[a-z]+)*):/i
  LOOSETAGREGEX=/\A([a-z]+([- ][a-z]+)*):/i

  def initialize
    @checkobj = nil
  end

  attr_writer :checkobj

  def extractTag(line)
    if m = TAGREGEX.match(line)
      return m[1].upcase
    end
    nil
  end

  def advanceCount(startLineNum, line)
    startLineNum + 1 + line.scan(EOLREGEX).size
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
      limit = [line.length, eol].min
    else
      limit = line.length
    end
    " '" + line[0, limit] + "'"
  end

  def eolCheck(subline, log, startLineNum)
    if EOLREGEX.match(subline)
      log.warnings << LineIssue.new(startLineNum, "Unexpected end-of-line in tag (usually caused by line wrap)", false)
    end
  end

  def checkTheRest(line, startIndex, log, startLineNum)
    rest = line[startIndex..-1]
    # skip leading space (blank lines are okay)
    if m = /\A\s+/.match(rest)
      startIndex = startIndex + m.end(0)
      rest = line[startIndex..-1]
    end
    if rest.length > 0
      @checkobj.checkStr(rest, startLineNum + line[0..(startIndex-1)].scan(EOLREGEX).size, log)
    end
    advanceCount(startLineNum, line)
  end

  def syntaxCheck(line, log, startLineNum)
    if m = LOOSETAGREGEX.match(line)
      log.errors << LineIssue.new(startLineNum, "Unknown tag '" + m[1] + "' in line: " + sample(line), true)
    else
      log.errors << LineIssue.new(startLineNum, "Line doesn't start with tag:" + sample(line) , true )
    end
    if m = EOLREGEX.match(line)
      checkTheRest(line, m.end(0), log, startLineNum)
    else
      advanceCount(startLineNum, line)
    end
  end

  def inexactCheck(line, log, startLineNum)
    syntaxCheck(line, log, startLineNum)
  end

  def stateTransition(log, linenum)
    nil
  end
end

class StandardNearMiss < LineChecker
  def initialize
    super
    @name = ""
    @tagregex = /\|{999}/       # intended to never match
    @strictregex = @tagregex
    @error = true
  end

  def inexactMatch?(line)
    tag = extractTag(line)
    tag and (Levenshtein.normalized_distance(tag, @name) < 0.3)
  end

  def inexactCheck(line, log, startLineNum)
    log.errors << LineIssue.new(startLineNum, "Unknown tag '#{extractTag(line)}' close to '#{@name}'", true)
    if m = EOLREGEX.match(line)
      checkTheRest(line, m.end(0), log, startLineNum)
    else
      advanceCount(startLineNum, line)
    end
  end

  def matchesLine?(line)
    @tagregex.match(line)
  end

  def tagMatch(match, log, linenum)
    nil
  end

  def resumeLocation(line, eolInd, matchEnd)
    if eolInd
      subline = line[eolInd..-1]
      if subline.start_with?("\r\n") or subline.start_with?("\n\r")
        eolInd = eolInd + 2
      elsif subline.start_with?("\n") or subline.start_with?("\r")
        eolInd = eolInd + 1
      end
      [eolInd, matchEnd].max
    else
      matchEnd
    end
  end

  def endOfLineIndex(line)
    ind = line.index(EOLREGEX)
    if not ind
      ind = line.length
    end
    ind
  end

  def properSyntax
    ""
  end

  def syntaxCheck(line, log, startLineNum)
    if m = @strictregex.match(line)
      eolIndex = endOfLineIndex(line)
      if eolIndex and (m.end(0) < eolIndex) # regular expression matched less than a lines worth
        if @error
          log.errors << LineIssue.new(startLineNum, "Incorrect #{@name} line expected " + properSyntax, @error)
        else
          log.warnings << LineIssue.new(startLineNum, "Incorrect #{@name} line expected " + properSyntax, @error)
        end
      else
        tagMatch(m, log, startLineNum)
        eolCheck(line[0,m.end(0)], log, startLineNum)
      end
      resumeChkIndex = resumeLocation(line, eolIndex, m.end(0))
      if resumeChkIndex < line.length
        return checkTheRest(line, resumeChkIndex, log, startLineNum)
      end
    else
      if @error
        log.errors << LineIssue.new(startLineNum, "Incorrect #{@name} line expected " + properSyntax, @error)
      else
        log.warnings << LineIssue.new(startLineNum, "Incorrect #{@name} line expected " + properSyntax, @error)
      end
      if m = EOLREGEX.match(line)
        return checkTheRest(line, m.end(0), log, startLineNum)
      end
    end
    advanceCount(startLineNum, line)
  end

end

class StartLogTag < StandardNearMiss
  TAG="START-OF-LOG"
  TAGREGEX=/\Astart-of-log:/i
  WHOLETAG=/\Astart-of-log:\s*([23].0)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def properSyntax
    "START-OF-LOG: (2.0|3.0)"
  end

  def tagMatch(match, log, linenum)
    log.version = match[1]
  end

  def stateTransition(log, linenum)
    if log.state == 0
      log.state = 1
    else
      log.errors << LineIssue.new(linenum, @name + " tag " + log.stateName, true)
    end
  end
end


class EndLogTag < StandardNearMiss
  TAG="END-OF-LOG"
  TAGREGEX=/\Aend-of-log:/i
  WHOLETAG=/\Aend-of-log:\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def properSyntax
    "END-OF-LOG:"
  end

  def stateTransition(log, linenum)
    if log.state == 1 or log.state == 2
      log.state = 3
    else
      log.errors << LineIssue.new(linenum, @name + " tag " + log.stateName, true)
    end
  end
end

class HeaderTag < StandardNearMiss

  def stateTransition(log, linenum)
    if log.state != 1
      log.errors << LineIssue.new(linenum, @name + " tag " + log.stateName, true)
    end
  end
end

class CallsignTag < HeaderTag
  TAG="CALLSIGN"
  TAGREGEX=/\Acallsign:/i
  WHOLETAG=/\Acallsign:\s*([a-z0-9]+(\/[a-z0-9]+(\/[a-z0-9])?)?)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def properSyntax
    "CALLSIGN: callsign"
  end

  def tagMatch(match, log, linenum)
    log.callsign = match[1].upcase
  end

end

class CatAssistedTag < HeaderTag
  TAG="CATEGORY-ASSISTED"
  TAGREGEX=/\Acategory-assisted:/i
  WHOLETAG=/\Acategory-assisted:\s*((non-|un)?assisted)\s*/i

  def properSyntax
    "CATEGORY-ASSISTED: (ASSISTED|NON-ASSISTED)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def tagMatch(match, log, linenum)
    log.assisted = (match[1].upcase == "ASSISTED")
    if match[1].upcase == "UNASSISTED"
      log.warnings << LineIssue.new(linenum, TAG + ": " + match[1] + " is nonstandard", false)
    end
  end
end

class CatBandTag < HeaderTag
  TAG="CATEGORY-BAND"
  TAGREGEX=/\Acategory-band:/i
  WHOLETAG=/\Acategory-band:\s*(all|(160|80|40|20|15|10|6|2)m|222|432|902|(1\.2|2\.3|3\.4|5\.7|10|24|47|75|119|142|241)g|light)\s*/i

  def properSyntax
    "CATEGORY-BAND: (ALL|160M|80M|40M|20M|15M|10M|6M|2M|222|432|902|1.2G|2.3G|3.4G|5.7G|10G|24G|47G|75G|119G|142G|241G|Light)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def tagMatch(match, log, linenum)
    log.band = match[1].upcase
  end
end

class CatDXPTag < HeaderTag
  TAG="CATEGORY-DXPEDITION"
  TAGREGEX=/\Acategory-dxpedition:/i
  WHOLETAG=/\Acategory-dxpedition:\s*(.*)\s*/i

  def properSyntax
    "CATEGORY-DXPEDITION: [dxpedition-status]"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class CatModeTag < HeaderTag
  TAG="CATEGORY-MODE"
  TAGREGEX=/\Acategory-mode:/i
  WHOLETAG=/\Acategory-mode:\s*(ssb|cw|rtty|mixed)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex  = WHOLETAG
    @error = false
  end

  def tagMatch(match, log, linenum)
    log.mode = match[1].upcase
  end
end

class CatOperatorTag < HeaderTag
  TAG="CATEGORY-OPERATOR"
  TAGREGEX=/\Acategory-operator:/i
  WHOLETAG=/\Acategory-operator:\s*((single|multi)-op|checklog)\s*/i

  def properSyntax
    "CATEGORY-OPERATOR: (SINGLE-OP|MULTI-OP|CHECKLOG)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def tagMatch(match, log, linenum)
    case match[1].upcase
    when "SINGLE-OP"
      log.numops = :single
    when "MULTI-OP"
      log.numops = :multi
    else
      log.numops = :checklog
    end
    if log.numOpsInconsistent?
      log.warnings << LineIssue.new(linenum, TAG + " and CATEGORY-OPERATOR tag are inconsistent", false)
    end
  end
end

class CatPowerTag < HeaderTag
  TAG="CATEGORY-POWER"
  TAGREGEX=/\Acategory-power:/i
  WHOLETAG=/\Acategory-power:\s*(high|low|qrp)\s*/i

  def properSyntax
    "CATEGORY-POWER: (HIGH|LOW|QRP)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def tagMatch(match, log, linenum)
    case match[1].upcase
    when "HIGH"
      log.power = :high
    when "LOW"
      log.power = :low
    when "QRP"
      log.power = :QRP
    end
  end

end


class CatStationTag < HeaderTag
  TAG="CATEGORY-STATION"
  TAGREGEX=/\Acategory-station:/i
  WHOLETAG=/\Acategory-station:\s*(fixed|mobile|portable|rover|expedition|hq|school|county(\s+|-)expedition)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def properSyntax
    "CATEGORY-STATION: (FIXED|MOBILE|PORTABLE|ROVER|EXPEDITION|HQ|SCHOOL|COUNTY EXPEDITION)"
  end

  def tagMatch(match, log, linenum)
    case match[1].upcase
    when "MOBILE", "ROVER"
      log.categories["mobile"] = 1
    when "EXPEDITION", /COUNTY(\s+|-)EXPEDITION/
      log.categories["expedition"] = 1
    when "SCHOOL"
      log.categories["school"] = 1
    end
  end
end

class CatTimeTag < HeaderTag
  TAG="CATEGORY-TIME"
  TAGREGEX=/\Acategory-time:/i
  WHOLETAG=/\Acategory-time:\s*((6|12|24)-hours?)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class CategoryTag < HeaderTag
  TAG="CATEGORY"
  TAGREGEX=/\Acategory:/i
  WHOLETAG=/\Acategory:\s+([-a-z0-9]+(\s+[-a-z0-9]+)*)\s*/i

  def properSyntax
    "CATEGORY: <see Cabrillo 2 spec>"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def tagMatch(match, log, linenum)
    if match[1]
      match[1].split.each { |cat|
        case cat.upcase
        when 'SINGLE-OP'
          log.numops = :single
          if log.assisted == nil
            log.assisted = false
          end
        when 'SINGLE-OP-ASSISTED'
          log.numops = :single
          log.assisted= true
        when 'LOW'
          log.power = :low
        when 'HIGH'
          log.power = :high
        when 'QRP'
          log.power = :QRP
        when 'MIXED', 'SSB', 'CW', 'RTTY'
          log.mode = cat.upcase
        when 'MULTI-ONE'
          log.numops = :multi
          log.numtrans = :one
        when 'MULTI-TWO'
          log.numops = :multi
          log.numtrans = :two
        when 'MULTI-MULTI'
          log.numops = :multi
          log.numtrans = :unlimited
        when 'CHECKLOG'
          log.numops = :checklog
        when 'ALL', /^\d+M$/, 'LIMITED'
          log.band = cat.upcase
        when 'CCE', 'COUNTY', 'EXPEDITION'
          log.categories["expedition"] = 1
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when /^SO-?HP$/
          log.numops = :single
          log.power = :high
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when /^SO-?LP$/
          log.numops = :single
          log.power = :low
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when /^SO-?QRP$/
          log.numops = :single
          log.power = :QRP
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when 'MM-HP'
          log.numops = :multi
          log.numtrans = :unlimited
          log.power = :high
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when 'MM-LP'
          log.numops = :multi
          log.numtrans = :unlimited
          log.power = :low
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when 'MM-QRP'
          log.numops = :multi
          log.numtrans = :unlimited
          log.power = :QRP
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when 'MOBILE'
          log.categories['mobile'] = 1
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        when 'SINGLE-OP-UNASSISTED'
          log.numops = :single
          log.assisted= false
          log.warnings << LineIssue.new(linenum, cat + " is a non-standard CATEGORY", false)
        else
          log.warnings << LineIssue.new(linenum, "Ignoring non-standard CATEGORY " + cat, false)
        end
      }
    end
  end
end


class CatTransmitterTag < HeaderTag
  TAG="CATEGORY-TRANSMITTER"
  TAGREGEX=/\Acategory-transmitter:/i
  WHOLETAG=/\Acategory-transmitter:\s*(one|two|limited|unlimited|swl)\s*/i

  def properSyntax
    "CATEGORY-TRANSMITTER: (ONE|TWO|LIMITED|UNLIMITED|SWL)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end

  def tagMatch(match, log, linenum)
    log.numtrans = match[1].downcase.to_sym
  end

end

class CatOverlayTag < HeaderTag
  TAG="CATEGORY-OVERLAY"
  TAGREGEX=/\Acategory-overlay:/i
  WHOLETAG=/\Acategory-overlay:\s*(classic|rookie|tb-wires|novice-tech|over-50|county-expedition)?\s*/i

  def properSyntax
    "CATEGORY-OVERLAY: (CLASSIC|ROOKIE|TB-WIRES|NOVICE-TECH|OVER-50|COUNTY-EXPEDITION)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def tagMatch(match, log, linenum)
    if match[1] and match[1].upcase == "COUNTY-EXPEDITION"
      log.categories["expedition"] = 1
    end
  end

end

class CertificateTag < HeaderTag
  TAG="CERTIFICATE"
  TAGREGEX=/\Acertificate:/i
  WHOLETAG=/\Acertificate:\s*(yes|no)\s*/i

  def properSyntax
    "CERTIFICATE: (YES|NO)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class ClaimedScoreTag < HeaderTag
  TAG="CLAIMED-SCORE"
  TAGREGEX=/\Aclaimed-score:/i
  WHOLETAG=/\Aclaimed-score:\s*(\d+)\s*/i

  def properSyntax
    "CLAIMED-SCORE: <integer>"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class ARRLSectionTag < HeaderTag
  TAG="ARRL-SECTION"
  TAGREGEX=/\Aarrl-section:/i
  WHOLETAG=/\Aarrl-section:\s*([a-z]+(\s+[a-z]+)*)?\s*/i

  def properSyntax
    "ARRL-SECTION: arrl-section-abbreviation"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end


class ClubTag < HeaderTag
  TAG="CLUB"
  TAGREGEX=/\Aclub(-name)?:/i
  WHOLETAG=/\Aclub(-name)?:\s*(([a-z0-9][a-z0-9\/\.]*(\s+(&|[a-z0-9][a-z0-9\/\.]*))*))?\s*/i

  def properSyntax
    "CLUB: club-name"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class IOTATag < HeaderTag
  TAG="IOTA-ISLAND-NAME"
  TAGREGEX=/\Aiota-island-name:/i
  WHOLETAG=/\Aiota-island-name:\s*(([a-z0-9][a-z0-9\/\.]*(\s+(&|[a-z0-9][a-z0-9\/\.]*))*))?\s*/i

  def properSyntax
    "IOTA-ISLAND-NAME: text"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class ContestTag < HeaderTag
  TAG="CONTEST"
  TAGREGEX=/\Acontest:/i
  WHOLETAG=/\Acontest:\s*(ca-qso-party|cqp|nccc-cqp|california\s+qso\s+party)\s*/i

  def properSyntax
    "CONTEST: (CA-QSO-PARTY|CQP|NCCC-CQP|CALIFORNIA QSO PARTY)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class CreatedByTag < HeaderTag
  TAG="CREATED-BY"
  TAGREGEX=/\Acreated-by:/i
  WHOLETAG=/\Acreated-by:\s*(.+)\s*/i

  def properSyntax
    "CREATED-BY: name of software"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class XCQPTag < HeaderTag
  TAG="X-CQP-TAG"
  TAGREGEX=/\Ax-cqp-(confirm1|email|special-\d+|comments|phone):/i
  WHOLETAG=/\Ax-cqp-(confirm1|email|special-\d+|comments|phone):\s*(.+)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

   def properSyntax
     "X-CQP-TAG: text"
   end
end

class EmailTag < HeaderTag
  TAG="EMAIL"
  TAGREGEX=/\Aemail:/i
  WHOLETAG=/\Aemail:\s*((([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Z‌​a-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6})\s*/i

  def properSyntax
    "EMAIL: valid-email-address"
  end

  def tagMatch(match, log, linenum)
    log.email = match[1]
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class LocationTag < HeaderTag
  TAG="LOCATION"
  TAGREGEX=/\Alocation:/i
  WHOLETAG=/\Alocation:\s*([a-z]+(\s+[a-z]+)*)\s*/i

  def properSyntax
    "LOCATION: state-province-or-CA-county-abbreviation"
  end

  def tagMatch(match, log, linenum)
    if match[1].length > 0
#      log.sentqth[match[1]] = 1
    end
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class NameTag < HeaderTag
  TAG="NAME"
  TAGREGEX=/\Aname:/i
  WHOLETAG=/\Aname:\s*([a-z0-9][a-z0-9\/\.]*(((\s*,\s*|\s+)(&|[a-z0-9][a-z0-9\/\.]*))*))\s*/i

  def properSyntax
    "NAME: text"
  end

  def tagMatch(match, log, linenum)
    log.name = match[1]
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class AddressTag < HeaderTag
  TAG="ADDRESS"
  TAGREGEX=/\Aaddress:/i
  ADDRWITHEMAIL=/\Aaddress:\s*\(e-mail\)\s*((([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Z‌​a-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6})\s*/i
  WHOLETAG=/\Aaddress:\s*(.+)\s*/i

  def properSyntax
    "ADDRESS: text"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end

  def tagMatch(match, log, linenum)
    str = match[0]
    if m = ADDRWITHEMAIL.match(str)
      log.email = m[1]
    end
  end
end

class AddressCityTag < HeaderTag
  TAG="ADDRESS-CITY"
  TAGREGEX=/\Aaddress-city:/i
  WHOLETAG=/\Aaddress-city:\s*(.+)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class AddressStateTag < HeaderTag
  TAG="ADDRESS-STATE-PROVINCE"
  TAGREGEX=/\Aaddress-state-province:/i
  WHOLETAG=/\Aaddress-state-province:\s*(.+)\s*/i

  def properSyntax
    "ADDRESS-STATE-PROVINCE: text"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class AddressPostcodeTag < HeaderTag
  TAG="ADDRESS-POSTALCODE"
  TAGREGEX=/\Aaddress-postalcode:/i
  WHOLETAG=/\Aaddress-postalcode:\s*(.+)\s*/i

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class AddressCountryTag < HeaderTag
  TAG="ADDRESS-COUNTRY"
  TAGREGEX=/\Aaddress-country:/i
  WHOLETAG=/\Aaddress-country:\s*(.+)\s*/i

  def properSyntax
    TAG + ": text"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class OperatorsTag < HeaderTag
  TAG="OPERATORS"
  TAGREGEX=/\Aoperators:/i
  WHOLETAG=/\Aoperators:\s*(@?([a-z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[a-z0-9]{1,4})?((\s*,\s*|\s+)@?([a-z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[a-z0-9]{1,4})?)*)?\s*/i

  def properSyntax
    TAG + ": space-seperated-list-of-callsigns"
  end

  def tagMatch(match, log, linenum)
    if match[1] and (match[1].length > 0)
      match[1].split(/\s+|\s*,\*/).each { |call|
        log.operators[call.upcase] = 1
      }
      if log.numOpsInconsistent?
        log.warnings << LineIssue.new(linenum, TAG + " and CATEGORY-OPERATOR tag are inconsistent", false)
      end
    end
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = true
  end
end

class OfftimeTag < HeaderTag
  TAG="OFFTIME"
  TAGREGEX=/\Aofftime:/i
  WHOLETAG=/\Aofftime:(\s+\d{4}-\d{2}-\d{2}\s+\d{4}){2}\s*/i

  def properSyntax
    TAG + ": yyyy-mm-dd hhmm yyyy-mm-dd hhmm (begin and end time)"
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class SoapboxTag < HeaderTag
  TAG="SOAPBOX"
  TAGREGEX=/\Asoapbox:/i
  WHOLETAG=/\Asoapbox:\s*(.*)\s*/im

  def properSyntax
    TAG + ": text"
  end

  def tagMatch(match, log, linenum)
    if not log.comments
      log.comments = match[1]
    else
      log.comments << (" " + match[1])
    end
  end

  def initialize
    super
    @name = TAG
    @tagregex = TAGREGEX
    @strictregex = WHOLETAG
    @error = false
  end
end

class QSOTag < StandardNearMiss
  TAG="QSO"
  TAGREGEX=/\Aqso:/i
  QSO_ONE=/\Aqso:\s+(\d+)\s+([a-z]+)\s+(\d+-\d+-\d+)\s+(\d+)\s+([a-z0-9]+(\/[a-z0-9]+(\/[a-z0-9])?)?)\s+(\d+)\s+([a-z]+)\s+([a-z0-9]+(\/[a-z0-9]+(\/[a-z0-9])?)?)\s+(\d+)\s+([a-z]+)(\s+(\d+)\s*|\s*)$/i
  QSO_TWO=/\Aqso:\s+(\d+)\s+([a-z]+)\s+(\d+-\d+-\d+)\s+(\d+)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)(\s+(\d+)|\s*)$/i
  QSO_GRP_ONE =  [ QSO_ONE, QSO_TWO ]

  # QSO_THREE is like QSO_TWO but with a recvd signal report
  QSO_THREE=/\Aqso:\s+(\d+)\s+([a-z]+)\s+(\d+-\d+-\d+)\s+(\d+)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+59{1,2}\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)(\s+(\d+\s*)|\s*)$/i
  # QSO_FOUR is like QSO_THREE but with a sent and recvd signal report
  QSO_FOUR=/\Aqso:\s+(\d+)\s+([a-z]+)\s+(\d+-\d+-\d+)\s+(\d+)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+59{1,2}\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)\s+(([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?)\s+59{1,2}\s+(\d+)\s+([a-z]+(\s+[a-z]+)*)(\s+(\d+)\s*|\s*)$/i
  QSO_GRP_TWO = [ QSO_THREE, QSO_FOUR ]

  def initialize
    super
    @name = TAG
    @tagregex= TAGREGEX
    @error = true
    @multipliers = nil
  end

  def properSyntax
    TAG + ": see robot.cqp.org/cqp/qso_syntax.html"
  end

  attr_writer :multipliers

  def checkFreqMode(log, lineNum, freq, mode)
    true
  end

  def checkDateTime(log, lineNum, date, time)
    begin
      t = Time.strptime(date + " " + time + " UTC", "%Y-%m-%d %H%M %Z")
    rescue ArgumentError => e
      log.errors << LineIssue.new(lineNum, "QSO has illegal date/time '" + date + " " + time + "'", true)
      return false
    end
    if t
      $CONTESTS.each { |c|
        if c.inContest?(t)
          return true
        end
      }
      log.errors << LineIssue.new(lineNum, "QSO occurs outside contest time '" + date + " " + time + "'", true)
    else
      log.errors << LineIssue.new(lineNum, "QSO has illegal date/time '" + date + " " + time + "'", true)
    end
    false
  end

  def callCheck(log, call)
    if not CALLSIGNREGEX.match(call)
      log.badcallsigns[call.upcase] = 1
      return false
    end
    true
  end

  def multiplierCheck(log, mult)
    mult = mult.upcase
    if @multipliers.has_key?(mult)
      if @multipliers[mult] != mult
        log.warnmultipliers[mult] = @multipliers[mult]
      end
    else
      log.badmultipliers[mult] = ""
      return false
    end
    true
  end

  def checkQSO(line, log, lineNum,
               freq, mode, date, time,
               sentcall, sentnum, sentqth,
               recvdcall, recvdnum, recvdqth,
               transnum)
    if sentcall and (not log.callsign) and sentcall.length > 0 
      log.callsign = sentcall.upcase
    end
      
    valid = true
    valid = valid and checkFreqMode(log, lineNum, freq, mode)
    valid = valid and checkDateTime(log, lineNum, date, time)
    log.sentqth[sentqth.upcase] = 1
    valid = valid and callCheck(log, sentcall)
    if callCheck(log, recvdcall)
      if log.tally
        ru = recvdcall.upcase
        log.tally[ru] = log.tally[ru] + 1
      end
    else
      valid = false
    end
    valid = valid and multiplierCheck(log, sentqth)
    valid = valid and multiplierCheck(log, recvdqth)

    if valid
      log.validqso = log.validqso + 1
    else
      log.errors << LineIssue.new(lineNum, "QSO line contains some invalid data: " + sample(line), true)
    end
  end

  # callsign ([A-Z0-9]{1,4}\/)?(\d?[A-Z]+\d*\d[A-Z]+)(\/[A-Z0-9]{1,4})?
  def syntaxCheck(line, log, startLineNum)
    m = QSO_ONE.match(line)
    if m
      checkQSO(line, log, startLineNum, m[1], m[2], m[3], m[4], m[5], m[8], m[9], m[10], m[13], m[14], m[16])
      eolCheck(line[0,m.end(0)], log, startLineNum)
      if m.end(0) < line.length
        return checkTheRest(line, m.end(0), log, startLineNum)
      end
      return advanceCount(startLineNum, line)
    end
    m = QSO_TWO.match(line)
    if m
      checkQSO(line, log, startLineNum, m[1], m[2], m[3], m[4], m[5], m[9], m[10], m[12], m[16], m[17], m[20])
      eolCheck(line[0,m.end(0)], log, startLineNum)
      if m.end(0) < line.length
        return checkTheRest(line, m.end(0), log, startLineNum)
      end
      return advanceCount(startLineNum, line)
    end
    QSO_GRP_TWO.each { |regex|
      m = regex.match(line)
      if m
        log.warnings << LineIssue.new(startLineNum, "QSO contains signal report that isn't required", false)
        checkQSO(line, log, startLineNum, m[1], m[2], m[3], m[4], m[5], m[9], m[10], m[12], m[16], m[17], m[20])
        eolCheck(line[0,m.end(0)], log, startLineNum)
        if m.end(0) < line.length
          return checkTheRest(line, m.end(0), log, startLineNum)
        end
        return advanceCount(startLineNum, line)
      end
    }
    log.errors << LineIssue.new(startLineNum, "Incorrect #{TAG} line: " + sample(line), @error)
    if m = EOLREGEX.match(line)
      return checkTheRest(line, m.end(0), log, startLineNum)
    end
    advanceCount(startLineNum, line)
  end

  def stateTransition(log, linenum)
    if log.state == 1
      log.state = 2
    else
      log.errors << LineIssue.new(linenum, @name + " tag " + log.stateName, true)
    end
  end
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

END_OF_RECORD = /(\r\n?|\n\r?)(?=([a-z]+(-([a-z]+\d*|\d+))*:)|([ \t]*\Z))/i

def splitLines(str)
  lines = mySplit(str, END_OF_RECORD)
  lines.each { |line|
    print "LINE=" + line.strip + "\n"
  }
  nil
end

class CheckLog
  CHECKERS = %w( QSOTag StartLogTag EndLogTag CallsignTag CatAssistedTag CatBandTag CatDXPTag CatModeTag 
                 CatOperatorTag CatPowerTag CatStationTag CatTimeTag CatTransmitterTag CatOverlayTag
                 CertificateTag ClaimedScoreTag ClubTag ARRLSectionTag ContestTag CreatedByTag XCQPTag
                 EmailTag LocationTag NameTag AddressTag AddressCityTag AddressStateTag AddressPostcodeTag
                 AddressCountryTag OperatorsTag OfftimeTag CategoryTag SoapboxTag IOTATag LineChecker )
  def initialize
    @checkers = [ ]
    @multipliers = readMultAliases(File.dirname(__FILE__) + "/multipliers.csv")
    @multregex = makeMultRegex
    CHECKERS.each { |c|
      chkClass = Object.const_get(c)
      chk = chkClass.new
      chk.checkobj = self
      if chk.respond_to?(:multipliers=)
        chk.multipliers = @multipliers
      end
      @checkers << chk
    }
  end

  def readMultAliases(filename)
    result = Hash.new
    open(filename, "r:ascii") { |io|
      io.each_line { |line|
        if line =~ /^"([^"]*)","([^"]*)"/
          result[$1] = $2
        end
      }
    }
    result
  end

  def makeMultRegex
    vals = @multipliers.values.sort.uniq
    return Regexp.new('\b(' + vals.join("|") + ')\b', Regexp::IGNORECASE)
  end

  def checkLog(filename, id)
    log = nil
    open(filename, "r:ascii") { |io|
      content = io.read()
      content = content.encode("ASCII", {:invalid => :replace, :undef => :replace})
      log = checkLogStr(filename, id, content)
    }
    log
  end

  def checkLogStr(filename, id, content)
    log = CQPLog.new(id, filename, @multregex, @multipliers)
    lineNum = 1
    lines = mySplit(content, END_OF_RECORD)
    log.maxqso = content.scan(/\bqso:\s+/i).size # upper bound on number of QSOs
    lines.each { |line|
      lineNum = checkStr(line, lineNum, log)
    }
    log
  end

  def checkStr(str, lineNum, log)
    @checkers.each { |chk|
      if chk.matchesLine?(str)
        return chk.syntaxCheck(str, log, lineNum)
      end
    }
    @checkers.each { |chk|
      if chk.inexactMatch?(str)
        return chk.inexactCheck(str, log, lineNum)
      end
    }
    print "No Matches\n"
    lineNum + 1
  end
end

def logProperties(id, str)
  log = CQPLog.new(id, "")
  log.maxqso = str.scan(/\bqso:\s+/i).size # maximum number of QSO lines

end

