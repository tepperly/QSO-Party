#!/usr/local/bin/ruby
# -*- encoding: utf-8 -*-
# CQP log HTML generator
# Tom Epperly NS6T
# ns6t@arrl.net
#
#

require 'cgi'
require_relative 'config'
require_relative 'logscan'
require_relative 'database'

HTML_HEADER=<<HEADER_END
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<HTML>
  <HEAD>
    <TITLE>%{callsign} CQP Log Report</TITLE>
    <META http-equiv="Content-Type" content="text/html; charset=UTF-8">
  </HEAD>
HEADER_END

INSTRUCTIONS=<<INSTRUCTIONS_END
<p>Thank you for submitting your log for the California QSO Party. 
We're tried to provide some feedback on your log in case there are
errors. If the material in the "CQP %{year} Log Details" section is correct,
the number of Readable QSO lines is close to the Total QSO lines, and
the number of Multiplier errors is low, you can probably ignore any 
warnings or error messages below. If the number of readable QSOs is low,
you may want to try to edit your log and resubmit using the
<a href="http://robot.cqp.org/cqp/logsubmit-form.html">CQP Log Upload form</a>.
In any case, we will do our best to fairly score every Cabrillo log.
</p>
INSTRUCTIONS_END

SUMMARY_TABLE=<<SUMMARY_END
    <TABLE %{tablestyle}>
      <CAPTION %{capstyle}>CQP %{year} Log Details</CAPTION>
      <TR>
         <TH %{headodd}>Callsign:</TH>
         <TD %{dataodd}>%{callsign}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Operator class:</TH>
         <TD %{dataeven}>%{opclass}</TD>
      </TR>
      <TR>
         <TH %{headodd}>Power:</TH>
         <TD %{dataodd}>%{power}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Sent QTH:</TH>
         <TD %{dataeven}>%{sentqth}</TD>
      </TR>

      <TR>
         <TH %{headodd}>Email:</TH>
         <TD %{dataodd}>%{email}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Special categories:</TH>
         <TD %{dataeven}>%{categories}</TD>
      </TR>
      <TR>
         <TH %{headodd}>Log ID:</TH>
         <TD %{dataodd}>%{id}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Log SHA1 Digest:</TH>
         <TD %{dataeven}>%{digest}</TD>
      </TR>
      <TR>
         <TH %{headodd}>Received:</TH>
         <TD %{dataodd}>%{uploadtime}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Deadline:</TH>
         <TD %{dataeven}>%{deadline}</TD>
      </TR>
    </TABLE>

    <TABLE %{tablestyle}>
      <CAPTION %{capstyle}>Robot Summary Evaluation</CAPTION>
      <TR>
         <TH %{headodd}>Total QSO lines:</TH>
         <TD %{dataodd}>%{maxqso}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Readable QSO lines:</TH>
         <TD %{dataeven}>%{validqso}</TD>
      </TR>
      <TR>
         <TH %{headodd}>Number syntax errors:</TH>
         <TD %{dataodd}>%{numerrors}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Number syntax warnings:</TH>
         <TD %{dataeven}>%{numwarnings}</TD>
      </TR>
      <TR>
         <TH %{headodd}>Multiplier errors:</TH>
         <TD %{dataodd}>%{multerrors}</TD>
      </TR>
      <TR>
         <TH %{headeven}>Multiplier warnings:</TH>
         <TD %{dataeven}>%{multwarnings}</TD>
      </TR>
    </TABLE>
SUMMARY_END

BODY=<<BODY_END
  <body>
BODY_END

TRAILER=<<TRAILER_END
  </body>
</html>
TRAILER_END

def issueText(desc, issues, attr)
  result = ""
  if issues.length > 0
    result << "     <DIV class=\"#{desc}Section\">\n"
    result << "       <H1 #{attr[:headingstyle]}>#{desc} Messages</H1>\n"
    issues.each { |issue|
      result << "      <p #{attr[("log" + desc).to_sym]}><span class=\"linenum\">Line " 
      result << issue.lineNum.to_s 
      result << ":</span> <span class=\"errmsg\">"
      result << CGI::escapeHTML(issue.description)
      result << "</span></p>\n"
    }
    result << "     </DIV>\n"
  end
  result
end

def multiplierErrors(issues, attr)
  result = ""
  if issues.length > 0
    result << "     <DIV class=\"MultErrSection\">\n"
    result << "       <H1 #{attr[:headingstyle]}>Unknown Multipliers</H1>\n"
    issues.keys.sort.each { |issue|
      result << "      <p #{attr[:multErrors]}>#{CGI::escapeHTML(issue)}</p>\n"
    }
    result << "     </DIV>\n"
  end
  result
end
  
def multiplierWarnings(issues, attr)
  result = ""
  if issues.length > 0
    result << "     <DIV class=\"MultErrSection\">\n"
    result << "       <H1 #{attr[:headingstyle]}>Multipliers Usings Aliases</H1>\n"
    issues.keys.sort.each { |log|
      result << "      <p #{attr[:multWarnings]}><span class=\"multalias\">#{CGI::escapeHTML(log)}</span> &rarr; "
      result << "<span class=\"multreal\">#{CGI::escapeHTML(issues[log])}</span></p>\n"
    }
    result << "     </DIV>\n"
  end
  result
end

def irregCallsigns(list, attr)
  result = ""
  if list.length > 0 
    result << "     <DIV class=\"CallsignSection\">\n"
    result << "       <H1 #{attr[:headingstyle]}>Irregular Callsigns</H1>\n"
    list.keys.sort.each { |callsign|
      result << "        <p #{attr[:badcall]}>#{CGI::escapeHTML(callsign)}</p>\n"
    }
    result << "     </DIV>\n"
  end
  result
end

def logHtml(log, dbent)
  cats = %w(county youth mobile female school newcontester)
  map = { "county" => "CCE", "youth" => "Youth", "mobile" => "Mobile",
    "female" => "YL", "school" => "School", "newcontester" => "New-contester" }
  attr = Hash.new
  attr[:id] = dbent["id"]
  attr[:digest] = dbent["origdigest"]
  attr[:year] = CQPConfig::CONTEST_DEADLINE.strftime("%Y")
  attr[:uploadtime] = CGI::escapeHTML(dbent["uploadtime"].to_s)
  attr[:deadline] = CGI::escapeHTML(CQPConfig::CONTEST_DEADLINE.to_s)
  attr[:callsign] = CGI::escapeHTML(dbent["callsign_confirm"])
  attr[:opclass] = CGI::escapeHTML(dbent["opclass"].capitalize)
  attr[:power] = CGI::escapeHTML(dbent["power"])
  attr[:email] = CGI::escapeHTML(dbent["emailaddr"])
  attr[:categories] = ""
  cats.each { |cat|
    if dbent[cat] == 1
      attr[:categories] << (" " + map[cat])
    end
  }
  attr[:maxqso] = log.maxqso
  attr[:validqso] = log.validqso
  attr[:numerrors] = log.errors.length
  attr[:numwarnings] = log.warnings.length
  attr[:multerrors] = log.badmultipliers.length
  attr[:multwarnings] = log.warnmultipliers.length
  attr[:sentqth] = CGI::escapeHTML(dbent["sentqth"])

  # CSS stuff
  attr[:capstyle] = "style=\"text-align: center; font-family: 'Trebuchet MS', Verdana, Sans-serif; font-style: normal; font-weight: bold; font-size: 16px; margin-top: 0;  margin-bottom: 0; padding: 0 0 0 0;\""

  attr[:logErrors] = "style=\"font-family: 'Courier New', 'Lucida Console', monospace; font-style: normal; font-weight: normal; margin: 0 0 0 0 ! important; padding: 0 0 0 0; line-height: 105%; white-space: nowrap;\""
  attr[:logWarnings] = attr[:logErrors]
  attr[:multErrors] = attr[:logErrors]
  attr[:multWarnings] = attr[:logErrors]
  attr[:badcall] = attr[:logErrors]

  attr[:headingstyle] = "style=\"font-family: 'Trebuchet MS', Verdana, Sans-serif; font-style: normal; font-weight: bold; font-size: 16px; margin-top: 0; margin-bottom: 0; padding: 0 0 0 0;\""


  attr[:tablestyle] = "style=\"margin: 2em 0 2em 0; border-style: solid; border-width: 2px; border-color: black;\""
  attr[:headeven] = "style=\"font-family: Arial, Verdana, San-serif; text-align: right; background-color: WhiteSmoke;\""
  attr[:headodd] = "style=\"font-family: Arial, Verdana, San-serif; text-align: right; background-color: white;\""
  attr[:dataeven] = "style=\"font-family: Arial, Verdana, San-serif; background-color: WhiteSmoke;\""
  attr[:dataodd] = "style=\"font-family: Arial, Verdana, San-serif; background-color: white;\""


  return (HTML_HEADER % attr) + (BODY % attr) + 
    (SUMMARY_TABLE % attr) + (INSTRUCTIONS % attr) + 
    issueText("Errors", log.errors, attr) +
    issueText("Warnings", log.warnings, attr) +
    multiplierErrors(log.badmultipliers, attr) +
    multiplierWarnings(log.warnmultipliers, attr) + 
    irregCallsigns(log.badcallsigns, attr) +
    (TRAILER % attr)
end

def htmlFromId(db, id)
  chk = CheckLog.new
  dbent = db.getEntry(id)
  log = chk.checkLog(dbent["asciifile"], id)
  return logHtml(log, dbent)
end

# db =  LogDatabase.new
# db.allEntries.each { |id|
#   html = htmlFromId(db, id) 
#   open("/tmp/logs/foo#{id}.html", "w") { |out|
#     out.write(html)
#   }
# }
