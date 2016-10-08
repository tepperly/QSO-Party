#!/usr/local/bin/ruby
require 'getoptlong'
require 'time'
require_relative 'cablog'

$overwritefile = false
$timeshift = nil
$makeoutput = true
$onlyerrors = false
$start_num = nil
$start_time = nil
$end_num = nil
$end_time = nil
opts = GetoptLong.new(
                      [ '--overwrite', '-O', GetoptLong::NO_ARGUMENT],
                      [ '--checkonly', '-C', GetoptLong::NO_ARGUMENT],
                      [ '--start-num', '-s', GetoptLong::REQUIRED_ARGUMENT],
                      [ '--start-time', '-t', GetoptLong::REQUIRED_ARGUMENT],
                      [ '--end-num', '-e', GetoptLong::REQUIRED_ARGUMENT],
                      [ '--end-time', '-T', GetoptLong::REQUIRED_ARGUMENT],
                      [ '--onlyerrors', '-E', GetoptLong::NO_ARGUMENT],
                      [ '--timeshift', GetoptLong::REQUIRED_ARGUMENT]
                      )
opts.each { |opt,arg|
  case opt
  when '--start-num'
    $start_num = arg.to_i
  when '--start-time'
    $start_time = Time.parse(arg)
  when '--end-num'
    $end_num = arg.to_i
  when '--end-time'
    $end_time = Time.parse(arg)
  when '--onlyerrors'
    $onlyerrors = true
  when '--overwrite'
    $overwritefile = true
  when '--checkonly'
    $makeoutput = false
  when '--timeshift'
    $timeshift = arg.to_i*60
  end
}

count = 0
total = 0
ARGV.each { |arg|
  total = total + 1
  begin
    cab = Cabrillo.new(arg)
    if $timeshift
      cab.timeshift($timeshift)
    end
    if $start_time and $end_time and $start_num and $end_num
      cab.interpolatetime($start_num..$end_num, $start_time, $end_time)
    end
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
        print "#{arg} is clean\n" if not $onlyerrors
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
