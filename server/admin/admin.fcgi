#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP admin script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'fcgi'
require 'csv'
require 'set'
require_relative '../database'

MISSING_THRESHOLD=50

HTML_HEADER=<<HEADER_END
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<HTML>
  <HEAD>
    <LINK href="/cqp/favicon.ico" rel="icon" sizes="16x16 32x32 40x40 64x64 128x128" type="image/vnd.microsoft.icon">
    <TITLE>CQP Log Manager Report</TITLE>
    <META http-equiv="Content-Type" content="text/html; charset=UTF-8">
  </HEAD>
  <BODY>
      <DIV><IMG SRC="/cqp/images/cqplogo80075.jpg", alt="California QSO Party"></DIV>
      <P>Data as of: %{timestamp}<br>
         <a href="../received.fcgi">Received Logs</a><br>
         <a href="/cqp/logsubmit-form.html">Submission Page</a><br>
         <a href="qsograph.fcgi">QSO Graph</a>
      </P>
      <TABLE %{tablestyle}>
      <CAPTION %{capstyle}>CQP %{year} Incoming Logs Summary</CAPTION>
      <TR>
         <TH %{rightodd}>Complete Logs Received:</TH>
         <TD %{dataodd}>%{totallogs}</TD>
      </TR>
      <TR>
         <TH %{righteven}>Incomplete Logs:</TH>
         <TD %{dataeven}>%{incompletelogs}</TD>
      </TR>
      <TR>
         <TH %{rightodd}>First log received:</TH>
         <TD %{dataodd}>%{firstlog}</TD>
      </TR>
      <TR>
         <TH %{righteven}>Last log received:</TH>
         <TD %{dataeven}>%{lastlog}</TD>
      </TR>
      <TR>
         <TH %{rightodd}>Number Exceptions:</TH>
         <TD %{dataodd}>%{numexcept}</TD>
      </TR>
      <TR>
         <TH %{righteven}>Last Exception:</TH>
         <TD %{dataeven}>%{lastexcept}</TD>
      </TR>
    </TABLE>

    <TABLE %{tablestyle}>
      <CAPTION %{capstyle}>Special Categories</CAPTION>
      <TR>
         <TH %{rightodd}>CA County Expeditions:</TH>
         <TD %{dataodd}>%{county}</TD>
      </TR>
      <TR>
         <TH %{righteven}>Mobile Entries:</TH>
         <TD %{dataeven}>%{mobile}</TD>
      </TR>
      <TR>
         <TH %{rightodd}>New Contesters:</TH>
         <TD %{dataodd}>%{newcontester}</TD>
      </TR>
      <TR>
         <TH %{righteven}>School:</TH>
         <TD %{dataeven}>%{school}</TD>
      </TR>
      <TR>
         <TH %{rightodd}>YL:</TH>
         <TD %{dataodd}>%{female}</TD>
      </TR>
      <TR>
         <TH %{righteven}>Youth:</TH>
         <TD %{dataeven}>%{youth}</TD>
      </TR>
    </TABLE>
      

    <TABLE %{tablestyle}>
      <CAPTION %{capstyle}>Incomplete Logs</CAPTION>
      <TR><TH %{headeven}>Callsign</TH><TH %{headeven}>Upload date</TH></TR>
HEADER_END

MIDDLE=<<MIDDLE_END
    </TABLE>
    <p>An incomplete log is one where the entrant did step 1 (on the web form) but did
       not complete step 3. It lacks confirmation of the operator class, power, etc.</p>

    <TABLE %{tabletwostyle}>
      <CAPTION %{capstyle}>%{nummissing} Potential Missing Logs</CAPTION>
      <TR><TH %{headeven}>Callsign</TH><TH %{headeven}># QSO Refs</TH></TR>
MIDDLE_END

HTML_TRAILER = <<TRAILER_END
    </TABLE>

     <h1>Entries by Power Level</h1>
     <img src="piechart.fcgi?type=power" height="450" width="500">
     <h1>Entries by Operator Class</h1>
     <img src="piechart.fcgi?type=opclass" height="450" width="500"> 
     <h1>Entries by Submission Approach</h1>
     <img src="piechart.fcgi?type=source" height="450" width="500">
  </BODY>
</HTML> 
TRAILER_END


def rootCall(call)
  # adapted from WX5S's CQP_RootCall.pm
  call = call.upcase.gsub(/\s+/,"") # remove space and convert to upper case
  parts = call.split("/")
  if parts.length <= 1
    return call
  else
    if parts[0] =~ /\d\z/
      return parts[1]
    else
      if (parts[0] =~ /\d/) or (parts[1] =~ /\d$/)
        return parts[1]
      else
        return parts[0]
      end
    end
  end
end

def charClasses(str)
  classes = Hash.new
  if str =~ /[A-Z]/
    classes[:alpha] = true
  end
  if str =~ /\d/
    classes[:digit] = true
  end
  classes
end

def compareCallParts(x, y)
  if x == y
    0
  else
    xc = charClasses(x)
    yc = charClasses(y)
    cmp = (xc.size <=> yc.size)
    if cmp != 0
      cmp
    else
      if xc.length == 2         # both have numbers and letters
        if x =~ /\d\z/ and y !~ /\d\z/
          -1
        elsif x !~ /d\z/ and y =~ /\d\z/
          1
        else
          return x.length <=> y.length
        end
      elsif xc.length == 1
        if xc.has_key?(:alpha) and yc.has_key?(:digit)
          1
        elsif xc.has_key?(:digit) and yc.has_key?(:alpha)
          -1
        else
          return x.length <=> y.length
        end
      else                      # neither has alpha or digits
        return x.length <=> y.length
      end
    end
  end
end

def callBase(str)
  str = str.upcase.encode("US-ASCII")
  str.gsub!(/\s+/,"")
  parts = str.split("/")
  case parts.length
  when 0
    str
  when 1
    parts[0]
  when 2
    if parts[0] =~ /\d\z/ or (parts[0] !~ /\d/ and parts[1] !~ /\A\d\z/)
      parts[1]
    else 
      parts[0]
    end
  else                          # more than 3 who knows
    parts.sort! { |x,y|
      compareCallParts(x,y)
    }
    parts[-1]
  end
end

def scanQSOs(filename, aliases, potLogs)
  sentlocs = Hash.new(0)
  open(filename, "r:ascii") { |login|
    content = login.read
    content.scan(/^QSO:\s+\d+\s+\w+\s+\d+-\d+-\d+\s+\d+\s+\S+\s+\d+\s+(\w+)\s+([a-z0-9\/]+)\s+\d+\s+(\w+)/i) { |qso|
      sentloc = qso[0].upcase.strip
      if aliases.has_key?(sentloc)
        sentlocs[aliases[sentloc]] = sentlocs[aliases[sentloc]] + 1
      end
      callsign = callBase(qso[1].upcase.strip)
      location = qso[2].upcase.strip
      if aliases.has_key?(location)
        potLogs[aliases[location]][callsign] = potLogs[aliases[location]][callsign] + 1
      end
    }
    if not sentlocs.empty?
      loc, count = sentlocs.max_by{|k,v| v}
      return loc
    end
    return nil
  }
end

def bigLogs(logHash, alreadyHave)
  callsigns = logHash.keys.sort { |x,y| logHash[y] <=> logHash[x] }
  callsigns = (callsigns.to_set - alreadyHave).to_a
  callsigns[0..8].reduce("") { |total, callsign|
    if total.length == 0
      comma = ""
    else
      comma = ", " 
    end
    total = total + comma + callsign + "(" + logHash[callsign].to_s + ")"
  }
end

def multiplierTable(db)
  potentialLogs = Hash.new
  aliases = Hash.new
  states = Hash.new
  counties = Hash.new
  CSV.open(File.dirname(__FILE__) + "/../multipliers.csv", "r:ascii") { |io|
    io.each { |line|
      if line[1] != "XXXX"
        aliases[line[0]] = line[1]
        if 2 == line[1].length
          states[line[1]] = Set.new
        elsif 4 == line[1].length
          counties[line[1]] = Set.new
        end
        if not potentialLogs.has_key?(line[1])
          potentialLogs[line[1]] = Hash.new(0)
        end
      end
    }
  }
  ids = db.allEntries
  ids.each { |id|
    allInfo = db.getEntry(id)
    if allInfo and 1 == allInfo["completed"] and allInfo["sentqth"]
      sentq = scanQSOs(allInfo["asciifile"], aliases, potentialLogs)
      if aliases.has_key?(allInfo["sentqth"])
        loc = aliases[allInfo["sentqth"]]
      elsif aliases.has_key?(sentq)
        loc = aliases[sentq]
      else 
        loc= nil
      end
      if loc
        if 4 == loc.length
          counties[loc].add(callBase(allInfo["callsign_confirm"].upcase.strip))
        else
          states[loc].add(callBase(allInfo["callsign_confirm"].upcase.strip))
        end
      end
    end
  }
  count = 0
  return "<table %{tablestyle}>
<caption %{capstyle}>CQP %{year} Completed Logs for Each Multiplier</caption>
<tr>
  <th %{headeven}>Multiplier</th><th %{headeven}># Logs</th><th %{headeven}>Potential logs</th>
</tr>
" + counties.keys.sort.reduce("") { |total, loc|
   count = count + 1
   if count.even?
     total = total + "<tr><td %{dataeven}>" + loc + "</td><td %{dataeven}>" + counties[loc].length.to_s + "</td><td %{dataeven}>"+ bigLogs(potentialLogs[loc], counties[loc]) +"</td></tr>\n"
   else
     total = total + "<tr><td %{dataodd}>" + loc + "</td><td %{dataodd}>" + counties[loc].length.to_s + "</td><td %{dataodd}>"+bigLogs(potentialLogs[loc], counties[loc]) +"</td></tr>"
   end
  } + states.keys.sort.reduce("") { |total, loc|
    count = count + 1
    if count.even?
      total = total + "<tr><td %{dataeven}>" + loc + "</td><td %{dataeven}>" + states[loc].length.to_s + "</td><td %{dataeven}>"+bigLogs(potentialLogs[loc], states[loc]) + "</td></tr>\n"
    else
      total = total + "<tr><td %{dataodd}>" + loc + "</td><td %{dataodd}>" + states[loc].length.to_s + "</td><td %{dataodd}>" + bigLogs(potentialLogs[loc], states[loc]) + "</td></tr>"
    end
  } + "</table>\n\n"
end


def handle_request(request, db)
  timestamp = Time.new.utc
  completedLogs = db.allEntries # array of log IDs for completed logs
  incompleteLogs = db.incompleteEntries # array of log IDs for incomplete logs
  firstLogDate, lastLogDate = db.logDates
  callsigns = Hash.new(false)
  completedLogs.each { |id|
    callsigns[db.getCallsign(id)] = true
  }
  callsWorked = db.workedStats(completedLogs, MISSING_THRESHOLD)
  callsigns.keys.each { |call|
    callsWorked.delete(call)
    callsWorked.delete(rootCall(call))
  }
  callsWorked.keys.each { |call|
    if callsigns.has_key?(rootCall(call))
      callsWorked.delete(call)
    end
  }
  missingCalls = callsWorked.keys
  missingCalls.sort! { |c1, c2|
    -1*(callsWorked[c1] <=> callsWorked[c2])
  }

  attr = Hash.new
  attr[:timestamp] = timestamp.to_s
  attr[:year] = CQPConfig::CONTEST_DEADLINE.strftime("%Y")
  attr[:totallogs] = completedLogs.length
  attr[:incompletelogs] = incompleteLogs.length
  attr[:firstlog] = CGI::escapeHTML(firstLogDate.to_s)
  attr[:lastlog] = CGI::escapeHTML(lastLogDate.to_s)
  attr[:lastexcept] = CGI::escapeHTML(db.latestException.to_s)
  attr[:numexcept]  = db.numExceptions
  categories = %w(county youth mobile female school newcontester)
  categories.each { |cat|
    attr[cat.to_sym] = db.numSpecial(completedLogs, cat)
  }

  attr[:capstyle] = "style=\"text-align: center; font-family: 'Trebuchet MS', Verdana, Sans-serif; font-style: normal; font-weight: bold; font-size: 16px; margin-top: 0;  margin-bottom: 0; padding: 0 0 0 0;\""

  attr[:logErrors] = "style=\"font-family: 'Courier New', 'Lucida Console', monospace; font-style: normal; font-weight: normal; margin: 0 0 0 0 ! important; padding: 0 0 0 0; line-height: 105%; white-space: nowrap;\""
  attr[:logWarnings] = attr[:logErrors]
  attr[:multErrors] = attr[:logErrors]
  attr[:multWarnings] = attr[:logErrors]
  attr[:badcall] = attr[:logErrors]
  attr[:nummissing] = missingCalls.length

  attr[:headingstyle] = "style=\"font-family: 'Trebuchet MS', Verdana, Sans-serif; font-style: normal; font-weight: bold; font-size: 16px; margin-top: 0; margin-bottom: 0; padding: 0 0 0 0;\""


  attr[:tablestyle] = "style=\"margin: 2em 0 2em 0; border-style: solid; border-width: 2px; border-color: black;\""
  attr[:tabletwostyle] = "style=\"margin: 2em 0 2em 0; border-style: solid; border-width: 2px; border-color: black; width: 25%%;\""
  attr[:headeven] = "style=\"font-family: Arial, Verdana, San-serif; text-align: left; background-color: WhiteSmoke;\""
  attr[:headodd] = "style=\"font-family: Arial, Verdana, San-serif; text-align: left; background-color: white;\""
  attr[:righteven] = "style=\"font-family: Arial, Verdana, San-serif; text-align: right; background-color: WhiteSmoke;\""
  attr[:rightodd] = "style=\"font-family: Arial, Verdana, San-serif; text-align: right; background-color: white;\""
  attr[:dataeven] = "style=\"font-family: Arial, Verdana, San-serif; background-color: WhiteSmoke;\""
  attr[:dataodd] = "style=\"font-family: Arial, Verdana, San-serif; background-color: white;\""
  attr[:numeven] = "style=\"font-family: Arial, Verdana, San-serif; background-color: WhiteSmoke; text-align: right;\""
  attr[:numodd] = "style=\"font-family: Arial, Verdana, San-serif; background-color: white; text-align: right;\""

  count = 0
  counttwo = 0
  request.out("text/html") {
    ( HTML_HEADER  +
      incompleteLogs.reduce("") { |total, id|
        call, ldate = db.getIncomplete(id)
        if call.nil?
          call="UNKNOWN (nil)"
        end
        counttwo = counttwo + 1
        if counttwo.even?
          total = total + "      <TR><TD %{dataeven}>" + call.to_s + "</TD><TD %{dataeven}>" + ldate.to_s + "</TR>\n"
        else
          total = total + "      <TR><TD %{dataodd}>" + call.to_s + "</TD><TD %{dataodd}>" + ldate.to_s + "</TR>\n"
        end
      } +
      MIDDLE +
      missingCalls.reduce("") { |total, call|
        count = count + 1
        if count.even?
          total = total + "      <TR><TD %{dataeven}>" + call + "</TD><TD %{numeven}>" + callsWorked[call].to_s + "</TD></TR>\n"
        else
          total = total + "      <TR><TD %{dataodd}>" + call + "</TD><TD %{numodd}>" + callsWorked[call].to_s + "</TD></TR>\n"
        end
        total
      } + "</table>\n" + multiplierTable(db) + 
      HTML_TRAILER) % attr
  }
end
  
begin
  db = LogDatabase.new(true)
rescue => e
  $stderr.write(e.message + "\n")
  $stderr.write(e.backtrace.join("\n"))
  $stderr.flush()
  db.addException(e)
  raise
end

FCGI.each_cgi("html4Tr") { |request|
  begin
    handle_request(request, db)
  rescue => e
    $stderr.write(e.message + "\n")
    $stderr.write(e.backtrace.join("\n"))
    $stderr.flush()
    db.addException(e)
    raise
  end
}
