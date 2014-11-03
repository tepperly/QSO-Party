#!/usr/local/bin/ruby 
# -*- encoding: utf-8 -*-
# Convert pseudo-Cabrillo into CQP Cabrillo
# By Tom Epperly
# ns6t@arrl.net
#
require 'database'
require_relative 'cablog'

def bool(hash, field)
  return (hash.has_key?(field) && (hash[field] == 1))
end

def outputFile(filename)
  File.basename(filename).sub(/.ascii$/i,".log")
end


def normalize(db, id, callsign)
  dbEntry = db.getEntry(id)     # read everything about log
  begin
    print "Callsign #{callsign} #{dbEntry["asciifile"]}\n"
    $stdout.flush
    log = Cabrillo.new(dbEntry["asciifile"])
    $stderr.flush
    log.dblogID = id
    log.dbsentqth = dbEntry["sentqth"]
    log.dbcomments = dbEntry["comments"]
    log.dblogcall = dbEntry["callsign_confirm"].upcase
    log.dbphone = dbEntry["phonenum"]
    log.dboptype = dbEntry['opclass']
    log.dbpower = dbEntry['power']
    log.dbemail = dbEntry['emailaddr']
    log.dbspecial("county", bool(dbEntry, 'county'))
    log.dbspecial("youth", bool(dbEntry, 'youth'))
    log.dbspecial("mobile", bool(dbEntry, 'mobile'))
    log.dbspecial("female", bool(dbEntry, 'female'))
    log.dbspecial("school",  bool(dbEntry, 'school'))
    log.dbspecial("newcontester", bool(dbEntry, 'newcontester'))
    if log.cleanparse
      print "Writing #{outputFile(dbEntry["asciifile"])}\n"
      open(outputFile(dbEntry["asciifile"]), "w:us-ascii") { |out|
        log.write(out)
      }
      return true
    end
  rescue => e
    print "Log for #{callsign} #{dbEntry["asciifile"]} exception: #{e.to_s}\n"
    print e.backtrace
  end
  false
end

db = LogDatabase.new(true)      # read-only connection to database

entries = db.allEntries         # list of IDs for complete entries

total = 0
fixed = 0

entries.each { |id|
  callsign = db.getCallsign(id)
  if "UNKNOWN" != callsign
    total = total + 1
    if normalize(db, id, callsign)
      fixed = fixed + 1
    end
  end
}

print "Total: #{total}\nFixed: #{fixed}\n"

