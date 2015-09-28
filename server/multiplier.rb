#!/usr/bin/env ruby

require 'csv'

count = Hash.new(0)

STDIN.each { |line|
  case line
  when /^Sent QTH:\s+$/
    count["UNKNOWN"] = count["UNKNOWN"]  + 1
  when /^Sent QTH:\s+(\w+)\s*$/
    count[$1] = count[$1] + 1
  when /^Sent QTH:(\s+(\w+))+\s*$/
    $1.split { |mult|
      count[mult] = count[mult] + 1
    }
  end
}

states = { }
counties = { }

CSV.foreach("multipliers.csv") { |row|
  if row[1].length == 2
    states[row[1].strip.upcase] = true
  else
    counties[row[1].strip.upcase] = true
  end
}

counties.keys.sort.each { |county|
  print county + "," + count[county].to_s + "\n"
}
states.keys.sort.each { |state|
  print state + "," + count[state].to_s + "\n"
}
print "UNKNOWN," + count["UNKNOWN"].to_s + "\n"
