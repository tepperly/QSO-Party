#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'database'
require 'csv'
require 'email'
require 'getoptlong'
require 'nokogiri'

XML_NAMESPACE = {'qrz' => 'http://xmldata.qrz.com'}
DELIM = /\s*,\s*/


ALREADY_EMAILED="alreadyemailed.csv"

opts = GetoptLong.new(
  [ '--threshold', '-t', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--email', '-e', GetoptLong::REQUIRED_ARGUMENT ]
)

reportThreshold = 75
testAddress = nil

opts.each { |opt, arg|
  case opt
  when '--threshold'
    reportThreshold = arg.to_i
  when '--email'
    testAddress = arg
  end
}

def calcMissingCalls(db, threshold)
  completedLogs = db.allEntries
  callsWorked = db.workedStats(completedLogs, threshold)
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

MESSAGE_ONE = """Dear %{call}

Preliminary analysis of the logs already received from CQP 2014
suggest that your station was active making QSOs during the contest.
Thanks for your participation!

This is a second courtesy reminder to ask you to please submit your
log in Cabrillo format. For those who already sent in your log in
paper format, we haven't added your callsign to the received
list, so you may be receiving this despite having submitted a paper
log.

Our log submission website is here:

   http://robot.cqp.org/cqp/logsubmit-form.html

Alternatively, you can email your log as an *ATTACHMENT* to
logs@cqp.org

We look forward to receiving your log before the deadline: Friday,
October 31, 2014

Many thanks.

73 de Tom NS6T
CQP 2014 Team
"""

MESSAGE_TWO = """Dear %{call}

Preliminary analysis of the logs already received from CQP 2014
suggest that your station was active making QSOs during the contest.
Thanks for your participation!

But we haven't received your log yet.  This is a courtesy reminder to
ask you to please submit your log in Cabrillo format.  It's fast and
easy.  Just use our online submission form:

   http://robot.cqp.org/cqp/logsubmit-form.html

Alternatively, you can email your log as an *ATTACHMENT* to
logs@cqp.org

We look forward to receiving your log before the deadline: Friday,
October 31, 2014

Many thanks.

73 de Tom NS6T
CQP 2014 Team
"""

def sendReminderEmail(toAddr, call, testAddr = nil)
  remind = OutgoingEmail.new
  remind.sendEmail(testAddr ? testAddr : toAddr,
                   "Your California QSO Party Log",
                   MESSAGE_ONE % { :call => call } )
  sleep 15
end

def getBase(fullcall)
  base = nil
  IO.popen("perl -Iqrz qrz/getbase.pl #{fullcall}", "r") { |io|
    base = io.read.strip
  }
  base.upcase.strip
end
    

calls = calcMissingCalls(LogDatabase.new(true), reportThreshold)

notifiedCalls, notifiedEmails = readCSV(ALREADY_EMAILED)
notifiedCalls.each { |call|
  calls.delete(call)
}
emailDb = Hash.new(false)
notifiedEmails.each { |email|
  emailDb[email] = true
}
xmlDb = scanXML("qrz/xml_db")
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
