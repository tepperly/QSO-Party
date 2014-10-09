#!/usr/bin/env ruby
# Driver

require 'getoptlong'
require_relative 'fetch'

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

qrz = QRZLookup.new(user, password)


ARGV.each { |callsign|
  str, xml = qrz.lookupCall(callsign)
  if str and xml
    print str
  else
    print "Lookup failed.\n"
  end
}
