#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# CQP admin script
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'fcgi'
require_relative '../database'

MISSING_THRESHOLD=75

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
      <CAPTION %{capstyle}>Potential Missing Logs</CAPTION>
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
  }
  missingCalls = callsWorked.keys
  missingCalls.sort! { |c1, c2|
    -1*(callsWorked[c1] <=> callsWorked[c2])
  }

  attr = Hash.new
  attr[:year] = CQPConfig::CONTEST_DEADLINE.strftime("%Y")
  attr[:totallogs] = completedLogs.length
  attr[:incompletelogs] = incompleteLogs.length
  attr[:firstlog] = CGI::escapeHTML(firstLogDate.to_s)
  attr[:lastlog] = CGI::escapeHTML(lastLogDate.to_s)
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
      } +
      HTML_TRAILER) % attr
  }
end
  
begin
  db = LogDatabase.new
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
