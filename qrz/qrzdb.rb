#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
# 

require 'database'
require 'getoptlong'
require 'nokogiri'
require_relative 'fetch'

XML_NAMESPACE = {'qrz' => 'http://xmldata.qrz.com'}
DELIM = /\s*,\s*/

def addToDb(db, xml, filename)
  xml.xpath("//qrz:Callsign/qrz:call", XML_NAMESPACE).each { |match|
    db[match.text.strip.upcase] = filename
  }
  xml.xpath("//qrz:Callsign/qrz:aliases", XML_NAMESPACE).each { |match|
    match.text.strip.upcase.split(DELIM) { |call|
      db[call] = filename
    }
  }
end

def readXMLDb(db = Hash.new)
  specialEntries = /^\.\.?$/
  Dir.foreach("xml_db") { |filename|
    if not specialEntries.match(filename)
      wholefile = "xml_db/" + filename
      open(wholefile, "r:iso8859-1:utf-8") { |io|
        xml = Nokogiri::XML(io)
        addToDb(db, xml, wholefile)
      }
    end
  }
  db
end

opts = GetoptLong.new(
  [ '--user', '-u', GetoptLong::REQUIRED_ARGUMENT ],
  [ '--password', '-p', GetoptLong::REQUIRED_ARGUMENT ])

user = nil
password = nil
opts.each { |opt, arg|
  case opt
  when '--user'
    user = arg
  when '--password'
    password = arg
  else
    print "Unknown"
  end
}

def lookupCall(qrz, db, call)
  str, xml = qrz.lookupCall(call)
  if str and xml
    open("xml_db/#{call}.xml", "w:iso-8859-1") { |out|
      out.write(str)
    }
    addToDb(db, xml, "xml_db/#{call}.xml")
    true
  else
    print "Lookup failed: #{call}\n"
    false
  end
end

def getBase(fullcall)
  base = nil
  IO.popen("perl getbase.pl #{fullcall}", "r") { |io|
    base = io.read.strip
  }
  base
end

qrz = QRZLookup.new(user, password)

db = LogDatabase.new(true)      # read-only connection
xmlDb = readXMLDb

logs = db.allEntries
stats = db.workedStats(logs)

stats.keys.sort { |x,y| -1 * (stats[x] <=> stats[y]) }.each { |call|
  call = call.strip.upcase
  if call !~ /[^a-z0-9]/i
    if not xmlDb.has_key?(call)
      lookupCall(qrz,xmlDb, call)
    end
  else
    baseCall = getBase(call)
    if baseCall
      if not xmlDb.has_key?(baseCall)
        print "Looking up base #{baseCall} of #{call}\n"
        lookupCall(qrz, xmlDb, baseCall)
      end
    else
      print "Unusual call: #{call}\n"
    end
  end
}
