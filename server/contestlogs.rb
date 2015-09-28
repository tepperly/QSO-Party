#!/usr/bin/env ruby

require 'database'

db = LogDatabase.new(true)

entries = db.allEntries
entries.each { |id|
  af = db.getASCIIFile(id)
  print(af.sub(/\.ascii$/, ".log") + "\n")
}
