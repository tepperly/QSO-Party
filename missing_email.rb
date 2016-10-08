#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'database'
require 'csv'
require 'email'
require 'getoptlong'
require 'nokogiri'

CONTEST_DEADLINE=DateTime.new(2015,10,12,23,59, 59,'+0').to_time
XML_NAMESPACE = {'qrz' => 'http://xmldata.qrz.com'}
DELIM = /\s*,\s*/

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


ALREADY_EMAILED="alreadyemailed.csv"

opts = GetoptLong.new(
  [ '--max', '-m', GetoptLong::REQUIRED_ARGUMENT ],                    
  [ '--threshold', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--email', '-e', GetoptLong::REQUIRED_ARGUMENT ]
)

reportThreshold = nil
maximumStations = nil
testAddress = nil

opts.each { |opt, arg|
  case opt
  when '--max'
    maximumStations = arg.to_i
  when '--threshold'
    reportThreshold = arg.to_i
  when '--email'
    testAddress = arg
  end
}

if not (maximumStations or reportThreshold)
  print "Must supply either --max or --threshold\n"
  exit 2
end

def calcMissingCalls(db, threshold, maximum)
  completedLogs = db.allEntries
  callsWorked = db.workedStats(completedLogs, threshold, maximum)
  completedLogs.each { |id|
    call = db.getCallsign(id)
    call.split(/(\s|[(),])+/).each { |indcall|
      if indcall.length > 0
        callsWorked.delete(indcall)
      end
    }
  }
  callsWorked.keys
end

def readCSV(filename)
  calls = [ ]
  emails = [ ]
  begin
    CSV.foreach(filename) { |row|
      calls << row[0].strip.upcase
      emails << row[1].strip.downcase
    }
  rescue => e
  end
  return calls, emails
end

def addToDb(db, xml, filename)
  xml.xpath("//qrz:Callsign/qrz:call", XML_NAMESPACE).each { |match|
    call = match.text.strip.upcase
    if call.length > 0
      xml.xpath("//qrz:Callsign/qrz:email", XML_NAMESPACE).each { |email|
        db[call] = email.text.strip.downcase
      }
    end
  }
  xml.xpath("//qrz:Callsign/qrz:aliases", XML_NAMESPACE).each { |match|
    match.text.strip.upcase.split(DELIM) { |call|
      if call.length > 0
        xml.xpath("//qrz:Callsign/qrz:email", XML_NAMESPACE).each { |email|
          db[call] = email.text.strip.downcase
        }
      end
    }
  }
  nil
end

def scanXML(dirname)
  db = Hash.new
  specialEntries =  /^\.\.?$/
  Dir.foreach(dirname) { |filename|
    if not specialEntries.match(filename)
      wholefile = dirname + "/" + filename
      open(wholefile, "r") { |io|
        xml = Nokogiri::XML(io)
        addToDb(db, xml, wholefile)
      }
    end
  }
  db
end

def readOne(filename)
  db = Hash.new
  CSV.foreach(filename) { |row|
    db[row[0].upcase.strip] = row[2].downcase.strip
  }
  db
end

def lookupEmail(call, xml, oneby)
  if oneby[call]
    return oneby[call]
  end
  if xml[call]
    return xml[call]
  end
  nil
end

MESSAGE_ONE = """Dear %{call},

Preliminary analysis of the logs already received for the 2015
California QSO Party (CQP) suggest that your station was active making
QSOs during the contest.  Thanks for your participation! Having lots
of stations on the air makes it an exciting contest for everyone.

This is reminder to ask you to please submit your log to our electronic
log retrieval system.  This year's logs must be submitted in Cabrillo
format.

Our log submission website is here:

   http://robot.cqp.org/cqp/logsubmit-form.html

Alternatively, you can email your log as an *ATTACHMENT* to
logs@cqp.org

We look forward to receiving your log before the deadline: Monday,
12 October 2015 23:59 UTC (16:59 PDT).

Many thanks.

73 de Tom NS6T
CQP 2015 Log Retrieval and Scoring
"""

MESSAGE_TWO = """Dear %{call},

Preliminary analysis of the logs already received from CQP 2015
suggest that your station was active making QSOs during the contest.
Thanks for your participation!

But we haven't received your log yet.  This is a courtesy reminder to
ask you to please submit your log in Cabrillo format.  It's fast and
easy.  Just use our online submission form:

   http://robot.cqp.org/cqp/logsubmit-form.html

Alternatively, you can email your log as an *ATTACHMENT* to
logs@cqp.org

We look forward to receiving your log before the deadline: Monday,
12 October 2015 23:59 UTC (16:59 PDT).


Many thanks.

73 de Tom NS6T
CQP 2015 Log Retrieval and Scoring
"""

def sendReminderEmail(toAddr, call, testAddr = nil)
  remind = OutgoingEmail.new
  remind.sendEmail(testAddr ? testAddr : toAddr,
                   "Send in your California QSO Party Log",
                   MESSAGE_ONE % { :call => call, :minutes => ((CONTEST_DEADLINE - Time.now)/60).to_i } )
  sleep 15 + 10*rand
end

def getBase(fullcall)
  return callBase(fullcall).upcase.strip
end
    

calls = calcMissingCalls(LogDatabase.new(true), reportThreshold, maximumStations)

notifiedCalls, notifiedEmails = readCSV(ALREADY_EMAILED)
notifiedCalls.each { |call|
  calls.delete(call)
}
emailDb = Hash.new(false)
notifiedEmails.each { |email|
  emailDb[email] = true
}
print "#{calls.length} calls to report\n"
xmlDb = scanXML("/home/tepperly/xml_db")
oneByOne = readOne("one-by-one.txt")
CSV.open(ALREADY_EMAILED, "a:utf-8") { |csvout|
  calls.each { |call|
    emailAddr = lookupEmail(call, xmlDb, oneByOne)
    if emailAddr
      if not emailDb[emailAddr]
        sendReminderEmail(emailAddr, call, testAddress)
        csvout << [ call, emailAddr ]
      end
    else
      base = getBase(call)
      emailAddr = lookupEmail(base, xmlDb, oneByOne)
      if emailAddr
        if not emailDb[emailAddr]
          sendReminderEmail(emailAddr, call, testAddress)
          csvout << [ call, emailAddr ]
          csvout << [ base, emailAddr ]
        end
      else
        print "No address for #{call} or #{base}\n"
      end
    end
  }
}
