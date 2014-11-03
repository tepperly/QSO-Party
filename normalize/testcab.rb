#!/usr/local/bin/ruby
require 'getoptlong'
require_relative 'cablog'

$overwritefile = false
opts = GetoptLong.new(
  [ '--overwrite', '-O', GetoptLong::NO_ARGUMENT] )
opts.each { |opt,arg|
  case opt
  when '--overwrite'
    $overwritefile = true
  end
}

ARGV.shuffle.each { |arg|
  begin
    cab = Cabrillo.new(arg)
    if cab.cleanparse
      if $overwritefile
        open(arg, "w:us-ascii") { |out|
          cab.write(out)
        }
      else
        cab.write($stdout)
      end
    end
  rescue => e
    print "Filename: #{arg}\nException: #{e}\n"
  end
}
