#!/usr/local/bin/ruby
require 'getoptlong'
require_relative 'cablog'

$overwritefile = false
$makeoutput = true
opts = GetoptLong.new(
                      [ '--overwrite', '-O', GetoptLong::NO_ARGUMENT],
                      [ '--checkonly', '-C', GetoptLong::NO_ARGUMENT]
                      )
opts.each { |opt,arg|
  case opt
  when '--overwrite'
    $overwritefile = true
  when '--checkonly'
    $makeoutput = false
  end
}

ARGV.shuffle.each { |arg|
  begin
    cab = Cabrillo.new(arg)
    if cab.cleanparse
      if $makeoutput
        if $overwritefile
          open(arg, "w:us-ascii") { |out|
            cab.write(out)
          }
        else
          cab.write($stdout)
        end
      else
        print "#{arg} is clean\n"
      end
    else
      if not $makeoutput
        print "#{arg} is not clean\n"
      end
    end
  rescue => e
    print "Filename: #{arg}\nException: #{e}\n"
  end
}
