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

count = 0
total = 0
ARGV.each { |arg|
  total = total + 1
  begin
    cab = Cabrillo.new(arg)
    $stderr.flush
    if cab.cleanparse
      count = count + 1
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
  rescue ArgumentError => e
    print "Filename: #{arg}\nException: #{e}\n"
  end
  $stdout.flush
}

print "#{count} clean logs\n"
print "#{total} total logs\n"
